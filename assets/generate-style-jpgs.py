#!/usr/bin/env python3
"""Generate styled before/after preview JPGs for every style in the repository.

For each .dtstyle file in styles/<collection>/styles/ and each raw file in
assets/raw-files/, exports a 1200px-wide JPG with that style applied and
converts it to WebP (to save disk space), into
styles/<collection>/images/<stylename>_<rawname>.webp. The unstyled
"before" images are produced by generate-jpgs.sh; the shared darktable-cli
export machinery lives in dt_export.py.

Usage:
  generate-style-jpgs.py               # everything (skips up-to-date files)
  generate-style-jpgs.py --filter kajili --raw portrait
  generate-style-jpgs.py --jobs 4 --force
"""
import argparse
import base64
import sqlite3
import sys
import tempfile
import xml.etree.ElementTree as ET
import zlib
from pathlib import Path

from dt_export import REPO, export_all, find_darktable_cli, init_config, list_raws, slugify

STYLES_DIR = REPO / "styles"


def decode_params(text: str | None) -> bytes | None:
    """dtstyle params are hex, or 'gzNN' + base64 of zlib-compressed data."""
    if not text:
        return None
    if text.startswith("gz"):
        return zlib.decompress(base64.b64decode(text[4:]))
    return bytes.fromhex(text)


def collect_styles() -> list[dict]:
    """One entry per .dtstyle file: collection, slug, unique db name, path."""
    styles = []
    seen = set()
    for collection in sorted(p for p in STYLES_DIR.iterdir() if p.is_dir()):
        for dtstyle in sorted((collection / "styles").glob("*.dtstyle")):
            slug = slugify(dtstyle.stem) or "style"
            db_name = f"{collection.name}__{slug}"
            n = 2
            while db_name in seen:
                db_name = f"{collection.name}__{slug}-{n}"
                n += 1
            seen.add(db_name)
            styles.append({"collection": collection.name, "slug": db_name.split("__", 1)[1],
                           "db_name": db_name, "path": dtstyle})
    return styles


def import_style(db: sqlite3.Connection, style: dict) -> None:
    root = ET.parse(style["path"]).getroot()
    info = root.find("info")
    iop_list = info.findtext("iop_list") if info is not None else None
    cur = db.execute("INSERT INTO styles (name, description, iop_list) VALUES (?, ?, ?)",
                     (style["db_name"], "", iop_list))
    for p in root.findall("./style/plugin"):
        g = p.findtext
        db.execute(
            """INSERT INTO style_items (styleid, num, module, operation, op_params,
               enabled, blendop_params, blendop_version, multi_priority, multi_name,
               multi_name_hand_edited) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (cur.lastrowid, int(g("num") or 0), int(g("module") or 0), g("operation"),
             decode_params(g("op_params")), int(g("enabled") or 0),
             decode_params(g("blendop_params")), int(g("blendop_version") or 0),
             int(g("multi_priority") or 0), g("multi_name") or "",
             int(g("multi_name_hand_edited") or 0)))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--filter", default="", help="only styles whose collection or name contains this")
    ap.add_argument("--raw", default="", help="only raw files whose name contains this")
    ap.add_argument("--jobs", type=int, default=3, help="parallel darktable-cli instances (default 3)")
    ap.add_argument("--force", action="store_true", help="regenerate even if up to date")
    args = ap.parse_args()

    cli = find_darktable_cli()
    raws = list_raws(args.raw)
    styles = [s for s in collect_styles()
              if args.filter.lower() in s["db_name"].lower()]
    if not raws or not styles:
        sys.exit("error: no matching raw files or styles")

    with tempfile.TemporaryDirectory() as tmp:
        workdir = Path(tmp)
        cfg = init_config(cli, workdir)
        imported = []
        with sqlite3.connect(cfg / "data.db") as db:
            for style in styles:
                try:
                    import_style(db, style)
                    imported.append(style)
                except Exception as e:
                    print(f"WARN  cannot import {style['path'].relative_to(REPO)}: {e}")
        styles = imported
        print(f"{len(styles)} style(s) x {len(raws)} raw(s), {args.jobs} parallel job(s)")

        jobs = []  # one per style: (db_name, display_name, [(raw, out), ...])
        total = len(styles) * len(raws)
        for style in styles:
            pairs = []
            for raw in raws:
                out = (STYLES_DIR / style["collection"] / "images"
                       / f"{style['slug']}_{slugify(raw.stem)}.webp")
                if (args.force or not out.is_file()
                        or out.stat().st_mtime < max(raw.stat().st_mtime,
                                                     style["path"].stat().st_mtime)):
                    pairs.append((raw, out))
            if pairs:
                jobs.append((style["db_name"], f"{style['collection']}/{style['slug']}", pairs))
        to_export = sum(len(pairs) for _, _, pairs in jobs)
        if total - to_export:
            print(f"{total - to_export} already up to date, {to_export} to export")

        failures = export_all(cli, cfg, workdir, jobs, args.jobs)
        if failures:
            print(f"\n{len(failures)} export(s) failed:")
            for rel, err in failures:
                print(f"  {rel}: {err[0]}")
            return 1
    print("done")
    return 0


if __name__ == "__main__":
    sys.exit(main())
