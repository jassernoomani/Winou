"""Copies the README's screenshots from out/ to docs/screenshots/ as compact WebP.

    flutter test tool/screenshots --update-goldens
    python tool/screenshots/readme_shots.py
"""
from pathlib import Path

from PIL import Image

HERE = Path(__file__).parent
TARGET = HERE.parents[2] / "docs" / "screenshots"
SCREENS = {
    "61_home_tabs": "home",
    "08_lost_detail": "lost-pet",
    "12_match_pending": "match",
    "17_map": "map",
    "24_chat": "chat",
    "30_stray_injured": "stray",
    "46_admin_dashboard": "admin-dashboard",
    "44_admin_reported": "admin-reported",
}

TARGET.mkdir(parents=True, exist_ok=True)
for source, name in SCREENS.items():
    for theme in ("light", "dark"):
        image = Image.open(HERE / "out" / f"{source}_{theme}.png").convert("RGB")
        image = image.resize((540, image.height * 540 // image.width), Image.LANCZOS)
        out = TARGET / f"{name}-{theme}.webp"
        image.save(out, "WEBP", quality=86, method=6)
        print(f"{out.relative_to(TARGET.parents[1])}  {out.stat().st_size // 1024} KB")
