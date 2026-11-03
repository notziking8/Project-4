"""Downscale the hi-res Blender renders to 32x32 RGBA sprites and build previews.

Usage: python export_sprites.py <hi_dir> <sprite_out_dir> <preview_dir>
All suits share ONE scale (so relative widths/heights survive) and are centred on their bbox.
A 1px dark outline is added (matches the existing pickup art); no backing, floor or shadow.
"""
import sys, os
import numpy as np
from PIL import Image

hi, out, prev = sys.argv[1:4]
names = ["hares-stride", "storm-vessel", "bulls-stance"]
SIZE = 32
MARGIN = 1  # clear pixels between the outline and the canvas edge
OUTLINE = (44, 30, 24)

imgs = {n: Image.open(os.path.join(hi, f"{n}_hi.png")).convert("RGBA") for n in names}
boxes = {n: im.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox() for n, im in imgs.items()}
# the 1px outline eats 2px of the budget
budget = SIZE - 2 * MARGIN - 2
scale = budget / max(max(b[2] - b[0], b[3] - b[1]) for b in boxes.values())
print(boxes, "scale", scale)


def outline(arr):
    a = arr[..., 3] > 0
    p = np.pad(a, 1)
    grow = np.zeros_like(a)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if dx or dy:
                grow |= p[1 + dy:1 + dy + a.shape[0], 1 + dx:1 + dx + a.shape[1]]
    ring = grow & ~a
    arr = arr.copy()
    arr[ring] = (*OUTLINE, 255)
    return arr


sprites = {}
for n, im in imgs.items():
    b = boxes[n]
    w, h = b[2] - b[0], b[3] - b[1]
    nw, nh = max(1, round(w * scale)), max(1, round(h * scale))
    small = im.crop(b).convert("RGBa").resize((nw, nh), Image.BOX).convert("RGBA")
    arr = np.array(small)
    arr[..., 3] = np.where(arr[..., 3] >= 110, 255, 0)  # crisp pixel-art edge
    canvas = np.zeros((SIZE, SIZE, 4), np.uint8)
    ox, oy = (SIZE - nw) // 2, (SIZE - nh) // 2
    canvas[oy:oy + nh, ox:ox + nw] = arr
    canvas = outline(np.pad(canvas, 0))
    sp = Image.fromarray(canvas, "RGBA")
    sprites[n] = sp
    sp.save(os.path.join(out, f"{n}.png"))
    print(n, sp.getchannel("A").getbbox())

DARK = (22, 19, 26, 255)
sheet = Image.new("RGBA", (10 + 3 * 266, 10 + 256 + 20 + 64 + 10), DARK)
for i, n in enumerate(names):
    sheet.alpha_composite(sprites[n].resize((256, 256), Image.NEAREST), (10 + i * 266, 10))
    sheet.alpha_composite(sprites[n], (10 + i * 266, 286))              # actual 1x size
    sheet.alpha_composite(sprites[n].resize((64, 64), Image.NEAREST), (60 + i * 266, 286))
sheet.save(os.path.join(prev, "sprites_on_dark_32px_check.png"))

row = Image.new("RGBA", (3 * 460 + 20, 520), (30, 26, 34, 255))
for i, n in enumerate(names):
    s = Image.new("RGBA", imgs[n].size, (30, 26, 34, 255))
    s.alpha_composite(imgs[n])
    row.alpha_composite(s.resize((460, 460), Image.LANCZOS), (10 + i * 460, 30))
row.save(os.path.join(prev, "armor_preview.png"))
