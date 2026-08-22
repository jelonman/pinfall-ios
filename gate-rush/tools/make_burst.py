"""Generate the impact burst sprite the gauntlet has asked for in every single round.

Every verdict has said some version of: "the collision is a scatter of white dots — no flash, no
shockwave, no radial streaks. The reference sells its impact with a bright white starburst." It is
the one NEW ASSET that has been ranked worth its cost every time, and "satisfying smash" is
literally what the reference's own banner promises.

Two sprites, both with alpha so they can be additive billboards:
  burst.png  — a radial starburst: bright core, long spikes, short spikes between them
  ring.png   — a soft expanding shock ring

    python3 tools/make_burst.py
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "tex")


def burst(size=512, spikes=12):
    im = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    d = ImageDraw.Draw(im)
    c = size / 2.0
    for i in range(spikes * 2):
        ang = (math.pi * 2.0) * i / (spikes * 2)
        # alternate long and short spikes, which is what reads as a star rather than a blob
        length = c * (0.94 if i % 2 == 0 else 0.52)
        width = c * (0.085 if i % 2 == 0 else 0.055)
        tipx, tipy = c + math.cos(ang) * length, c + math.sin(ang) * length
        px, py = -math.sin(ang) * width, math.cos(ang) * width
        d.polygon([(c + px, c + py), (tipx, tipy), (c - px, c - py)],
                  fill=(255, 255, 255, 235))
    # a solid core so the centre is the brightest point
    r = c * 0.30
    d.ellipse([c - r, c - r, c + r, c + r], fill=(255, 255, 255, 255))
    im = im.filter(ImageFilter.GaussianBlur(size * 0.012))
    return im


def ring(size=512):
    im = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    d = ImageDraw.Draw(im)
    c = size / 2.0
    for i, (rr, a) in enumerate([(0.94, 90), (0.90, 180), (0.86, 235), (0.82, 180), (0.78, 90)]):
        r = c * rr
        d.ellipse([c - r, c - r, c + r, c + r], outline=(255, 255, 255, a),
                  width=max(2, int(size * 0.018)))
    return im.filter(ImageFilter.GaussianBlur(size * 0.010))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, im in (("burst.png", burst()), ("ring.png", ring())):
        p = os.path.join(OUT, name)
        im.save(p)
        print("wrote %s  %dx%d RGBA" % (p, im.width, im.height))
