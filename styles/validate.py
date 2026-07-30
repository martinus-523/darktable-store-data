#!/usr/bin/env python3
"""Validate that every subfolder in styles/ contains a valid style collection.

Each collection folder must contain a meta.json, a styles/ subfolder holding
the style files listed in meta.json's "files" field, and an images/ subfolder
with one preview WebP per (style, raw file) pair named <style>_<rawname>.webp,
as produced by assets/generate-style-jpgs.py.
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


RAW_DIR = Path(__file__).resolve().parent.parent / "assets" / "raw-files"
RAW_EXTS = {".arw", ".cr2", ".cr3", ".nef", ".dng", ".raf", ".orf", ".rw2", ".pef", ".srw"}

REQUIRED = {
    "creation-date": str,
    "author": str,
    "name": str,
    "contributor" : str,
    "description": str,
    "license": str,
    "category": list,
    "files": list,
    "dt-versions": list,
}
SLUG = re.compile(r"^[a-z0-9-]+$")
DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
CATEGORIES = {"camera-profile", "film-emulation", "technical", "creative"}


def slugify(text: str) -> str:
    return re.sub(r"-+", "-", re.sub(r"[^a-z0-9]+", "-", text.lower())).strip("-")


def style_slugs(folder: Path) -> list[str]:
    """Slug per .dtstyle file, deduplicated exactly like generate-style-jpgs.py."""
    slugs = []
    seen = set()
    for dtstyle in sorted((folder / "styles").glob("*.dtstyle")):
        slug = slugify(dtstyle.stem) or "style"
        n, unique = 2, slug
        while unique in seen:
            unique = f"{slug}-{n}"
            n += 1
        seen.add(unique)
        slugs.append(unique)
    return slugs


def validate_images(folder: Path, raw_slugs: list[str]) -> list[str]:
    expected = {f"{style}_{raw}.webp" for style in style_slugs(folder) for raw in raw_slugs}
    images_dir = folder / "images"
    if not images_dir.is_dir():
        return ["'images' subfolder is missing"] if expected else []
    actual = {nfc(p.name) for p in images_dir.iterdir() if not p.name.startswith(".")}
    errors = [f"image 'images/{name}' is missing" for name in sorted(expected - actual)]
    errors += [f"unexpected file 'images/{name}'" for name in sorted(actual - expected)]
    return errors


def validate(folder: Path, raw_slugs: list[str]) -> list[str]:
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

    for category in list(meta.get("category") or []):
        if not isinstance(category, str) or category not in CATEGORIES:
            errors.append(f"category '{category}' is not one of {', '.join(sorted(CATEGORIES))}")

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

    styles_subdir = folder / "styles"
    if not styles_subdir.is_dir():
        errors.append("'styles' subfolder is missing")
    on_disk = {nfc(p.name) for p in styles_subdir.iterdir()} if styles_subdir.is_dir() else set()
    for name in list(meta.get("files") or []):
        if isinstance(name, str) and nfc(name) not in on_disk:
            errors.append(f"referenced file 'styles/{name}' does not exist")

    errors += validate_images(folder, raw_slugs)

    return errors


def main() -> int:
    styles_dir = Path(__file__).parent
    raw_slugs = sorted(slugify(p.stem) for p in RAW_DIR.iterdir()
                       if p.suffix.lower() in RAW_EXTS) if RAW_DIR.is_dir() else []
    if not raw_slugs:
        print(f"error: no raw files found in {RAW_DIR}", file=sys.stderr)
        return 1
    failed = False
    for folder in sorted(p for p in styles_dir.iterdir() if p.is_dir() and not p.name.startswith(".")):
        errors = validate(folder, raw_slugs)
        if errors:
            failed = True
            print(f"FAIL  {folder.name}")
            for error in errors:
                print(f"      - {error}")
        else:
            print(f"OK    {folder.name}")
    dtstyle_count = sum(1 for _ in styles_dir.rglob("*.dtstyle"))
    print(f"Found {dtstyle_count} .dtstyle file(s)")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
