#!/usr/bin/env python3
"""Generate the iOS app icon set, drawn rather than screenshotted.

Godot's iOS export refuses with "configuration errors" if the required icons are absent, and a
cropped gameplay frame is the wrong answer anyway: at 120px an App Store icon has to read as ONE
shape. A screenshot of three shelves reads as noise at that size.

So the icon is the game reduced to its single idea — a bright pin crossing a molten drop, on the
dark chamber colour. It survives being shrunk, which is the only test that matters here.

    make_icons.py            # write every size the preset asks for
"""
from __future__ import annotations

import os

from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(HERE, "art", "icons")

# iPhone-only (targeted_device_family=1) plus the App Store icon, which is always required.
SIZES = {
    # Android launcher icons must be these exact sizes; Godot validates them and refuses the
    # export rather than scaling on your behalf.
    "icon_432.png": 432,
    "icon_192.png": 192,
    "icon_1024.png": 1024,
    "icon_180.png": 180,
    "icon_120.png": 120,
    "icon_87.png": 87,
    "icon_80.png": 80,
    "icon_60.png": 60,
    "icon_58.png": 58,
    "icon_40.png": 40,
}

BG_TOP = (30, 26, 24)
BG_BOTTOM = (12, 11, 13)
MOLTEN = (255, 122, 26)
MOLTEN_HOT = (255, 214, 120)
STEEL = (226, 232, 240)
STEEL_DARK = (140, 150, 165)


def draw_master(n: int = 1024) -> Image.Image:
    """The game in one shape: molten pouring through a gap, and the pin that was holding it.

    The first attempt drew a big blob with satellite circles and it read as a paw print — three
    lumps around a disc is a face, not a liquid. Redrawn as a POUR: a wide body above, a narrow
    falling stream, a splash. Falling liquid is legible at 40px because the silhouette tapers,
    which a circle never does.
    """
    img = Image.new("RGB", (n, n), BG_BOTTOM)
    d = ImageDraw.Draw(img)
    for y in range(n):
        t = (y / n) ** 0.8
        d.line([(0, y), (n, y)],
               fill=tuple(int(BG_TOP[i] + (BG_BOTTOM[i] - BG_TOP[i]) * t) for i in range(3)))

    def pour(canvas, colour):
        c = ImageDraw.Draw(canvas)
        cx = n // 2
        # Reservoir above the gap, clipped by the pin so it reads as being HELD.
        c.rounded_rectangle([int(n * 0.24), int(n * 0.20), int(n * 0.76), int(n * 0.40)],
                            radius=int(n * 0.05), fill=colour)
        # The stream: a taper from the gap down to the splash, drawn as a polygon so the edges
        # are straight-ish like real falling liquid rather than a stack of circles.
        c.polygon([(cx - int(n * 0.085), int(n * 0.40)),
                   (cx + int(n * 0.085), int(n * 0.40)),
                   (cx + int(n * 0.052), int(n * 0.70)),
                   (cx - int(n * 0.052), int(n * 0.70))], fill=colour)
        # Splash pool.
        c.ellipse([cx - int(n * 0.20), int(n * 0.66), cx + int(n * 0.20), int(n * 0.84)],
                  fill=colour)
        # Two thrown droplets: asymmetric on purpose, so the icon has a direction.
        c.ellipse([cx - int(n * 0.28), int(n * 0.60), cx - int(n * 0.22), int(n * 0.66)],
                  fill=colour)
        c.ellipse([cx + int(n * 0.235), int(n * 0.555), cx + int(n * 0.285), int(n * 0.605)],
                  fill=colour)

    glow = Image.new("RGB", (n, n), (0, 0, 0))
    pour(glow, MOLTEN)
    glow = glow.filter(ImageFilter.GaussianBlur(int(n * 0.05)))
    img = Image.blend(img, Image.blend(img, glow, 0.9), 0.8)

    pour(img, MOLTEN)
    d = ImageDraw.Draw(img)
    # Hot core down the middle of the stream — the thing that says "molten" rather than "orange".
    cx = n // 2
    d.rounded_rectangle([int(n * 0.30), int(n * 0.235), int(n * 0.56), int(n * 0.315)],
                        radius=int(n * 0.03), fill=MOLTEN_HOT)
    d.polygon([(cx - int(n * 0.032), int(n * 0.42)), (cx + int(n * 0.032), int(n * 0.42)),
               (cx + int(n * 0.018), int(n * 0.64)), (cx - int(n * 0.018), int(n * 0.64))],
              fill=MOLTEN_HOT)

    # The pin, crossing exactly where the reservoir ends and the stream begins. That overlap is
    # the whole story: this was plugged a second ago.
    py = int(n * 0.415)
    ph = int(n * 0.105)
    d.rounded_rectangle([int(n * 0.07), py - ph // 2, int(n * 0.72), py + ph // 2],
                        radius=ph // 2, fill=STEEL_DARK)
    d.rounded_rectangle([int(n * 0.085), py - ph // 2 + ph // 7,
                         int(n * 0.70), py + ph // 14], radius=ph // 3, fill=STEEL)
    return img


def main() -> int:
    os.makedirs(OUT, exist_ok=True)
    master = draw_master(1024)
    for name, size in SIZES.items():
        # LANCZOS down from a single 1024 master: rendering each size separately makes the pin
        # land on a different sub-pixel row at every scale and the set stops looking like one icon.
        master.resize((size, size), Image.LANCZOS).save(os.path.join(OUT, name))
        print(f"  {name:<16} {size}x{size}")
    print(f"\n{len(SIZES)} icons in {os.path.relpath(OUT, HERE)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
