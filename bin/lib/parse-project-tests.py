#!/usr/bin/env python3
"""Parse cockpit.yaml, tests.yaml, or auto-discover project tests for at. Prints JSON."""
from __future__ import annotations

import json
import sys
from pathlib import Path


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
    """Extract cockpits.test section from unified cockpit.yaml."""
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

    # Re-wrap as flat tests.yaml shape for reuse.
    flat = []
    for line in block:
        s = line.strip()
        if s.startswith("layout:") or s.startswith("max_run:") or s == "tests:":
            flat.append(s)
        elif s.startswith("- id:") or any(s.startswith(f"{k}:") for k in ("priority", "command", "watch_command", "label")):
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

    return {"max_run": 2, "tests": tests}


def load_manifest(root: Path) -> dict:
    cockpit = root / ".agents" / "verification" / "cockpit.yaml"
    tests_yaml = root / ".agents" / "verification" / "tests.yaml"

    if cockpit.is_file():
        data = parse_cockpit_yaml(cockpit.read_text())
        if data:
            return data

    if tests_yaml.is_file():
        return parse_tests_yaml(tests_yaml.read_text())

    return discover(root)


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: parse-project-tests.py <manifest> [root]", file=sys.stderr)
        print("       parse-project-tests.py --discover <root>", file=sys.stderr)
        print("       parse-project-tests.py --root <directory>", file=sys.stderr)
        return 2

    if sys.argv[1] == "--discover":
        root = Path(sys.argv[2]).resolve()
        data = discover(root)
    elif sys.argv[1] == "--root":
        root = Path(sys.argv[2]).resolve()
        data = load_manifest(root)
    else:
        manifest = Path(sys.argv[1])
        root = Path(sys.argv[2]).resolve() if len(sys.argv) > 2 else manifest.parent
        if manifest.name == "cockpit.yaml":
            data = parse_cockpit_yaml(manifest.read_text()) or discover(root)
        elif manifest.name == "tests.yaml":
            data = parse_tests_yaml(manifest.read_text())
        else:
            data = parse_tests_yaml(manifest.read_text())

    for t in data["tests"]:
        if "command" in t:
            t["command"] = expand_command(root, t["command"])
        if t.get("watch_command"):
            t["watch_command"] = expand_command(root, t["watch_command"])

    print(json.dumps(data))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
