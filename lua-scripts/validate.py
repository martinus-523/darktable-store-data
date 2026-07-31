#!/usr/bin/env python3
"""Validate that every subfolder in lua-scripts/ describes a valid Lua script.

Each folder holds a meta.json describing one script. Entries come in two
shapes, keyed off "type":

  "shipped"      scripts that ship with darktable itself. They carry a
                 "group" (official/contrib/tools), are pre-"validated", and
                 have no bundled files (darktable already provides them).
  "third-party"  scripts pulled from an external repo. They carry a "files"
                 list of the bundled paths and a matching files/ subfolder,
                 have no "group", and are not "validated".
"""
import json
import re
import sys
import unicodedata
from pathlib import Path


def nfc(name: str) -> str:
    """Unicode NFC form, so meta.json names and on-disk names compare equal
    regardless of how each was normalized (macOS often stores NFD, Linux NFC)."""
    return unicodedata.normalize("NFC", name)


# Fields present on every entry, with their required JSON type.
REQUIRED = {
    "author": str,
    "name": str,
    "description": str,
    "description-extensive": str,
    "license": str,
    "type": str,
    "validated": bool,
    "category": list,
    "contributor": str,
    "url": str,
    "source": list,
    "dt-versions": list,
    "creation-date": str,
}
# Fields present on every entry whose value may be a string or null.
NULLABLE_STR = ("lua-api", "commit", "commit-date")

TYPES = {"shipped", "third-party"}
GROUPS = {"official", "contrib", "tools"}
CATEGORIES = {"image-processing", "metadata", "utility", "export",
              "integration", "workflow", "ui", "geo", "import"}
LICENSES = {"GPL-3.0-or-later", "GPL-2.0-or-later", "GPL-2.0-only",
            "MIT", "CC-BY-NC-SA-4.0"}

# Folder names mirror upstream script filenames, which commonly use underscores.
SLUG = re.compile(r"^[a-z0-9_-]+$")
DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


def validate_files(folder: Path, meta: dict) -> list[str]:
    """Third-party: every listed path resolves under files/ and nothing else
    lives there. Listed paths may be nested (e.g. 'lib/util.lua')."""
    files = meta.get("files")
    if not isinstance(files, list) or not files:
        return ["field 'files' must be a non-empty list"]
    if not all(isinstance(f, str) for f in files):
        return ["field 'files' must contain only strings"]

    files_dir = folder / "files"
    if not files_dir.is_dir():
        return ["'files' subfolder is missing"]

    listed = {nfc(f) for f in files}
    errors = [f"referenced file 'files/{f}' does not exist"
              for f in files if not (files_dir / f).is_file()]
    on_disk = {nfc(str(p.relative_to(files_dir)))
               for p in files_dir.rglob("*") if p.is_file() and not p.name.startswith(".")}
    errors += [f"unexpected file 'files/{name}'" for name in sorted(on_disk - listed)]
    return errors


def validate(folder: Path) -> list[str]:
    errors = []
    if not SLUG.match(folder.name):
        errors.append("folder name is not a valid slug (lowercase letters, numbers, hyphens, underscores)")

    meta_path = folder / "meta.json"
    if not meta_path.is_file():
        return errors + ["meta.json is missing"]
    try:
        meta = json.loads(meta_path.read_text())
    except json.JSONDecodeError as e:
        return errors + [f"meta.json is not valid JSON: {e}"]

    for field, ftype in REQUIRED.items():
        value = meta.get(field)
        if field not in meta:
            errors.append(f"required field '{field}' is missing")
        # bool is a subclass of int; guard against it standing in for other types
        elif not isinstance(value, ftype) or (ftype is not bool and isinstance(value, bool)):
            errors.append(f"field '{field}' must be of type {ftype.__name__}")
        elif ftype is list and not value:
            errors.append(f"field '{field}' must not be empty")

    for field in NULLABLE_STR:
        if field not in meta:
            errors.append(f"required field '{field}' is missing")
        elif meta[field] is not None and not isinstance(meta[field], str):
            errors.append(f"field '{field}' must be a string or null")

    # 'author' holds a single person; additional authors go in 'co-authors'.
    if isinstance(meta.get("author"), str) and "," in meta["author"]:
        errors.append("field 'author' must name a single person (put others in 'co-authors')")
    coauthors = meta.get("co-authors")
    if coauthors is not None and (not isinstance(coauthors, list) or not coauthors
                                  or not all(isinstance(a, str) and a.strip() for a in coauthors)):
        errors.append("field 'co-authors' must be a non-empty list of non-empty strings")

    if meta.get("type") not in TYPES:
        errors.append(f"field 'type' must be one of {sorted(TYPES)}")
    if isinstance(meta.get("license"), str) and meta["license"] not in LICENSES:
        errors.append(f"field 'license' must be one of {sorted(LICENSES)}")
    if isinstance(meta.get("category"), list):
        bad = [c for c in meta["category"] if c not in CATEGORIES]
        if bad:
            errors.append(f"field 'category' has unknown value(s) {bad}; allowed: {sorted(CATEGORIES)}")

    cdate = meta.get("creation-date")
    if isinstance(cdate, str) and not DATE.match(cdate):
        errors.append("field 'creation-date' must be an ISO date (YYYY-MM-DD)")

    versions = meta.get("dt-versions")
    if isinstance(versions, list) and not all(isinstance(v, (int, float)) and not isinstance(v, bool) for v in versions):
        errors.append("field 'dt-versions' must contain only numbers")

    source = meta.get("source")
    if isinstance(source, list) and not all(isinstance(u, str) and u.startswith("http") for u in source):
        errors.append("field 'source' must contain only http(s) URLs")

    # Variant coherence: shipped vs third-party.
    ftype = meta.get("type")
    # 'validated' is an independent flag, deliberately not tied to type/group.
    if ftype == "shipped":
        if meta.get("group") not in GROUPS:
            errors.append(f"shipped entry must have 'group' in {sorted(GROUPS)}")
        if "files" in meta:
            errors.append("shipped entry must not have a 'files' field")
        if (folder / "files").exists():
            errors.append("shipped entry must not have a 'files' subfolder")
    elif ftype == "third-party":
        if "group" in meta:
            errors.append("third-party entry must not have a 'group' field")
        errors += validate_files(folder, meta)

    return errors


def main() -> int:
    scripts_dir = Path(__file__).parent
    failed = False
    counts = {"shipped": 0, "third-party": 0}
    for folder in sorted(p for p in scripts_dir.iterdir() if p.is_dir() and not p.name.startswith(".")):
        errors = validate(folder)
        if errors:
            failed = True
            print(f"FAIL  {folder.name}")
            for error in errors:
                print(f"      - {error}")
        else:
            print(f"OK    {folder.name}")
        meta_path = folder / "meta.json"
        if meta_path.is_file():
            try:
                stype = json.loads(meta_path.read_text()).get("type")
                counts[stype] = counts.get(stype, 0) + 1
            except json.JSONDecodeError:
                pass
    total = sum(counts.values())
    print(f"Found {total} Lua script(s) ({counts['shipped']} shipped, {counts['third-party']} third-party)")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
