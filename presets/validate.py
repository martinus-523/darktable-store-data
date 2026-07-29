#!/usr/bin/env python3
"""Validate that every subfolder in presets/ contains a valid preset collection."""
import json
import re
import sys
from pathlib import Path

REQUIRED = {
    "author": str,
    "name": str,
    "contributor": str,
    "description": str,
    "license": str,
    "files": dict,
    "languages": list,
    "readme": bool,
    "dt-versions": list,
    "modules": list,
}
SLUG = re.compile(r"^[a-z0-9-]+$")


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
        elif ftype in (list, dict) and not value:
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

    files = meta.get("files")
    languages = meta.get("languages")
    if isinstance(files, dict) and isinstance(languages, list):
        if sorted(files) != sorted(languages):
            errors.append("'languages' does not match the language keys of 'files'")

    if isinstance(files, dict):
        counts = {}
        for lang, names in files.items():
            lang_dir = folder / "presets" / lang
            if not isinstance(names, list):
                errors.append(f"files['{lang}'] must be of type list")
                continue
            counts[lang] = len(names)
            if not lang_dir.is_dir():
                errors.append(f"language folder 'presets/{lang}' does not exist")
                continue
            for name in names:
                if isinstance(name, str) and not (lang_dir / name).is_file():
                    errors.append(f"referenced file 'presets/{lang}/{name}' does not exist")
            on_disk = {f.name for f in lang_dir.iterdir() if f.suffix == ".dtpreset"}
            for name in sorted(on_disk - set(names)):
                errors.append(f"file 'presets/{lang}/{name}' is not listed in meta.json")
        if len(set(counts.values())) > 1:
            errors.append(f"languages have different numbers of presets: {counts}")

    readme_exists = (folder / "readme.md").is_file()
    if meta.get("readme") is True and not readme_exists:
        errors.append("'readme' is true but readme.md does not exist")
    if meta.get("readme") is False and readme_exists:
        errors.append("'readme' is false but readme.md exists")

    images = meta.get("images")
    if images is not None:
        if not isinstance(images, list):
            errors.append("field 'images' must be of type list")
        else:
            for name in images:
                if isinstance(name, str) and not (folder / "images" / name).is_file():
                    errors.append(f"referenced image 'images/{name}' does not exist")

    return errors


def main() -> int:
    presets_dir = Path(__file__).parent
    failed = False
    unique_presets = 0
    total_files = 0
    for folder in sorted(p for p in presets_dir.iterdir() if p.is_dir() and not p.name.startswith(".")):
        errors = validate(folder)
        if errors:
            failed = True
            print(f"FAIL  {folder.name}")
            for error in errors:
                print(f"      - {error}")
        else:
            print(f"OK    {folder.name}")
        lang_counts = [
            sum(1 for f in lang.iterdir() if f.suffix == ".dtpreset")
            for lang in (folder / "presets").iterdir()
            if lang.is_dir()
        ] if (folder / "presets").is_dir() else []
        unique_presets += max(lang_counts, default=0)
        total_files += sum(lang_counts)
    print(f"Found {unique_presets} .dtpreset file(s) ({total_files} including translations)")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
