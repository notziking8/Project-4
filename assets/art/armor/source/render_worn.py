"""Render the worn (on-explorer) views of the three suits from armor_suits.blend.

Run:  blender -b armor_suits.blend --factory-startup -P render_worn.py -- <out_dir>
For each suit and facing (down, left, right, up) this writes <suit>_<facing>.png and
worn_points.json: camera-space (0..1) positions of the sash anchor (Hare's Stride) and
of the visible patina channel (Storm Vessel), used for the in-game sash and spark.
The explorer is a chibi figure, so suits are squashed vertically (TORSO_SQUASH) to fit
its short torso, and deepened (TORSO_DEPTH) to match its round body. The Hare's Stride sash is removed here (the game animates it) and its wrap diagonal is
exaggerated (WRAP_SHEAR) so it still reads on the small worn sprite.
"""
import bpy, bmesh, math, sys, os, json
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

OUT = sys.argv[sys.argv.index("--") + 1]
os.makedirs(OUT, exist_ok=True)
scene = bpy.context.scene
RES = 512
TORSO_SQUASH = 0.55
TORSO_DEPTH = 1.6  # chibi bodies are round: deepen front-to-back so side views cover the torso
FACINGS = {"down": 0.0, "left": -90.0, "right": 90.0, "up": 180.0}

suits = {"hares-stride": bpy.data.objects["HaresStride"],
         "storm-vessel": bpy.data.objects["StormVessel"],
         "bulls-stance": bpy.data.objects["BullsStance"]}

# Strip the sash islands off a copy of Hare's Stride (sash = loose boxes below the belt, in front).
hare = suits["hares-stride"]
bm = bmesh.new()
bm.from_mesh(hare.data)
seen, sash = set(), []
for v in bm.verts:
    if v.index in seen:
        continue
    island, stack = [], [v]
    seen.add(v.index)
    while stack:
        a = stack.pop()
        island.append(a)
        for e in a.link_edges:
            b = e.other_vert(a)
            if b.index not in seen:
                seen.add(b.index)
                stack.append(b)
    c = sum((x.co for x in island), Vector()) / len(island)
    if len(island) == 8 and c.z < 0.45 and c.y < -0.3:
        sash += island
print("sash verts removed:", len(sash))
bmesh.ops.delete(bm, geom=sash, context="VERTS")
# Squashed onto the chibi torso the diagonal wrap flattens out, so for the worn view shear
# everything above the belt: the covered shoulder rises, the exposed one drops.
WRAP_SHEAR = 0.45
for v in bm.verts:
    if v.co.z > 0.62:
        v.co.z -= WRAP_SHEAR * v.co.x * min(1.0, (v.co.z - 0.62) / 0.5)
bm.to_mesh(hare.data)
bm.free()

scene.render.resolution_x = scene.render.resolution_y = RES
cam = scene.camera
view_dir = cam.matrix_world.to_quaternion() @ Vector((0, 0, -1))
SASH_ANCHOR = Vector((0.36, -0.40, 0.48 * 1.02))  # where the sash knots onto the belt


def bez(p0, p1, p2, n=10):
    return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
             (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1])
            for t in [i / n for i in range(n + 1)]]


# Storm Vessel channel centre-lines (match build_armor.py), scaled by its 1.22 z stretch.
CHANNELS = {"front_right": (bez((0.52, 1.74), (0.46, 1.00), (0.08, 0.52)), -1),
            "front_left": (bez((-0.52, 1.74), (-0.46, 1.00), (-0.08, 0.52)), -1),
            "back_right": (bez((0.52, 1.74), (0.46, 1.00), (0.08, 0.52)), 1),
            "back_left": (bez((-0.52, 1.74), (-0.46, 1.00), (-0.08, 0.52)), 1)}


def surface_point(obj, x, z, side):
    """Ray-cast onto the suit's surface along Y (local space) from the front or back."""
    o = Vector((x, side * 3.0, z))
    ok, loc, nrm, _ = obj.ray_cast(o, Vector((0, -side, 0)))
    return loc if ok else None


def visible(world_pt):
    origin = world_pt - view_dir * 30.0
    deps = bpy.context.evaluated_depsgraph_get()
    ok, loc, *_ = scene.ray_cast(deps, origin, view_dir)
    return ok and (loc - world_pt).length < 0.06


def cam_xy(world_pt):
    v = world_to_camera_view(scene, cam, world_pt)
    return [round(v.x, 5), round(1.0 - v.y, 5)]  # image space: y down


points = {}
for name, obj in suits.items():
    obj.location = (0, 0, 0)
for name, obj in suits.items():
    for m, o in suits.items():
        o.hide_render = (m != name)
        o.hide_viewport = (m != name)
    # precompute local surface points before squashing/rotating
    local_channels = {}
    if name == "storm-vessel":
        for key, (pts, side) in CHANNELS.items():
            local_channels[key] = [surface_point(obj, x, z * 1.22, side) for x, z in pts]
    for facing, rz in FACINGS.items():
        obj.rotation_euler = (0, 0, math.radians(rz))
        obj.scale = (1, TORSO_DEPTH, TORSO_SQUASH)
        bpy.context.view_layer.update()
        mw = obj.matrix_world
        info = {}
        if name == "hares-stride":
            p = mw @ SASH_ANCHOR
            info["sash_anchor"] = cam_xy(p)
            # front-facing if the anchor's outward normal (-Y local) points at the camera
            info["sash_front"] = (mw.to_3x3() @ Vector((0, -1, 0))).dot(view_dir) < 0.2
        if name == "storm-vessel":
            best, best_n = None, -1
            for key, pts in local_channels.items():
                world = [mw @ (p + (p - Vector((0, 0, p.z))).normalized() * 0.02) for p in pts if p is not None]
                n = sum(visible(w) for w in world)
                if n > best_n:
                    best, best_n = (key, [cam_xy(w) for w in world]), n
            info["spark_channel"] = best[0]
            info["spark_path"] = best[1]
            info["spark_visible_points"] = best_n
        points.setdefault(name, {})[facing] = info
        scene.render.filepath = os.path.join(OUT, f"{name}_{facing}.png")
        bpy.ops.render.render(write_still=True)
    obj.rotation_euler = (0, 0, 0)
    obj.scale = (1, 1, 1)

with open(os.path.join(OUT, "worn_points.json"), "w") as f:
    json.dump(points, f, indent=1)
print("DONE")
