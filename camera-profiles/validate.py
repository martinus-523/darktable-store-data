#!/usr/bin/env python3
"""Validate that every subfolder in camera-profiles/ contains a valid collection.

Each collection folder must contain a meta.json and a profiles/ subfolder
holding the ICC camera input profiles listed in meta.json's "files" field.
Unlike styles and luts there is no images/ folder: an input profile is only
meaningful on raws from the camera it was made for, so no previews are
generated from the shared raw set.
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


REQUIRED = {
    "creation-date": str,
    "author": str,
    "name": str,
    "contributor": str,
    "description": str,
    "license": str,
    "cameras": list,
    "files": list,
    "dt-versions": list,
}
SLUG = re.compile(r"^[a-z0-9-]+$")
DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
PROFILE_EXTS = {".icc", ".icm"}


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

    cdate = meta.get("creation-date")
    if isinstance(cdate, str) and not DATE.match(cdate):
        errors.append("field 'creation-date' must be an ISO date (YYYY-MM-DD)")

    if "url" in meta and not isinstance(meta["url"], str):
        errors.append("field 'url' must be of type str")

    for camera in list(meta.get("cameras") or []):
        if not isinstance(camera, str) or not camera.strip():
            errors.append(f"camera '{camera}' must be a non-empty string")

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

    profiles_subdir = folder / "profiles"
    if not profiles_subdir.is_dir():
        errors.append("'profiles' subfolder is missing")
    on_disk = {nfc(p.name) for p in profiles_subdir.iterdir()} if profiles_subdir.is_dir() else set()
    for name in list(meta.get("files") or []):
        if not isinstance(name, str):
            continue
        if Path(name).suffix.lower() not in PROFILE_EXTS:
            errors.append(f"file '{name}' is not an ICC profile (.icc/.icm)")
        if nfc(name) not in on_disk:
            errors.append(f"referenced file 'profiles/{name}' does not exist")

    notes = meta.get("notes")
    if notes is not None:
        if not isinstance(notes, dict):
            errors.append("field 'notes' must be an object mapping filename to note")
        else:
            for key, value in notes.items():
                if key not in (meta.get("files") or []):
                    errors.append(f"notes key '{key}' is not in 'files'")
                if not isinstance(value, str):
                    errors.append(f"note for '{key}' must be of type str")

    return errors


def main() -> int:
    profiles_dir = Path(__file__).parent
    failed = False
    profile_count = 0
    for folder in sorted(p for p in profiles_dir.iterdir() if p.is_dir() and not p.name.startswith(".")):
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
                profile_count += len(json.loads(meta_path.read_text()).get("files") or [])
            except json.JSONDecodeError:
                pass
    print(f"Found {profile_count} camera profile(s)")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
