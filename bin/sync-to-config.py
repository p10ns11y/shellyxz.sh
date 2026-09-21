#!/usr/bin/env python3
"""Sync shellyxz checkout → ~/.config/shell; preserve local/, environment, backups/."""
from __future__ import annotations

import os
import shutil
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent
SRC = Path(os.environ.get("SHELLXZ_SRC", REPO_ROOT))
DST = Path(os.environ.get("SHELLXZ_DST", Path.home() / ".config/shell"))
PRESERVE_TOP = {"local", "backups", "environment", ".git"}


def main() -> int:
    if not (SRC / "core" / "path.contract").is_file():
        print(f"error: source checkout missing at {SRC}", file=sys.stderr)
        print("hint: set SHELLXZ_SRC to your shellyxz git checkout", file=sys.stderr)
        return 1

    DST.mkdir(parents=True, exist_ok=True)
    preserve_dir = Path(os.environ.get("TMPDIR", "/tmp")) / f"shellyxz-preserve-{os.getpid()}"
    if preserve_dir.exists():
        shutil.rmtree(preserve_dir)
    preserve_dir.mkdir(parents=True)

    for name in ("local", "backups"):
        preserved_path = DST / name
        if preserved_path.exists():
            shutil.copytree(preserved_path, preserve_dir / name)
    environment_file = DST / "environment"
    if environment_file.is_file():
        shutil.copy2(environment_file, preserve_dir / "environment")

    def should_skip(relative_path: Path) -> bool:
        if not relative_path.parts:
            return False
        return relative_path.parts[0] in PRESERVE_TOP or relative_path.name == ".DS_Store"

    for path in SRC.rglob("*"):
        relative_path = path.relative_to(SRC)
        if should_skip(relative_path):
            continue
        target = DST / relative_path
        if path.is_dir():
            target.mkdir(parents=True, exist_ok=True)
        elif path.is_symlink():
            target.parent.mkdir(parents=True, exist_ok=True)
            if target.exists() or target.is_symlink():
                target.unlink()
            target.symlink_to(os.readlink(path))
        elif path.is_file():
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, target)

    (DST / "local").mkdir(exist_ok=True)
    (DST / "backups").mkdir(exist_ok=True)
    if (preserve_dir / "local").exists():
        if (DST / "local").exists():
            shutil.rmtree(DST / "local")
        shutil.copytree(preserve_dir / "local", DST / "local")
    if (preserve_dir / "backups").exists():
        for preserved_entry in (preserve_dir / "backups").iterdir():
            target_entry = DST / "backups" / preserved_entry.name
            if preserved_entry.is_dir():
                if target_entry.exists():
                    shutil.rmtree(target_entry)
                shutil.copytree(preserved_entry, target_entry)
            else:
                shutil.copy2(preserved_entry, target_entry)
    if (preserve_dir / "environment").is_file():
        shutil.copy2(preserve_dir / "environment", DST / "environment")

    path_contract_example = DST / "local" / "path.contract.example"
    path_contract = DST / "local" / "path.contract"
    if not path_contract.exists() and path_contract_example.exists():
        shutil.copy2(path_contract_example, path_contract)

    shutil.rmtree(preserve_dir, ignore_errors=True)
    print(f"synced: {SRC} → {DST}")
    print("preserved: local/ environment backups/")
    print("next: source ~/.config/shell/env.sh && path_check")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
