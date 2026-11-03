"""Composite the worn sheets over the explorer frames exactly as game.gd draws them.

Usage: python preview_worn.py <worn_dir> <explorer_dir> <out.png> [offsets.json]
Order per cell: explorer frame, suit cell (+ per-frame torso offset), then the explorer's
head rows redrawn on top so the hood sits over the neck opening.
"""
import sys, os, json
from PIL import Image

worn, exp, out = sys.argv[1:4]
SUITS = ["hares-stride", "storm-vessel", "bulls-stance"]
HEAD_ROWS = [37, 37, 37, 34]  # must match game.gd WORN_HEAD_ROWS
offsets = json.load(open(sys.argv[4])) if len(sys.argv) > 4 else None
walk = Image.open(os.path.join(exp, "explorer_a_walk.png")).convert("RGBA")
idle = Image.open(os.path.join(exp, "explorer_a_idle.png")).convert("RGBA")
Z = 4
sheet = Image.new("RGBA", (7 * 64 * Z, 3 * 4 * 64 * Z // 2 + 3 * 8), (28, 30, 38, 255))
rows = []
for s, suit in enumerate(SUITS):
    w = Image.open(os.path.join(worn, f"{suit}_worn.png"))
    for f in range(4):
        for c in range(7):
            src = idle if c == 0 else walk
            col = 0 if c == 0 else c - 1
            frame = src.crop((col * 64, f * 64, col * 64 + 64, f * 64 + 64))
            cell = Image.new("RGBA", (64, 64), (52, 58, 70, 255))
            cell.alpha_composite(frame)
            dx, dy = (0, 0) if (c == 0 or offsets is None) else offsets[f][col]
            cell.alpha_composite(w.crop((f * 64, 0, f * 64 + 64, 64)), (dx, dy))
            cell.alpha_composite(frame.crop((0, 0, 64, HEAD_ROWS[f])))
            rows.append((s, f, c, cell))
H = 64 * Z
out_img = Image.new("RGBA", (7 * H, 12 * H), (28, 30, 38, 255))
for s, f, c, cell in rows:
    out_img.alpha_composite(cell.resize((H, H), Image.NEAREST), (c * H, (s * 4 + f) * H))
out_img.save(out)
