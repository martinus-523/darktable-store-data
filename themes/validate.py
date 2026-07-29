#!/usr/bin/env python3
"""Validate that every subfolder in themes/ contains a valid theme."""
import json
import re
import sys
from pathlib import Path

REQUIRED = {
    "author": str,
    "name": str,
    "contributor" : str,
    "description": str,
    "license": str,
    "type": str,
    "files": list,
    "screenshots": list,
    "dt-versions": list,
}
SLUG = re.compile(r"^[a-z0-9-]+$")
THEME_TYPES = {"color", "dark", "grey", "light"}


def validate(folder: Path) -> list[str]:
    errors = []
    if not SLUG.match(folder.name):
        errors.append("folder name is not a valid slug (lowercase letters, numbers, hyphens)")

    meta_path = folder / "meta.json"
    if not meta_path.is_file():
        return errors + ["meta.json is missing"]
    try:
        meta = json.loads(meta_path.read_text())
    except json.JSONDecodeError as e:
        return errors + [f"meta.json is not valid JSON: {e}"]

    for field, ftype in REQUIRED.items():
        value = meta.get(field)
        if value is None:
            errors.append(f"required field '{field}' is missing")
        elif not isinstance(value, ftype):
            errors.append(f"field '{field}' must be of type {ftype.__name__}")
        elif ftype is list and not value:
            errors.append(f"field '{field}' must not be empty")

    if isinstance(meta.get("type"), str) and meta["type"] not in THEME_TYPES:
        errors.append(f"field 'type' must be one of: {', '.join(sorted(THEME_TYPES))}")

    if "url" in meta and not isinstance(meta["url"], str):
        errors.append("field 'url' must be of type str")

    native = meta.get("native", False)
    if not isinstance(native, bool):
        errors.append("field 'native' must be of type bool")
        native = False
    source = meta.get("source")
    if native:
        if source is not None:
            errors.append("'native' is true but 'source' is present")
    elif source is None:
        errors.append("required field 'source' is missing (use 'native': true for repo-native collections)")
    elif not isinstance(source, list) or not source or not all(isinstance(u, str) and u.startswith("http") for u in source):
        errors.append("field 'source' must be a non-empty list of http(s) URLs")

    for name in list(meta.get("files") or []) + list(meta.get("screenshots") or []):
        if isinstance(name, str) and not (folder / name).is_file():
            errors.append(f"referenced file '{name}' does not exist")

    return errors


def main() -> int:
    themes_dir = Path(__file__).parent
    failed = False
    valid = 0
    for folder in sorted(p for p in themes_dir.iterdir() if p.is_dir() and not p.name.startswith(".")):
        errors = validate(folder)
        if errors:
            failed = True
            print(f"FAIL  {folder.name}")
            for error in errors:
                print(f"      - {error}")
        else:
            valid += 1
            print(f"OK    {folder.name}")
    print(f"Found {valid} valid theme(s)")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
