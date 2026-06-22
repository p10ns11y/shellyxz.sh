#!/usr/bin/env python
"""Parse cockpit.yaml / tests.yaml and run priority tests for at.

Subcommands (via flags):
  --root DIR          Print test plan JSON (expanded commands).
  --discover DIR      Auto-discover tests, print JSON.
  --run-cmd CMD       Validate allowlist and run one manifest command.
  --run --root DIR    Run top max_run tests (--all, --watch supported).
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import time
from pathlib import Path

FORBIDDEN_SUBSTRINGS = (";", "|", "`", "$(", ">", "<")
ALLOWED_RUNNERS = frozenset(
    {"pnpm", "npm", "cargo", "pytest", "python", "python3", "bash", "sh", "echo"}
)


def parse_tests_yaml(text: str) -> dict:
    max_run = 2
    tests: list[dict] = []
    cur: dict | None = None

    for raw in text.splitlines():
        line = raw.rstrip()
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if stripped.startswith("max_run:"):
            max_run = int(stripped.split(":", 1)[1].strip())
            continue
        if stripped.startswith("- id:"):
            if cur:
                tests.append(cur)
            cur = {"id": stripped.split(":", 1)[1].strip()}
            continue
        if cur is None:
            continue
        for key in ("priority", "command", "watch_command", "label"):
            if stripped.startswith(f"{key}:"):
                val = stripped.split(":", 1)[1].strip()
                if key == "priority":
                    cur[key] = int(val)
                else:
                    cur[key] = val
                break

    if cur:
        tests.append(cur)

    tests.sort(key=lambda t: (t.get("priority", 99), t.get("id", "")))
    return {"max_run": max_run, "tests": tests}


def parse_cockpit_yaml(text: str) -> dict | None:
    """Extract cockpits.test section from unified cockpit.yaml (YAML subset)."""
    lines = text.splitlines()
    in_test = False
    test_indent = 0
    block: list[str] = []

    for raw in lines:
        if not raw.strip() or raw.strip().startswith("#"):
            if in_test:
                block.append(raw)
            continue
        stripped = raw.strip()
        indent = len(raw) - len(raw.lstrip())

        if stripped == "test:" or stripped.startswith("test:"):
            in_test = True
            test_indent = indent
            if ":" in stripped and stripped != "test:":
                block.append(raw[raw.index("test:") + len("test:") :].lstrip())
            continue

        if in_test:
            if indent <= test_indent and stripped.endswith(":") and not stripped.startswith("-"):
                break
            block.append(raw)

    if not block:
        return None

    joined = "\n".join(block)
    if "tests:" not in joined:
        return None

    flat = []
    for line in block:
        s = line.strip()
        if s.startswith("layout:") or s.startswith("max_run:") or s == "tests:":
            flat.append(s)
        elif s.startswith("- id:") or any(
            s.startswith(f"{k}:") for k in ("priority", "command", "watch_command", "label")
        ):
            flat.append(s)

    return parse_tests_yaml("\n".join(flat))


def expand_command(root: Path, cmd: str) -> str:
    cmd = cmd.replace("~", str(Path.home()))
    parts = cmd.split(None, 1)
    exe = parts[0]
    rest = parts[1] if len(parts) > 1 else ""
    if exe.startswith("./"):
        exe = str(root / exe[2:])
    elif not exe.startswith("/") and "/" in exe:
        exe = str(root / exe)
    return f"{exe} {rest}".rstrip() if rest else exe


def expand_plan(root: Path, data: dict) -> dict:
    for t in data["tests"]:
        if "command" in t:
            t["command"] = expand_command(root, t["command"])
        if t.get("watch_command"):
            t["watch_command"] = expand_command(root, t["watch_command"])
    return data


def discover(root: Path) -> dict:
    tests: list[dict] = []
    prio = 1

    pkg = root / "package.json"
    if pkg.is_file():
        watch = "pnpm test --watch" if (root / "pnpm-lock.yaml").is_file() else "npm test --watch"
        tests.append(
            {
                "id": "npm-test",
                "priority": prio,
                "command": "pnpm test" if (root / "pnpm-lock.yaml").is_file() else "npm test",
                "watch_command": watch,
                "label": "package.json test script",
            }
        )
        prio += 1

    if (root / "Cargo.toml").is_file():
        tests.append(
            {
                "id": "cargo-test",
                "priority": prio,
                "command": "cargo test",
                "watch_command": "cargo watch -x test",
                "label": "Cargo.toml test suite",
            }
        )
        prio += 1

    if (root / "pyproject.toml").is_file() or (root / "pytest.ini").is_file():
        tests.append(
            {
                "id": "pytest",
                "priority": prio,
                "command": "pytest",
                "watch_command": "pytest",
                "label": "Python pytest suite",
            }
        )
        prio += 1

    check = root / "bin" / "check-shell.sh"
    if check.is_file():
        tests.append(
            {
                "id": "shellcheck",
                "priority": prio,
                "command": f"{check} --shellcheck-only",
                "label": "shellcheck static analysis",
            }
        )
        prio += 1

    test_dir = root / "bin" / "test"
    if test_dir.is_dir():
        for script in sorted(test_dir.glob("*.test.sh")):
            if script.is_file():
                tests.append(
                    {
                        "id": script.stem.replace(".test", ""),
                        "priority": prio,
                        "command": str(script),
                        "label": f"unit test {script.name}",
                    }
                )
                prio += 1

    if check.is_file():
        tests.append(
            {
                "id": "load-order",
                "priority": prio,
                "command": str(check),
                "label": "full shell audit",
            }
        )

    if not tests:
        tests.append(
            {
                "id": "none",
                "priority": 1,
                "command": "echo 'at: no tests — add .agents/verification/cockpit.yaml or package.json/Cargo.toml/bin/check-shell.sh'",
                "label": "no runner detected",
            }
        )
        return {"max_run": 0, "tests": tests}

    return {"max_run": 2, "tests": tests}


def load_manifest(root: Path) -> dict:
    cockpit = root / ".agents" / "verification" / "cockpit.yaml"
    tests_yaml = root / ".agents" / "verification" / "tests.yaml"

    if cockpit.is_file():
        data = parse_cockpit_yaml(cockpit.read_text())
        if data:
            return expand_plan(root, data)

    if tests_yaml.is_file():
        return expand_plan(root, parse_tests_yaml(tests_yaml.read_text()))

    return expand_plan(root, discover(root))


def command_allowed(cmd: str) -> tuple[bool, str]:
    """Return (ok, first_token)."""
    cmd = cmd.strip()
    if not cmd:
        return False, ""
    first = cmd.split(None, 1)[0]
    if any(sub in cmd for sub in FORBIDDEN_SUBSTRINGS):
        return False, first
    if first.startswith(("bin/", "./", "/")) or first in ALLOWED_RUNNERS:
        return True, first
    return False, first


def run_manifest_command(cmd: str) -> int:
    ok, first = command_allowed(cmd)
    if not ok:
        if not cmd.strip() or any(sub in cmd for sub in FORBIDDEN_SUBSTRINGS):
            print(f"run-project-tests: rejected command: {cmd}", file=sys.stderr)
        else:
            print(f"run-project-tests: command not allowlisted: {first}", file=sys.stderr)
        return 1
    return subprocess.run(["bash", "-c", cmd], check=False).returncode


def first_watch_command(data: dict) -> str | None:
    for t in data.get("tests", []):
        watch = t.get("watch_command")
        if watch:
            return watch
    return None


def run_plan(root: Path, *, run_all: bool = False) -> int:
    data = load_manifest(root)
    tests = data["tests"]
    max_run = len(tests) if run_all else int(data["max_run"])
    total = len(tests)
    failures = 0

    print(f"=== at: running top {max_run} test(s) (max_run={max_run}) ===")

    for run, test in enumerate(tests[:max_run], start=1):
        tid = test.get("id", "")
        prio = test.get("priority", "")
        label = test.get("label", tid)
        cmd = test.get("command", "")
        print(f"\n── [{run}/{max_run}] {tid} (priority {prio}) ──")
        print(f"    {label}")
        if run_manifest_command(cmd) != 0:
            failures += 1

    if total > max_run and not run_all:
        print("\n=== at: also available (not run) ===")
        for t in tests[max_run:]:
            prio = t.get("priority", "?")
            tid = t.get("id", "?")
            label = t.get("label", "")
            cmd = t.get("command", "")
            print(f"  [{prio}] {tid} — {label}")
            print(f"      run: {cmd}")
        print("  tip:   bin/run-project-tests.sh --all")

    print()
    if failures == 0:
        print(f"=== at summary: {max_run} run, 0 failed ===")
    else:
        print(f"=== at summary: {max_run} run, {failures} failed ===")
    return failures


def run_watch(root: Path, interval: int) -> int:
    data = load_manifest(root)
    watch_cmd = first_watch_command(data)
    if watch_cmd:
        print(f"=== at watch: {watch_cmd} ===")
        return run_manifest_command(watch_cmd)

    run_plan(root)
    while True:
        time.sleep(interval)
        print(f"\n── at watch {time.strftime('%Y-%m-%d %H:%M:%S')} ──")
        run_plan(root)


def cmd_run(argv: list[str]) -> int:
    root: Path | None = None
    watch = False
    run_all = False
    interval = int(os.environ.get("TEST_WATCH_INTERVAL", "60"))

    i = 0
    while i < len(argv):
        arg = argv[i]
        if arg == "--root" and i + 1 < len(argv):
            root = Path(argv[i + 1]).resolve()
            i += 2
            continue
        if arg == "--watch":
            watch = True
            i += 1
            continue
        if arg == "--all":
            run_all = True
            i += 1
            continue
        print(f"run-project-tests: unknown argument: {arg}", file=sys.stderr)
        return 2

    if root is None:
        print("run-project-tests: --root required", file=sys.stderr)
        return 2

    if watch:
        return run_watch(root, interval)
    return run_plan(root, run_all=run_all)


def print_usage() -> None:
    print(
        "usage: parse-project-tests.py --root <directory>\n"
        "       parse-project-tests.py --discover <root>\n"
        "       parse-project-tests.py --run-cmd <command>\n"
        "       parse-project-tests.py --run --root <dir> [--watch] [--all]\n"
        "       parse-project-tests.py <manifest> [root]",
        file=sys.stderr,
    )


def main() -> int:
    if len(sys.argv) < 2:
        print_usage()
        return 2

    if sys.argv[1] == "--run-cmd":
        if len(sys.argv) < 3:
            print_usage()
            return 2
        return run_manifest_command(sys.argv[2])

    if sys.argv[1] == "--run":
        return cmd_run(sys.argv[2:])

    if sys.argv[1] == "--discover":
        root = Path(sys.argv[2]).resolve()
        data = expand_plan(root, discover(root))
        print(json.dumps(data))
        return 0

    if sys.argv[1] == "--root":
        root = Path(sys.argv[2]).resolve()
        data = load_manifest(root)
        print(json.dumps(data))
        return 0

    manifest = Path(sys.argv[1])
    root = Path(sys.argv[2]).resolve() if len(sys.argv) > 2 else manifest.parent
    if manifest.name == "cockpit.yaml":
        data = parse_cockpit_yaml(manifest.read_text()) or discover(root)
    elif manifest.name == "tests.yaml":
        data = parse_tests_yaml(manifest.read_text())
    else:
        data = parse_tests_yaml(manifest.read_text())

    data = expand_plan(root, data)
    print(json.dumps(data))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
