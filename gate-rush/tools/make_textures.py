"""Generate the surface textures the frame has never had.

Ten blind verdicts have now said some version of "no texture on any surface — road, gates, walls
and characters are all single flat colours". Six rounds of colour and light tuning did not move
that, which is the gauntlet skill's own rule: when a gap will not move, the MECHANISM is wrong.
Flat-shaded primitives cannot be lit into looking like an art-directed asset set. So: real albedo
textures, generated here, no download and no licence question.

    python3 tools/make_textures.py
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "tex")


def asphalt(size=512, seed=7):
    """Warm grey tarmac: fine grain, a few darker patches, faint wear streaks along the lane."""
    rnd = random.Random(seed)
    im = Image.new("RGB", (size, size), (150, 150, 154))
    px = im.load()
    for y in range(size):
        for x in range(size):
            n = rnd.randint(-16, 16)
            r, g, b = px[x, y]
            px[x, y] = (max(0, r + n), max(0, g + n), max(0, b + n))
    d = ImageDraw.Draw(im)
    for _ in range(26):                       # patches of older, darker surface
        cx, cy = rnd.randrange(size), rnd.randrange(size)
        rr = rnd.randrange(28, 90)
        d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=(136, 136, 141))
    im = im.filter(ImageFilter.GaussianBlur(1.1))
    d = ImageDraw.Draw(im)
    for _ in range(70):                       # wear streaks, run along +y so they follow the lane
        x = rnd.randrange(size)
        w = rnd.choice([1, 1, 2])
        v = rnd.randint(-12, 12)
        d.line([(x, 0), (x + rnd.randint(-6, 6), size)], fill=(150 + v, 150 + v, 154 + v), width=w)
    return im.filter(ImageFilter.GaussianBlur(0.5))


def barrier(size=256):
    """A crowd-barrier panel: recessed centre, lit top edge, dark base, one printed chevron."""
    im = Image.new("RGB", (size, size), (196, 202, 214))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, size, int(size * 0.13)], fill=(246, 249, 255))      # lit cap
    d.rectangle([0, int(size * 0.13), size, int(size * 0.17)], fill=(120, 126, 140))
    m = int(size * 0.10)
    d.rectangle([m, int(size * 0.26), size - m, int(size * 0.82)], fill=(168, 176, 192))   # recess
    d.rectangle([m, int(size * 0.26), size - m, int(size * 0.30)], fill=(126, 133, 148))
    d.rectangle([0, int(size * 0.88), size, size], fill=(104, 110, 124))      # dark base
    cx, cy = size // 2, int(size * 0.54)
    d.polygon([(cx - 34, cy + 18), (cx, cy - 18), (cx + 34, cy + 18),
               (cx + 20, cy + 18), (cx, cy - 2), (cx - 20, cy + 18)], fill=(238, 242, 252))
    return im.filter(ImageFilter.GaussianBlur(0.4))


def gate_face(size=256):
    """A gate panel face: bevelled frame, inner plate, gloss band across the top third."""
    im = Image.new("RGB", (size, size), (255, 255, 255))
    d = ImageDraw.Draw(im)
    b = int(size * 0.055)
    d.rectangle([0, 0, size, size], fill=(236, 236, 240))                  # outer bevel, light
    d.rectangle([b, b, size - b, size - b], fill=(255, 255, 255))          # inner plate
    d.rectangle([b, b, size - b, b + int(size * 0.03)], fill=(255, 255, 255))
    d.rectangle([b, size - b - int(size * 0.05), size - b, size - b], fill=(206, 206, 214))
    for i in range(int(size * 0.30)):                                      # gloss falloff
        v = 255 - int(i * 0.16)
        d.line([(b, b + i), (size - b, b + i)], fill=(v, v, v))
    return im.filter(ImageFilter.GaussianBlur(0.6))


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, im in [("asphalt.png", asphalt()), ("barrier.png", barrier()),
                     ("gate_face.png", gate_face())]:
        p = os.path.join(OUT, name)
        im.save(p)
        print("wrote %s  %dx%d" % (p, im.width, im.height))


if __name__ == "__main__":
    main()
