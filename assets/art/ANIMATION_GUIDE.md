# Runtime animation and atlas contract

Explorer cells are exactly 64×64. Rows are **Down, Left, Right, Up**. The foot anchor is **(32,60)**, drawn at the gameplay position. Each explorer uses one source scale across every pose; crops are measured individually in `sprite_crop_manifest.json`.

| State | Runtime behaviour |
| --- | --- |
| Idle | Stable directional pose; no unrelated poses cycled |
| Walk | Six-frame ping-pong sequence from four complete poses; advances one frame per 28 pixels actually travelled |
| Attack | Directional body plus a bow animated around a fixed hand pivot; aim cannot accidentally replace the direction with a sideways source pose |
| Hurt | 0.2-second damage tint; preserves current direction and foot placement |
| Death | Immediate gameplay respawn; the unused legacy death sheet is not played |

The solo explorer has a distance accumulator; colliding with a wall stops the cycle. The second explorer's source artwork remains available but is unused. There is no switching or follower animation in the solo campaign.

Creature/companion strips use measured band crops. Spirit/owl cells are 64×64; Minotaur/Athena cells are 128×128. Spirits now use the first complete pose with a gentle hover offset, avoiding changes of viewing direction. Their attack rings come from AI state. Athena's reveal advances once through twelve frames.

The original generated concept masters remain in `work/generated/`. Rebuild current runtime atlases with `python work/polish_assets.py`; the old importer entry point delegates to it. Do not assume any source sheet has equal-sized cells.

`connected_walls.png` has sixteen 64px cells indexed by neighbour bits **N=1, E=2, S=4, W=8**. `polished_floor.png` has four seamless 64px variants plus hoofprint and claw-mark story tiles. TileMap collision polygons and light occluders occupy the same 64px cells as the wall art.
