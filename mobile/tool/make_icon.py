"""Winou app icon: a white location pin holding a paw, on a blue-to-indigo gradient.

Usage (needs Pillow): python tool/make_icon.py assets/icon && dart run flutter_launcher_icons

Writes into the folder given as argv[1]:
  icon.png       1024 full icon (legacy launchers, Play Store)
  icon_bg.png    1024 adaptive background (gradient)
  icon_fg.png    1024 adaptive foreground (pin + paw in the safe zone, transparent)
  icon_mono.png  1024 Android 13 themed icon (white pin with the paw cut out)
"""
import math
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

OUT = Path(sys.argv[1])
SS = 4  # supersampling
N = 1024 * SS

TOP_LEFT = (56, 132, 255)     # bright blue
BOTTOM_RIGHT = (67, 56, 202)  # indigo
PAW = (37, 99, 235)


def gradient(size):
    """Diagonal blue -> indigo with a soft light spot top-left."""
    small = 256
    img = Image.new("RGB", (small, small))
    px = img.load()
    for y in range(small):
        for x in range(small):
            t = (x + y) / (2 * (small - 1))
            px[x, y] = tuple(round(a + (b - a) * t) for a, b in zip(TOP_LEFT, BOTTOM_RIGHT))
    img = img.resize((size, size), Image.BICUBIC)
    glow = Image.new("L", (size, size), 0)
    ImageDraw.Draw(glow).ellipse((-size * 0.25, -size * 0.3, size * 0.75, size * 0.6), fill=70)
    glow = glow.filter(ImageFilter.GaussianBlur(size * 0.12))
    return Image.composite(Image.new("RGB", (size, size), (255, 255, 255)), img, glow)


def pin_mask(size, scale, cy_offset=0.0):
    """Location pin silhouette: a circle and the two tangents to its tip."""
    m = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(m)
    c = size / 2
    r = 0.30 * size * scale
    cx, cy = c, c - 0.10 * size * scale + cy_offset * size
    tip = (cx, cy + r / 0.6)  # tangents meet at distance r/sin(36.87°)
    a = math.acos(0.6)
    left = (cx - r * math.sin(a), cy + r * math.cos(a))
    right = (cx + r * math.sin(a), cy + r * math.cos(a))
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=255)
    d.polygon([left, right, tip], fill=255)
    return m, (cx, cy, r)


def rotated_ellipse(mask, center, rx, ry, angle):
    w = int(max(rx, ry) * 2.4)
    layer = Image.new("L", (w, w), 0)
    ImageDraw.Draw(layer).ellipse((w / 2 - rx, w / 2 - ry, w / 2 + rx, w / 2 + ry), fill=255)
    layer = layer.rotate(angle, resample=Image.BICUBIC)
    mask.paste(255, (int(center[0] - w / 2), int(center[1] - w / 2)), layer)


def paw_mask(size, circle):
    cx, cy, r = circle
    m = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(m)
    # Main pad: a wide rounded shape made of three overlapping ellipses
    py = cy + 0.22 * r
    d.ellipse((cx - 0.40 * r, py - 0.30 * r, cx + 0.40 * r, py + 0.30 * r), fill=255)
    d.ellipse((cx - 0.46 * r, py - 0.08 * r, cx - 0.06 * r, py + 0.36 * r), fill=255)
    d.ellipse((cx + 0.06 * r, py - 0.08 * r, cx + 0.46 * r, py + 0.36 * r), fill=255)
    # Toes
    for dx, dy, angle in ((-0.52, -0.22, 25), (-0.19, -0.50, 8), (0.19, -0.50, -8), (0.52, -0.22, -25)):
        rotated_ellipse(m, (cx + dx * r, cy + dy * r), 0.15 * r, 0.20 * r, angle)
    return m


def art(size, scale):
    """Pin (white) and paw (blue) on transparent."""
    pin, circle = pin_mask(size, scale)
    paw = paw_mask(size, circle)
    shadow = pin.filter(ImageFilter.GaussianBlur(size * 0.012))
    shadow = ImageChops.offset(shadow, 0, int(size * 0.012)).point(lambda v: v * 0.35)
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    img.paste((20, 24, 80, 255), (0, 0), shadow)
    img.paste((255, 255, 255, 255), (0, 0), pin)
    img.paste(PAW + (255,), (0, 0), paw)
    return img, pin, paw


def down(img, size):
    return img.resize((size, size), Image.LANCZOS)


OUT.mkdir(parents=True, exist_ok=True)

bg = gradient(N)
down(bg, 1024).save(OUT / "icon_bg.png")

full_art, _, _ = art(N, 1.0)
full = bg.convert("RGBA")
full.alpha_composite(full_art)
down(full, 1024).save(OUT / "icon.png")

# Adaptive: the visible circle is the middle 72/108 of the canvas, keep the art inside it
fg_art, pin, paw = art(N, 0.62)
down(fg_art, 1024).save(OUT / "icon_fg.png")

mono = Image.new("RGBA", (N, N), (0, 0, 0, 0))
mono.paste((255, 255, 255, 255), (0, 0), ImageChops.subtract(pin, paw))
down(mono, 1024).save(OUT / "icon_mono.png")

print("written to", OUT)
