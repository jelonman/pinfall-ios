"""Texture for the crowd unit: a face plate, a dark wheeled base band, and an accent stripe.

Every verdict so far has ranked the unit silhouette first or third, and the last two named exactly
what is missing: "no face, no wheels, no second colour". Geometry alone has been tried twice (a
sphere head, then a helmet) and both were read as marbles or cubes. A texture puts the detail
where a 40 px silhouette can actually carry it.

    python3 tools/make_unit_tex.py
"""
import os

from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "tex")


def unit(size=256):
    im = Image.new("RGB", (size, size), (255, 255, 255))
    d = ImageDraw.Draw(im)
    # the sphere's V runs top (crown) to bottom (base); bands are horizontal strips
    d.rectangle([0, 0, size, int(size * 0.18)], fill=(255, 255, 255))              # lit crown
    d.rectangle([0, int(size * 0.18), size, int(size * 0.30)], fill=(232, 236, 246))
    d.rectangle([0, int(size * 0.30), size, int(size * 0.62)], fill=(255, 255, 255))  # body
    d.rectangle([0, int(size * 0.62), size, int(size * 0.70)], fill=(120, 190, 255))  # accent
    d.rectangle([0, int(size * 0.70), size, int(size * 0.84)], fill=(96, 104, 126))   # shadowed
    d.rectangle([0, int(size * 0.84), size, size], fill=(34, 38, 52))                 # dark base

    # a visor plate across the front — U wraps the sphere, so the front sits mid-U
    cx = int(size * 0.5)
    vy0, vy1 = int(size * 0.34), int(size * 0.46)
    d.rounded_rectangle([cx - int(size * 0.17), vy0, cx + int(size * 0.17), vy1],
                        radius=int(size * 0.04), fill=(26, 32, 48))
    d.rounded_rectangle([cx - int(size * 0.13), vy0 + 3, cx + int(size * 0.13), vy0 + 9],
                        radius=3, fill=(120, 200, 255))

    # two dark wheels on the base band
    for sx in (-0.20, 0.20):
        wx = cx + int(size * sx)
        d.ellipse([wx - int(size * 0.075), int(size * 0.855),
                   wx + int(size * 0.075), int(size * 0.985)], fill=(18, 20, 28))
    return im.filter(ImageFilter.GaussianBlur(0.5))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    p = os.path.join(OUT, "unit.png")
    unit().save(p)
    print("wrote %s" % p)
