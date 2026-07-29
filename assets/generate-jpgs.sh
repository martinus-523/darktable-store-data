#!/usr/bin/env bash
# Generate 1200px-wide previews from the raw files in raw-files/, using only
# darktable's stock out-of-the-box processing. A throwaway --configdir is
# used so the user's own darktablerc, default presets and styles are never
# applied. Note: an .xmp sidecar sitting next to a raw WOULD still be
# applied by darktable-cli — keep raw-files/ free of sidecars.
# darktable-cli exports a JPG; as a last step it is converted to WebP with
# cwebp to save disk space, so the final files are .webp.
set -euo pipefail

DARKTABLE_CLI="${DARKTABLE_CLI:-darktable-cli}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAW_DIR="$SCRIPT_DIR/raw-files"
OUT_DIR="$SCRIPT_DIR/jpg"
WIDTH=1200

command -v "$DARKTABLE_CLI" >/dev/null || { echo "error: $DARKTABLE_CLI not found in PATH" >&2; exit 1; }
command -v cwebp >/dev/null || { echo "error: cwebp not found in PATH (brew install webp)" >&2; exit 1; }
# darktable derives its plugin/data paths from the invocation path, so a
# symlinked darktable-cli fails with "cannot find disk storage module".
# Resolve to the real binary before calling it.
DARKTABLE_CLI="$(readlink -f "$(command -v "$DARKTABLE_CLI")")"
[ -d "$RAW_DIR" ] || { echo "error: $RAW_DIR does not exist" >&2; exit 1; }
mkdir -p "$OUT_DIR"

# Fresh, empty config dir => stock darktable defaults, no user presets/styles.
TMP_CONF="$(mktemp -d)"
trap 'rm -rf "$TMP_CONF"' EXIT

shopt -s nullglob nocaseglob
for raw in "$RAW_DIR"/*.{arw,cr2,cr3,nef,dng,raf,orf,rw2,pef,srw}; do
    base="$(basename "$raw")"
    out="$OUT_DIR/${base%.*}.webp"
    tmp_jpg="$TMP_CONF/${base%.*}.jpg"
    if [ -f "$out" ] && [ "$out" -nt "$raw" ]; then
        echo "skip  ${base%.*}.webp (up to date)"
        continue
    fi
    echo "export $base -> ${out#"$SCRIPT_DIR/"}"
    "$DARKTABLE_CLI" "$raw" "$tmp_jpg" \
        --width "$WIDTH" --height 0 \
        --upscale false \
        --apply-custom-presets false \
        --core \
        --configdir "$TMP_CONF" \
        --library ':memory:' \
        --conf write_sidecar_files=never \
        --conf plugins/imageio/format/jpeg/quality=90
    cwebp -quiet -q 90 "$tmp_jpg" -o "$out"
    rm -f "$tmp_jpg"
done
shopt -u nullglob nocaseglob

echo "done: $(ls "$OUT_DIR"/*.webp 2>/dev/null | wc -l | tr -d ' ') webp(s) in ${OUT_DIR#"$SCRIPT_DIR/"}/"
