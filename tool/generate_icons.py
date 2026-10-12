#!/usr/bin/env python3
"""Export the repository's SVG mark for the existing Flutter platform catalogs."""
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "branding/mediflow-mark.svg"


def export(path, size):
    subprocess.run([
        "rsvg-convert", "--width", str(size), "--height", str(size),
        "--output", str(ROOT / path), str(SOURCE),
    ], check=True)


def main():
    export("web/favicon.png", 32)
    for size in (192, 512):
        for name in (f"Icon-{size}.png", f"Icon-maskable-{size}.png"):
            export(f"web/icons/{name}", size)
    for density, size in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        export(f"android/app/src/main/res/mipmap-{density}/ic_launcher.png", size)
    for platform in ("ios", "macos"):
        folder = Path(f"{platform}/Runner/Assets.xcassets/AppIcon.appiconset")
        catalog = json.loads((ROOT / folder / "Contents.json").read_text())
        for item in catalog["images"]:
            size = round(float(item["size"].split("x")[0]) * float(item["scale"].rstrip("x")))
            export(folder / item["filename"], size)
    subprocess.run(["magick", str(ROOT / "web/icons/Icon-512.png"),
                    "-define", "icon:auto-resize=256,128,64,48,32,16",
                    str(ROOT / "windows/runner/resources/app_icon.ico")], check=True)


if __name__ == "__main__":
    main()
