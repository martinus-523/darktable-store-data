"""Shared darktable-cli export machinery for generate-style-jpgs.py and
generate-lut-jpgs.py.

darktable-cli can only apply styles that exist in a config's styles database,
so callers build a throwaway darktable config (stock defaults — the user's
own darktablerc/presets are never involved), import their styles into its
data.db, and run the exports through export_all(). Each parallel worker gets
its own copy of the config because darktable locks its databases.

darktable-cli startup (~3.5s) dwarfs the per-image work (~0.5s), so each job
is one invocation per style over a directory of symlinks to the raws that
need regenerating, rather than one invocation per (style, raw) pair.

darktable-cli exports JPGs; as a last step each one is converted to WebP with
cwebp to save disk space, so the final preview files are .webp.
"""
import re
import shutil
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from queue import Queue

ASSETS = Path(__file__).resolve().parent
REPO = ASSETS.parent
RAW_DIR = ASSETS / "raw-files"
RAW_EXTS = {".arw", ".cr2", ".cr3", ".nef", ".dng", ".raf", ".orf", ".rw2", ".pef", ".srw"}
WIDTH = "1200"


def slugify(text: str) -> str:
    return re.sub(r"-+", "-", re.sub(r"[^a-z0-9]+", "-", text.lower())).strip("-")


def find_darktable_cli() -> str:
    path = shutil.which("darktable-cli")
    if not path:
        sys.exit("error: darktable-cli not found in PATH")
    # darktable derives its plugin paths from the invocation path; a symlink
    # breaks it ("cannot find disk storage module"), so resolve it first.
    return str(Path(path).resolve())


def find_cwebp() -> str:
    path = shutil.which("cwebp")
    if not path:
        sys.exit("error: cwebp not found in PATH (brew install webp)")
    return path


def list_raws(name_filter: str = "") -> list[Path]:
    return sorted(p for p in RAW_DIR.iterdir()
                  if p.suffix.lower() in RAW_EXTS and name_filter.lower() in p.name.lower())


def init_config(cli: str, workdir: Path) -> Path:
    """Create a stock darktable config dir whose data.db styles the caller fills in."""
    cfg = workdir / "cfg"
    subprocess.run(  # bogus export solely so darktable initializes the config
        [cli, "/nonexistent.raw", str(workdir / "init.jpg"),
         "--core", "--configdir", str(cfg), "--library", ":memory:"],
        capture_output=True)
    if not (cfg / "data.db").is_file():
        sys.exit("error: darktable-cli did not initialize the config dir")
    for lock in cfg.glob("*.lock"):
        lock.unlink()
    return cfg


def export_all(cli: str, cfg: Path, workdir: Path, jobs: list, njobs: int,
               extra_conf: tuple = ()) -> list:
    """Run all export jobs; returns [(failed_out_rel_to_repo, err_lines), ...].

    jobs: one entry per style: (db_name, display_name, [(raw, out), ...]).
    extra_conf: additional "key=value" strings passed as --conf flags.
    """
    cwebp = find_cwebp()
    configs: Queue[Path] = Queue()
    for i in range(njobs):
        worker_cfg = workdir / f"cfg-{i}"
        shutil.copytree(cfg, worker_cfg)
        configs.put(worker_cfg)

    to_export = sum(len(pairs) for _, _, pairs in jobs)
    failures = []
    done = 0

    def export(job):
        nonlocal done
        db_name, name, pairs = job
        jobdir = workdir / "jobs" / db_name
        indir, outdir = jobdir / "in", jobdir / "out"
        indir.mkdir(parents=True)
        outdir.mkdir()
        for raw, out in pairs:
            (indir / (slugify(raw.stem) + raw.suffix)).symlink_to(raw)
        worker_cfg = configs.get()
        print(f"...   {name} ({len(pairs)} raw(s))", flush=True)
        try:
            proc = subprocess.Popen(
                [cli, str(indir), str(outdir / "$(FILE_NAME).jpg"),
                 "--width", WIDTH, "--height", "0",
                 "--upscale", "false", "--style", db_name,
                 "--core", "--configdir", str(worker_cfg), "--library", ":memory:",
                 "--conf", "write_sidecar_files=never",
                 "--conf", "plugins/imageio/format/jpeg/quality=90",
                 *(flag for kv in extra_conf for flag in ("--conf", kv))],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            seen = 0
            while True:  # poll exports so slow styles still show progress
                try:
                    _, stderr = proc.communicate(timeout=5)
                    break
                except subprocess.TimeoutExpired:
                    n = len(list(outdir.glob("*.jpg")))
                    if n > seen:
                        seen = n
                        print(f"...   {name}: {n}/{len(pairs)}", flush=True)
            r = subprocess.CompletedProcess(proc.args, proc.returncode, "", stderr)
        finally:
            configs.put(worker_cfg)
        done += len(pairs)
        failed = []
        for raw, out in pairs:
            produced = outdir / (slugify(raw.stem) + ".jpg")
            if not produced.is_file():
                failed.append((out.relative_to(REPO),
                               r.stderr.strip().splitlines()[-1:] or ["unknown error"]))
                continue
            out.parent.mkdir(parents=True, exist_ok=True)
            conv = subprocess.run([cwebp, "-quiet", "-q", "90", str(produced),
                                   "-o", str(out)], capture_output=True, text=True)
            if conv.returncode != 0 or not out.is_file():
                failed.append((out.relative_to(REPO),
                               conv.stderr.strip().splitlines()[-1:] or ["cwebp failed"]))
        failures.extend(failed)
        shutil.rmtree(jobdir)
        status = f", {len(failed)} FAILED" if failed else ""
        print(f"[{done}/{to_export}] {name} ({len(pairs)} raw(s){status})", flush=True)

    with ThreadPoolExecutor(max_workers=njobs) as pool:
        list(pool.map(export, jobs))
    return failures
