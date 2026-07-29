#!/usr/bin/env python3
"""Run the validators of all collection categories (presets, styles, themes, luts, camera-profiles)."""
import subprocess
import sys
from pathlib import Path

CATEGORIES = ["presets", "styles", "themes", "luts", "camera-profiles"]


def main() -> int:
    root = Path(__file__).parent
    failed = []
    for category in CATEGORIES:
        script = root / category / "validate.py"
        print(f"=== {category} ===", flush=True)
        if not script.is_file():
            print(f"FAIL  {category}/validate.py is missing")
            failed.append(category)
            continue
        result = subprocess.run([sys.executable, str(script)])
        if result.returncode != 0:
            failed.append(category)
        print()
    if failed:
        print(f"FAILED: {', '.join(failed)}")
        return 1
    print("All validations passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
