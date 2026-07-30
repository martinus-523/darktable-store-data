#!/usr/bin/env python3
"""Generate LUT preview JPGs for every LUT in the repository.

For each LUT file listed in luts/<collection>/meta.json and each raw file in
assets/raw-files/, exports a 1200px-wide JPG with that LUT applied and
converts it to WebP (to save disk space), into
luts/<collection>/images/<lutname>_<rawname>.webp. The unstyled "before"
images are produced by generate-jpgs.sh; the shared darktable-cli export
machinery lives in dt_export.py.

darktable-cli cannot apply a LUT file directly, so for each LUT this script
synthesizes a one-module style — lut3d pointing at the file, with the repo's
luts/ folder passed as plugins/darkroom/lut3d/def_path — into the throwaway
config's data.db and exports with --style. Collections whose input-colorspace
the lut3d module cannot represent (e.g. V-Log, Rec.2100 PQ) are skipped with
a warning and get no preview images.

Usage:
  generate-lut-webps.py                # everything (skips images that already exist)
  generate-lut-webps.py --filter sensia --raw portrait
  generate-lut-webps.py --jobs 4 --force     # regenerate even if the image exists
"""
import argparse
import json
import sqlite3
import struct
import sys
import tempfile
from pathlib import Path

from dt_export import REPO, export_all, find_darktable_cli, init_config, list_raws, slugify

LUTS_DIR = REPO / "luts"
# dt_iop_lut3d_colorspace_t in darktable's src/iop/lut3d.c
COLORSPACES = {
    "sRGB": 0,
    "Adobe RGB": 1,
    "gamma Rec.709": 2,
    "linear Rec.709": 3,
    "linear Rec.2020": 4,
    "linear ProPhoto": 5,
}
LUT_EXTS = {".cube", ".3dl", ".png"}  # .gmz bundles need a lut name; not supported


def lut3d_params(relpath: str, colorspace: int) -> bytes:
    """dt_iop_lut3d_params_t version 3: char[512] filepath, int colorspace,
    int interpolation (0 = tetrahedral), int nb_keypoints, char[12288] c_clut,
    char[128] lutname."""
    path = relpath.encode()
    if len(path) > 511:
        raise ValueError(f"lut path too long: {relpath}")
    return path.ljust(512, b"\0") + struct.pack("<iii", colorspace, 0, 0) + bytes(12288 + 128)


def collect_luts() -> list[dict]:
    """One entry per supported LUT file: collection, slug, unique db name, path."""
    luts = []
    seen = set()
    for collection in sorted(p for p in LUTS_DIR.iterdir() if p.is_dir()):
        try:
            meta = json.loads((collection / "meta.json").read_text())
        except (OSError, json.JSONDecodeError) as e:
            print(f"WARN  {collection.name}: cannot read meta.json ({e}), skipping")
            continue
        colorspace = COLORSPACES.get(meta.get("input-colorspace"))
        if colorspace is None:
            print(f"WARN  {collection.name}: lut3d does not support input-colorspace "
                  f"'{meta.get('input-colorspace')}', skipping")
            continue
        for name in meta.get("files") or []:
            path = collection / "luts" / name
            if Path(name).suffix.lower() not in LUT_EXTS:
                print(f"WARN  {collection.name}: unsupported LUT type '{name}', skipping")
                continue
            if not path.is_file():
                print(f"WARN  {collection.name}: missing LUT file '{name}', skipping")
                continue
            slug = slugify(Path(name).stem) or "lut"
            db_name = f"{collection.name}__{slug}"
            n = 2
            while db_name in seen:
                db_name = f"{collection.name}__{slug}-{n}"
                n += 1
            seen.add(db_name)
            luts.append({"collection": collection.name, "slug": db_name.split("__", 1)[1],
                         "db_name": db_name, "path": path, "colorspace": colorspace})
    return luts


def import_lut(db: sqlite3.Connection, lut: dict) -> None:
    params = lut3d_params(str(lut["path"].relative_to(LUTS_DIR)), lut["colorspace"])
    cur = db.execute("INSERT INTO styles (name, description, iop_list) VALUES (?, ?, NULL)",
                     (lut["db_name"], ""))
    db.execute(
        """INSERT INTO style_items (styleid, num, module, operation, op_params,
           enabled, blendop_params, blendop_version, multi_priority, multi_name,
           multi_name_hand_edited) VALUES (?, 0, 3, 'lut3d', ?, 1, NULL, 0, 0, '', 0)""",
        (cur.lastrowid, params))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--filter", default="", help="only luts whose collection or name contains this")
    ap.add_argument("--raw", default="", help="only raw files whose name contains this")
    ap.add_argument("--jobs", type=int, default=3, help="parallel darktable-cli instances (default 3)")
    ap.add_argument("--force", action="store_true", help="regenerate even if the image already exists")
    args = ap.parse_args()

    cli = find_darktable_cli()
    raws = list_raws(args.raw)
    luts = [l for l in collect_luts() if args.filter.lower() in l["db_name"].lower()]
    if not raws or not luts:
        sys.exit("error: no matching raw files or luts")

    with tempfile.TemporaryDirectory() as tmp:
        workdir = Path(tmp)
        cfg = init_config(cli, workdir)
        imported = []
        with sqlite3.connect(cfg / "data.db") as db:
            for lut in luts:
                try:
                    import_lut(db, lut)
                    imported.append(lut)
                except Exception as e:
                    print(f"WARN  cannot import {lut['path'].relative_to(REPO)}: {e}")
        luts = imported
        print(f"{len(luts)} lut(s) x {len(raws)} raw(s), {args.jobs} parallel job(s)")

        jobs = []  # one per lut: (db_name, display_name, [(raw, out), ...])
        total = len(luts) * len(raws)
        for lut in luts:
            pairs = []
            for raw in raws:
                out = (LUTS_DIR / lut["collection"] / "images"
                       / f"{lut['slug']}_{slugify(raw.stem)}.webp")
                if args.force or not out.is_file():
                    pairs.append((raw, out))
            if pairs:
                jobs.append((lut["db_name"], f"{lut['collection']}/{lut['slug']}", pairs))
        to_export = sum(len(pairs) for _, _, pairs in jobs)
        if total - to_export:
            print(f"{total - to_export} already exist, {to_export} to export")

        failures = export_all(cli, cfg, workdir, jobs, args.jobs,
                              extra_conf=(f"plugins/darkroom/lut3d/def_path={LUTS_DIR}",))
        if failures:
            print(f"\n{len(failures)} export(s) failed:")
            for rel, err in failures:
                print(f"  {rel}: {err[0]}")
            return 1
    print("done")
    return 0


if __name__ == "__main__":
    sys.exit(main())
