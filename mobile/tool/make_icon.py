"""Winou app icon: a map pin dropped on the map, holding a paw whose main pad is a heart, with
radar rings around it (searching nearby), on the brand's blue-to-indigo gradient.

Usage (needs Pillow): python tool/make_icon.py assets/icon && dart run flutter_launcher_icons

Writes into the folder given as argv[1] (all 1024 x 1024, drawn at 4096 and scaled down):
  icon.png       full icon (legacy launchers, iOS, Play Store)
  icon_bg.png    adaptive background: gradient and radar rings
  icon_fg.png    adaptive foreground: pin, paw and ground shadow, inside the safe zone
  icon_mono.png  Android 13 themed icon: white pin with the paw cut out
  splash.png     the pin alone, for the launch screen (transparent)
"""
import math
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

OUT = Path(sys.argv[1])
N = 4096  # drawn at 4x, then scaled down

TOP_LEFT = (64, 140, 255)
BOTTOM_RIGHT = (67, 48, 196)
TOE_TOP, TOE_BOTTOM = (59, 130, 246), (67, 56, 202)       # brand blue -> indigo
HEART_TOP, HEART_BOTTOM = (251, 113, 133), (225, 29, 72)  # coral -> rose
PIN_TOP, PIN_BOTTOM = (255, 255, 255), (224, 231, 255)


def vertical(size, top, bottom, box=None):
    """A vertical gradient image (over the box's height if given)."""
    y0, y1 = (box[1], box[3]) if box else (0, size)
    col = Image.new("RGB", (1, size))
    px = col.load()
    for y in range(size):
        t = min(1.0, max(0.0, (y - y0) / max(1, y1 - y0)))
        px[0, y] = tuple(round(a + (b - a) * t) for a, b in zip(top, bottom))
    return col.resize((size, size))


def background(size, circle):
    """Diagonal blue -> indigo, light top-left, darker bottom-right, radar rings around the pin."""
    small = 256
    img = Image.new("RGB", (small, small))
    px = img.load()
    for y in range(small):
        for x in range(small):
            t = (x + y) / (2 * (small - 1))
            px[x, y] = tuple(round(a + (b - a) * t) for a, b in zip(TOP_LEFT, BOTTOM_RIGHT))
    img = img.resize((size, size), Image.BICUBIC).convert("RGBA")

    glow = Image.new("L", (size, size), 0)
    ImageDraw.Draw(glow).ellipse((-size * 0.3, -size * 0.35, size * 0.7, size * 0.55), fill=80)
    img.paste((255, 255, 255, 255), (0, 0), glow.filter(ImageFilter.GaussianBlur(size * 0.14)))
    shade = Image.new("L", (size, size), 0)
    ImageDraw.Draw(shade).ellipse((size * 0.45, size * 0.55, size * 1.4, size * 1.5), fill=70)
    img.paste((30, 20, 110, 255), (0, 0), shade.filter(ImageFilter.GaussianBlur(size * 0.15)))

    # Radar rings, fading outwards: "looking for them, nearby"
    cx, cy, r = circle
    rings = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(rings)
    for k, (radius, alpha) in enumerate(((1.45, 70), (1.95, 46), (2.5, 26), (3.1, 12))):
        rr = r * radius
        d.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), outline=alpha, width=int(size * (0.010 - k * 0.0015)))
    img.paste((255, 255, 255, 255), (0, 0), rings.filter(ImageFilter.GaussianBlur(size * 0.0015)))
    return img


def pin_mask(size, scale, lift=0.10):
    """Location pin: a circle and the two tangents meeting at its tip."""
    m = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(m)
    c = size / 2
    r = 0.29 * size * scale
    cx, cy = c, c - lift * size * scale
    a = math.acos(0.6)
    tip = (cx, cy + r / 0.6)
    left = (cx - r * math.sin(a), cy + r * math.cos(a))
    right = (cx + r * math.sin(a), cy + r * math.cos(a))
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=255)
    d.polygon([left, right, tip], fill=255)
    return m, (cx, cy, r), tip


def ellipse_mask(size, center, rx, ry, angle):
    m = Image.new("L", (size, size), 0)
    w = int(max(rx, ry) * 2.4)
    layer = Image.new("L", (w, w), 0)
    ImageDraw.Draw(layer).ellipse((w / 2 - rx, w / 2 - ry, w / 2 + rx, w / 2 + ry), fill=255)
    layer = layer.rotate(angle, resample=Image.BICUBIC)
    m.paste(255, (int(center[0] - w / 2), int(center[1] - w / 2)), layer)
    return m


def heart_mask(size, center, width):
    """The classic heart curve, scaled to [width], pointing down."""
    cx, cy = center
    s = width / 34
    points = []
    for i in range(720):
        t = 2 * math.pi * i / 720
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        points.append((cx + x * s, cy - y * s))
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).polygon(points, fill=255)
    return m


def paw_masks(size, circle):
    """Four toes and a heart-shaped main pad, inside the pin's head."""
    cx, cy, r = circle
    heart = heart_mask(size, (cx, cy + 0.24 * r), 0.88 * r)
    toes = Image.new("L", (size, size), 0)
    for dx, dy, rx, ry, angle in ((-0.60, -0.22, 0.145, 0.195, 30), (-0.235, -0.53, 0.155, 0.21, 10),
                                  (0.235, -0.53, 0.155, 0.21, -10), (0.60, -0.22, 0.145, 0.195, -30)):
        toes = ImageChops.lighter(toes, ellipse_mask(size, (cx + dx * r, cy + dy * r), rx * r, ry * r, angle))
    return toes, heart


def art(size, scale, ground=True):
    """Pin, paw and the pin's shadow on the ground, on transparent. Returns the image and masks."""
    pin, circle, tip = pin_mask(size, scale)
    cx, cy, r = circle
    toes, heart = paw_masks(size, circle)
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))

    if ground:  # the pin stands on the map: a soft oval shadow under its tip
        g = Image.new("L", (size, size), 0)
        ImageDraw.Draw(g).ellipse((tip[0] - 0.42 * r, tip[1] - 0.10 * r, tip[0] + 0.42 * r, tip[1] + 0.10 * r),
                                  fill=110)
        img.paste((15, 12, 70, 255), (0, 0), g.filter(ImageFilter.GaussianBlur(size * 0.012)))

    drop = ImageChops.offset(pin.filter(ImageFilter.GaussianBlur(size * 0.018)), int(size * 0.006),
                             int(size * 0.018)).point(lambda v: v * 0.42)
    img.paste((20, 16, 80, 255), (0, 0), drop)

    box = (0, cy - r, 0, cy + r / 0.6)
    img.paste(vertical(size, PIN_TOP, PIN_BOTTOM, box).convert("RGBA"), (0, 0), pin)
    # A soft highlight on the top-left of the pin's head: it reads as glossy, not flat
    shine = Image.new("L", (size, size), 0)
    ImageDraw.Draw(shine).ellipse((cx - 0.82 * r, cy - 0.9 * r, cx + 0.1 * r, cy - 0.1 * r), fill=60)
    shine = ImageChops.multiply(shine.filter(ImageFilter.GaussianBlur(size * 0.02)), pin)
    img.paste((255, 255, 255, 255), (0, 0), shine)

    paw_box = (0, cy - 0.7 * r, 0, cy + 0.75 * r)
    img.paste(vertical(size, TOE_TOP, TOE_BOTTOM, paw_box).convert("RGBA"), (0, 0), toes)
    img.paste(vertical(size, HEART_TOP, HEART_BOTTOM, (0, cy - 0.2 * r, 0, cy + 0.75 * r)).convert("RGBA"), (0, 0),
              heart)
    return img, pin, ImageChops.lighter(toes, heart), circle


def down(img, size=1024):
    return img.resize((size, size), Image.LANCZOS)


OUT.mkdir(parents=True, exist_ok=True)

# Full icon (iOS, Play Store, legacy launchers)
full_art, _, _, circle = art(N, 0.92)
full = background(N, circle)
full.alpha_composite(full_art)
down(full.convert("RGB")).save(OUT / "icon.png")

# Adaptive icon: launchers mask the middle 72/108 of the canvas and may move it; the art keeps to
# the 66/108 safe circle. The rings live in the background layer, centred on the pin's head.
fg_art, pin, paw, fg_circle = art(N, 0.6)
down(fg_art).save(OUT / "icon_fg.png")
down(background(N, fg_circle).convert("RGB")).save(OUT / "icon_bg.png")

mono = Image.new("RGBA", (N, N), (0, 0, 0, 0))
mono.paste((255, 255, 255, 255), (0, 0), ImageChops.subtract(pin, paw))
down(mono).save(OUT / "icon_mono.png")

# Launch screen: the pin alone, no ground shadow (the splash draws its own scene)
splash_art, _, _, _ = art(N, 0.9, ground=False)
down(splash_art).save(OUT / "splash.png")

print("written to", OUT)
