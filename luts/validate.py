#!/usr/bin/env python3
"""Validate that every subfolder in luts/ contains a valid LUT collection.

Each collection folder must contain a meta.json, a luts/ subfolder holding
the LUT files listed in meta.json's "files" field, and an images/ subfolder
with one preview WebP per (LUT, raw file) pair named <lutname>_<rawname>.webp,
as produced by assets/generate-lut-jpgs.py. Collections that generator
skips (unsupported input-colorspace or LUT type) are exempt.
"""
import json
import re
import sys
from pathlib import Path

RAW_DIR = Path(__file__).resolve().parent.parent / "assets" / "raw-files"
RAW_EXTS = {".arw", ".cr2", ".cr3", ".nef", ".dng", ".raf", ".orf", ".rw2", ".pef", ".srw"}
# what assets/generate-lut-jpgs.py can render previews for
SUPPORTED_COLORSPACES = {"sRGB", "Adobe RGB", "gamma Rec.709", "linear Rec.709",
                         "linear Rec.2020", "linear ProPhoto"}
SUPPORTED_LUT_EXTS = {".cube", ".3dl", ".png"}

REQUIRED = {
    "author": str,
    "name": str,
    "contributor": str,
    "description": str,
    "license": str,
    "input-colorspace": str,
    "output-colorspace": str,
    "files": list,
    "dt-versions": list,
}
SLUG = re.compile(r"^[a-z0-9-]+$")


def slugify(text: str) -> str:
    return re.sub(r"-+", "-", re.sub(r"[^a-z0-9]+", "-", text.lower())).strip("-")


def lut_slugs(meta: dict) -> list[str]:
    """Slug per renderable LUT file, deduplicated exactly like generate-lut-jpgs.py."""
    slugs = []
    seen = set()
    for name in meta.get("files") or []:
        if not isinstance(name, str) or Path(name).suffix.lower() not in SUPPORTED_LUT_EXTS:
            continue
        slug = slugify(Path(name).stem) or "lut"
        n, unique = 2, slug
        while unique in seen:
            unique = f"{slug}-{n}"
            n += 1
        seen.add(unique)
        slugs.append(unique)
    return slugs


def validate_images(folder: Path, meta: dict, raw_slugs: list[str]) -> list[str]:
    if meta.get("input-colorspace") not in SUPPORTED_COLORSPACES:
        return []  # generate-lut-jpgs.py cannot render previews for these
    expected = {f"{lut}_{raw}.webp" for lut in lut_slugs(meta) for raw in raw_slugs}
    images_dir = folder / "images"
    if not images_dir.is_dir():
        return ["'images' subfolder is missing"] if expected else []
    actual = {p.name for p in images_dir.iterdir() if not p.name.startswith(".")}
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

    luts_subdir = folder / "luts"
    if not luts_subdir.is_dir():
        errors.append("'luts' subfolder is missing")
    for name in list(meta.get("files") or []):
        if isinstance(name, str) and not (luts_subdir / name).is_file():
            errors.append(f"referenced file 'luts/{name}' does not exist")

    errors += validate_images(folder, meta, raw_slugs)

    return errors


def main() -> int:
    luts_dir = Path(__file__).parent
    raw_slugs = sorted(slugify(p.stem) for p in RAW_DIR.iterdir()
                       if p.suffix.lower() in RAW_EXTS) if RAW_DIR.is_dir() else []
    if not raw_slugs:
        print(f"error: no raw files found in {RAW_DIR}", file=sys.stderr)
        return 1
    failed = False
    lut_count = 0
    for folder in sorted(p for p in luts_dir.iterdir() if p.is_dir() and not p.name.startswith(".")):
        errors = validate(folder, raw_slugs)
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
                lut_count += len(json.loads(meta_path.read_text()).get("files") or [])
            except json.JSONDecodeError:
                pass
    print(f"Found {lut_count} LUT file(s)")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
