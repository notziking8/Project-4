"""Pack the worn renders into 64x64 explorer-cell sheets and print the GDScript anchor data.

Usage: python export_worn.py <worn_render_dir> <worn_out_dir> <explorer_walk.png> <explorer_idle.png>
Each <suit>_worn.png is 256x64: one 64x64 cell per facing in the explorer row order
(Down, Left, Right, Up), with the same foot anchor (32,60). One pixel scale is shared by
every suit and facing, so the three silhouettes keep their real relative widths.
"""
import sys, os, json
import numpy as np
from PIL import Image

src, out, walk_path, idle_path = sys.argv[1:5]
SUITS = ["hares-stride", "storm-vessel", "bulls-stance"]
KINDS = {"hares-stride": "light", "storm-vessel": "medium", "bulls-stance": "heavy"}
FACINGS = ["down", "left", "right", "up"]
RES = 512
SCALE = 0.078              # render px -> sprite px (Storm Vessel front is ~25px wide)
NECK_Y = 36                # neck opening sits under the hood's lower edge
TORSO_X = {"down": 32, "left": 34, "right": 30, "up": 32}  # measured torso centres
OUTLINE = (34, 24, 22, 255)

# The camera, suit origin and squash are shared, so the suit's neck centre lands on the
# same render pixel in every image. Find it from Storm Vessel's front render: the neck hole
# is the lining-coloured region nearest the top.
pts = json.load(open(os.path.join(src, "worn_points.json")))


def neck_pixel():
    im = np.array(Image.open(os.path.join(src, "storm-vessel_down.png")).convert("RGBA")).astype(int)
    a = im[..., 3] > 200
    dark = a & (im[..., :3].sum(-1) < 150)
    ys, xs = np.nonzero(dark)
    top = ys.min()
    sel = ys < top + 40
    return xs[sel].mean(), ys[sel].mean()


NX, NY = neck_pixel()


def to_sprite(u, v, facing):
    return ((u * RES - NX) * SCALE + TORSO_X[facing], (v * RES - NY) * SCALE + NECK_Y)


def outline(arr):
    a = arr[..., 3] > 0
    p = np.pad(a, 1)
    grow = np.zeros_like(a)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if dx or dy:
                grow |= p[1 + dy:1 + dy + a.shape[0], 1 + dx:1 + dx + a.shape[1]]
    arr = arr.copy()
    arr[grow & ~a] = OUTLINE
    return arr


big = int(round(RES * SCALE))
for suit in SUITS:
    sheet = np.zeros((64, 256, 4), np.uint8)
    for j, facing in enumerate(FACINGS):
        im = Image.open(os.path.join(src, f"{suit}_{facing}.png")).convert("RGBa")
        small = np.array(im.resize((big, big), Image.BOX).convert("RGBA"))
        small[..., 3] = np.where(small[..., 3] >= 110, 255, 0)
        cell = np.zeros((64 + big, 64 + big, 4), np.uint8)
        ox = int(round(TORSO_X[facing] - NX * SCALE)) + big // 2
        oy = int(round(NECK_Y - NY * SCALE)) + big // 2
        cell[oy:oy + big, ox:ox + big] = small
        cell = cell[big // 2:big // 2 + 64, big // 2:big // 2 + 64]
        sheet[:, j * 64:(j + 1) * 64] = outline(cell)
    Image.fromarray(sheet, "RGBA").save(os.path.join(out, f"{suit}_worn.png"))
    print(suit, [Image.fromarray(sheet[:, j * 64:(j + 1) * 64]).getchannel("A").getbbox() for j in range(4)])

# Per-frame body offsets: match each walk frame's hood and shoulders (rows 14-37, which move
# rigidly with the torso; the arms below them swing) against the idle pose of the same facing.
walk = np.array(Image.open(walk_path).convert("RGBA")).astype(float)
idle = np.array(Image.open(idle_path).convert("RGBA")).astype(float)
offsets = []
for r in range(4):
    ref = idle[r * 64 + 14:r * 64 + 38, 8:56]
    row = []
    for c in range(walk.shape[1] // 64):
        best, err = (0, 0), 1e18
        for dy in (-1, 0, 1):
            for dx in range(-3, 4):
                cand = walk[r * 64 + 14 + dy:r * 64 + 38 + dy, c * 64 + 8 + dx:c * 64 + 56 + dx]
                e = ((cand - ref) ** 2).sum()
                if e < err:
                    best, err = (dx, dy), e
        row.append(best)
    offsets.append(row)

print("\n# ---- paste into game.gd ----")
print("const WORN_WALK_OFFSETS := [")
for row in offsets:
    print("\t[" + ", ".join(f"Vector2({dx},{dy})" for dx, dy in row) + "],")
print("]")
sash = []
for facing in FACINGS:
    info = pts["hares-stride"][facing]
    x, y = to_sprite(*info["sash_anchor"], facing)
    sash.append((round(x - 32, 1), round(y - 60, 1), info["sash_front"]))
print("const SASH_ANCHORS := [" + ", ".join(f"Vector2({x},{y})" for x, y, _ in sash) + "]")
print("const SASH_IN_FRONT := [" + ", ".join("true" if f else "false" for *_, f in sash) + "]")
print("const SPARK_PATHS := [")
for facing in FACINGS:
    info = pts["storm-vessel"][facing]
    path = [to_sprite(u, v, facing) for u, v in info["spark_path"]]
    print("\t[" + ", ".join(f"Vector2({x - 32:.1f},{y - 60:.1f})" for x, y in path) + "], # " + info["spark_channel"])
print("]")
