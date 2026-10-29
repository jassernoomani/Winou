"""Puts each design (design/winou-screens.html) next to the app's screenshot of the same screen.

    flutter test tool/screenshots --update-goldens
    python tool/screenshots/compare.py

writes tool/screenshots/out/compare/<screen>_<theme>.png: design left, app right. Needs Microsoft Edge.
"""
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image

HERE = Path(__file__).parent
DESIGN = HERE.parents[2] / "design"
OUT = HERE / "out"
EDGE = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"

sys.path.insert(0, str(DESIGN))
import build_screens as b  # noqa: E402


def render(fn, theme: str, png: Path, tmp: Path) -> None:
    photos = ":root{" + "".join(f"--{k}:url({v});" for k, v in b.PHOTOS.items()) + "}"
    html = (f'<!doctype html><html><head><meta charset="utf-8">'
            f'<link href="https://fonts.googleapis.com/css2?family=Nunito:wght@400;600;700;800;900&display=swap" rel="stylesheet">'
            f'<style>{photos}{b.CSS} body{{margin:0}} .screen{{position:fixed;left:0;top:0;margin:0}}</style></head>'
            f'<body><div class="screen {theme}">{fn()}</div></body></html>'
            ).replace("url(__cat__)", "var(--cat)").replace("url(__dog__)", "var(--dog)")
    page = tmp / "screen.html"
    page.write_text(html, encoding="utf-8")
    subprocess.run([EDGE, "--headless", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=2",
                    "--window-size=360,800", f"--screenshot={png}", "--virtual-time-budget=4000", page.as_uri()],
                   capture_output=True, check=True)


def main() -> None:
    screens = [fn for _, section in b.SECTIONS for _, fn in section]
    (OUT / "compare").mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        for shot in sorted(OUT.glob("[0-9][0-9]_*.png")):
            number, theme = int(shot.name[:2]), shot.stem.rsplit("_", 1)[1]
            design = Path(tmp) / "design.png"
            render(screens[number - 1], theme, design, Path(tmp))
            left, right = Image.open(design).convert("RGB"), Image.open(shot).convert("RGB")
            right = right.resize(left.size)
            sheet = Image.new("RGB", (left.width * 2 + 20, left.height), "#808080")
            sheet.paste(left, (0, 0))
            sheet.paste(right, (left.width + 20, 0))
            sheet.thumbnail((1000, 1000))
            sheet.save(OUT / "compare" / shot.name)
            print(shot.name)


if __name__ == "__main__":
    main()
