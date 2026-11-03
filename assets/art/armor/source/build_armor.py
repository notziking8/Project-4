"""Build the three armor pickup suits in Blender and render them.

Run:  blender -b --factory-startup -P build_armor.py -- <out_dir>
Writes armor_suits.blend and hi-res renders (hares-stride.png etc.) into <out_dir>.
Facing -Y, Z up. Camera looks from -Y, pitched slightly down.
"""
import bpy, bmesh, math, sys, os
from mathutils import Vector

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else os.getcwd()
RES = 512
ORTHO = 3.8  # shared orthographic scale (world units across frame)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


# ---------- materials (flat, restrained palette) ----------
def mat(name, rgb, rough=0.8, metal=0.0, emit=None, emit_str=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit:
        b.inputs["Emission Color"].default_value = (*emit, 1)
        b.inputs["Emission Strength"].default_value = emit_str
    m.diffuse_color = (*rgb, 1)
    return m


def srgb(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c)


M = {
    "bronze": mat("Bronze", srgb("c99a52"), 0.55, 0.0),
    "bronze_dk": mat("BronzeDark", srgb("8a5f32"), 0.6),
    "patina": mat("Patina", srgb("2f7a72"), 0.7),
    "cyan": mat("CyanGlow", srgb("5fe6e6"), 0.3, 0, srgb("5fe6e6"), 2.0),
    "sage": mat("SageCloth", srgb("a9b58a"), 0.95),
    "sage_lt": mat("SageLight", srgb("cdd3a6"), 0.95),
    "sage_dk": mat("SageDark", srgb("727e5c"), 0.95),
    "leather": mat("Leather", srgb("7b4d2a"), 0.7),
    "oxblood": mat("Oxblood", srgb("8c3a46"), 0.9),
    "inner": mat("Lining", srgb("3a2c24"), 1.0),
    "gouge": mat("Gouge", srgb("4a3020"), 0.9),
    "brass": mat("Brass", srgb("e8c070"), 0.4),
}


# ---------- geometry helpers ----------
def new_obj(name, bm, material, coll, solid=0.0, solid_inner=None):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = False
    o = bpy.data.objects.new(name, me)
    coll.objects.link(o)
    o.data.materials.append(material)
    if solid_inner is not None:
        o.data.materials.append(solid_inner)
    if solid:
        s = o.modifiers.new("Thickness", "SOLIDIFY")
        s.thickness = solid
        s.offset = 1
        if solid_inner is not None:
            s.material_offset = 1
    return o


def loft(rings, closed_top=False):
    """rings: list of lists of (x,y,z). Open tube (no caps) unless closed_top."""
    bm = bmesh.new()
    vr = [[bm.verts.new(p) for p in r] for r in rings]
    n = len(rings[0])
    for a, b in zip(vr[:-1], vr[1:]):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((a[i], a[j], b[j], b[i]))
    if closed_top:
        bm.faces.new(vr[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def ring(z, hw, hd, x0=0.0, y0=0.0, n=10, sq=0.0):
    pts = []
    for i in range(n):
        a = 2 * math.pi * i / n + math.pi / n
        c, s = math.cos(a), math.sin(a)
        if sq:
            c = math.copysign(abs(c) ** (1 - sq), c)
            s = math.copysign(abs(s) ** (1 - sq), s)
        pts.append((x0 + hw * c, y0 + hd * s, z))
    return pts


def box(name, size, loc, rot, material, coll, taper=None):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= size[0]
        v.co.y *= size[1]
        v.co.z *= size[2]
        if taper:  # taper top (z>0) x/y
            if v.co.z > 0:
                v.co.x *= taper[0]
                v.co.y *= taper[1]
    o = new_obj(name, bm, material, coll)
    o.location = loc
    o.rotation_euler = [math.radians(r) for r in rot]
    return o


def prism(name, pts2d, depth, loc, rot, material, coll):
    """Extruded polygon in the XZ plane, thickness along Y."""
    bm = bmesh.new()
    f = [bm.verts.new((x, -depth / 2, z)) for x, z in pts2d]
    b = [bm.verts.new((x, depth / 2, z)) for x, z in pts2d]
    n = len(pts2d)
    bm.faces.new(f[::-1])
    bm.faces.new(b)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((f[i], f[j], b[j], b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    o = new_obj(name, bm, material, coll)
    o.location = loc
    o.rotation_euler = [math.radians(r) for r in rot]
    return o


def shear_deform(o, fn):
    for v in o.data.vertices:
        v.co = Vector(fn(v.co.copy()))


def join(objs, name, coll):
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objs:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    # apply modifiers first
    for ob in objs:
        bpy.context.view_layer.objects.active = ob
        for m in list(ob.modifiers):
            bpy.ops.object.modifier_apply(modifier=m.name)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    objs[0].name = name
    return objs[0]


def collection(name):
    c = bpy.data.collections.new(name)
    scene.collection.children.link(c)
    return c


def strip(name, pts, width, target, material, coll, off=0.014, step=0.07, back=False):
    """Ribbon along an XZ polyline, shrinkwrapped onto `target` (projected along +Y, or -Y for the back)."""
    sy = 3.0 if back else -3.0
    P = [Vector((x, sy, z)) for x, z in pts]
    path = [P[0]]
    for p0, p1 in zip(P[:-1], P[1:]):
        L = (p1 - p0).length
        k = max(1, int(L / step))
        for i in range(1, k + 1):
            path.append(p0.lerp(p1, i / k))
    bm = bmesh.new()
    rows = []
    for i, p in enumerate(path):
        t = path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)]
        t = Vector((t.x, 0, t.z)).normalized()
        n = Vector((-t.z, 0, t.x))
        rows.append([bm.verts.new(p + n * w) for w in (-width / 2, 0, width / 2)])
    for r0, r1 in zip(rows[:-1], rows[1:]):
        for j in range(2):
            bm.faces.new((r0[j], r0[j + 1], r1[j + 1], r1[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    o = new_obj(name, bm, material, coll)
    sw = o.modifiers.new("Wrap", "SHRINKWRAP")
    sw.target = target
    sw.wrap_method = "PROJECT"
    sw.use_project_y = True
    sw.use_positive_direction = not back
    sw.use_negative_direction = back
    sw.offset = off
    sw.cull_face = "OFF"
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.modifier_apply(modifier="Wrap")
    # drop any vertices whose ray missed the target (they stay at y=-3 and smear into slivers)
    bm2 = bmesh.new()
    bm2.from_mesh(o.data)
    bmesh.ops.delete(bm2, geom=[v for v in bm2.verts if abs(v.co.y) > 1.5], context="VERTS")
    bm2.to_mesh(o.data)
    bm2.free()
    return o


def bez(p0, p1, p2, n=6):
    return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
             (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1])
            for t in [i / n for i in range(n + 1)]]


def stretch_z(o, k):
    for v in o.data.vertices:
        v.co.z *= k


def tilted_band(name, z0, tilt, hh, hw, hd, material, coll, n=10, thick=0.045, inner=None):
    def r(z):
        pts = ring(z, hw, hd, n=n)
        return [(x, y, zz + tilt * x) for x, y, zz in pts]
    return new_obj(name, loft([r(z0 - hh), r(z0 + hh)]), material, coll, thick, inner)


# =====================================================================
# Hare's Stride -- slim asymmetrical sage wraps
# =====================================================================
def build_hare():
    c = collection("Suit_HaresStride")
    parts = []
    core_r = [(0.08, 0.54, 0.30), (0.80, 0.56, 0.31), (1.45, 0.58, 0.32), (2.05, 0.30, 0.24)]
    core = new_obj("HS_Undershirt", loft([ring(z, w, d, n=8) for z, w, d in core_r]), M["sage_dk"], c, 0.05, M["inner"])
    # slanted neckline: viewer-left (covered) rises, viewer-right (exposed) shoulder drops
    shear_deform(core, lambda p: (p.x, p.y, p.z - (0.55 * p.x if p.z > 1.2 else 0)))
    parts.append(core)
    # overlapping diagonal wraps: tilted rings that hug the torso, high on viewer-left
    tilt = -0.62
    for i, (z0, mt, hh) in enumerate([(0.78, "sage", 0.16), (1.04, "sage_lt", 0.17),
                                      (1.30, "sage", 0.17), (1.56, "sage_lt", 0.17), (1.84, "sage", 0.15)]):
        k = 1.06 + (0.03 if i % 2 else 0)
        parts.append(tilted_band(f"HS_Wrap{i}", z0, tilt, hh, 0.58 * k, 0.32 * k, M[mt], c, inner=M["inner"]))
    # narrow leather belt + buckle
    parts.append(new_obj("HS_Belt", loft([ring(0.46, 0.64, 0.37, n=10), ring(0.58, 0.64, 0.37, n=10)]),
                         M["leather"], c, 0.03, M["inner"]))
    parts.append(box("HS_Buckle", (0.15, 0.05, 0.15), (0.04, -0.385, 0.52), (0, 0, 0), M["brass"], c))
    # short forked sash off the belt, falling to viewer-right
    parts.append(box("HS_SashA", (0.24, 0.05, 0.62), (0.36, -0.38, 0.20), (0, 10, 0), M["sage_lt"], c, taper=(0.55, 1)))
    parts.append(box("HS_SashB", (0.22, 0.05, 0.56), (0.74, -0.35, 0.10), (0, -30, 0), M["sage"], c, taper=(0.55, 1)))
    obj = join(parts, "HaresStride", c)
    stretch_z(obj, 1.02)
    return obj


# =====================================================================
# Storm Vessel -- fitted bronze cuirass, patina channels, cyan highlight
# =====================================================================
def build_storm():
    c = collection("Suit_StormVessel")
    parts = []
    prof = [(0.15, 0.58, 0.34), (0.60, 0.66, 0.36), (1.15, 0.80, 0.38), (1.62, 0.92, 0.38),
            (1.80, 0.90, 0.32), (2.02, 0.32, 0.25)]
    body = new_obj("SV_Cuirass", loft([ring(z, w, d, n=8, sq=0.3) for z, w, d in prof]),
                   M["bronze"], c, 0.07, M["inner"])
    parts.append(body)
    for s in (-1, 1):
        parts.append(box(f"SV_Pauldron{s}", (0.52, 0.46, 0.16), (s * 0.90, 0, 1.76), (0, s * 22, 0), M["bronze"], c))
    parts.append(new_obj("SV_Waistband",
                         loft([ring(0.15, 0.585, 0.345, n=8, sq=0.3), ring(0.40, 0.64, 0.365, n=8, sq=0.3)]),
                         M["bronze_dk"], c, 0.05, M["inner"]))
    parts.append(box("SV_Buckle", (0.24, 0.05, 0.20), (0, -0.375, 0.28), (0, 0, 0), M["brass"], c))
    # two curved patina channels from the shoulders sweeping down to the belt
    left = bez((-0.52, 1.74), (-0.46, 1.00), (-0.08, 0.52))
    right = bez((0.52, 1.74), (0.46, 1.00), (0.08, 0.52))
    parts.append(strip("SV_ChannelL", left, 0.17, body, M["patina"], c))
    parts.append(strip("SV_ChannelR", right, 0.17, body, M["patina"], c))
    # tight cyan highlight inside the upper right channel
    parts.append(strip("SV_CyanGlow", right[:4], 0.07, body, M["cyan"], c, off=0.03))
    # the channels continue over the shoulders onto the back plate (seen in the worn back view)
    parts.append(strip("SV_ChannelBackL", left, 0.17, body, M["patina"], c, back=True))
    parts.append(strip("SV_ChannelBackR", right, 0.17, body, M["patina"], c, back=True))
    obj = join(parts, "StormVessel", c)
    stretch_z(obj, 1.22)
    return obj


# =====================================================================
# Bull's Stance -- heavy guardian, widest silhouette
# =====================================================================
def build_bull():
    c = collection("Suit_BullsStance")
    parts = []
    prof = [(0.15, 0.80, 0.42), (0.80, 0.86, 0.44), (1.45, 0.92, 0.44), (1.72, 0.66, 0.38), (1.95, 0.36, 0.28)]
    body = new_obj("BS_Breastplate", loft([ring(z, w, d, n=8, sq=0.4) for z, w, d in prof]),
                   M["bronze"], c, 0.08, M["inner"])
    parts.append(body)
    # oxblood mantle over the collar and shoulders, hanging tail on viewer-left
    parts.append(new_obj("BS_Mantle", loft([ring(1.30, 1.10, 0.50, n=8, sq=0.35), ring(1.72, 0.88, 0.45, n=8, sq=0.3),
                                            ring(2.02, 0.48, 0.34, n=8)]), M["oxblood"], c, 0.06, M["inner"]))
    parts.append(box("BS_MantleTail", (0.36, 0.10, 0.95), (-0.86, -0.42, 0.95), (0, 5, 0), M["oxblood"], c))
    # wide squared bronze shoulder plates
    pl = {}
    for s in (-1, 1):
        pl[s] = box(f"BS_Pauldron{s}", (1.00, 0.84, 0.52), (s * 1.14, 0, 1.62), (0, s * 10, 0), M["bronze"], c)
        parts.append(pl[s])
        parts.append(box(f"BS_PauldronRim{s}", (1.06, 0.88, 0.12), (s * 1.16, 0, 1.30), (0, s * 10, 0), M["bronze_dk"], c))
    # two diagonal horn gouges cut into the viewer-right shoulder plate
    parts.append(strip("BS_Gouge0", [(0.98, 1.36), (1.18, 1.74)], 0.085, pl[1], M["gouge"], c, off=0.02, step=0.06))
    parts.append(strip("BS_Gouge1", [(1.22, 1.34), (1.42, 1.72)], 0.085, pl[1], M["gouge"], c, off=0.02, step=0.06))
    # belt plates
    parts.append(strip("BS_BandLow", [(-0.78, 0.50), (0.78, 0.50)], 0.20, body, M["bronze_dk"], c))
    parts.append(strip("BS_BandMid", [(-0.80, 0.95), (0.80, 0.95)], 0.12, body, M["brass"], c))
    obj = join(parts, "BullsStance", c)
    stretch_z(obj, 1.18)
    return obj


suits = {
    "hares-stride": build_hare(),
    "storm-vessel": build_storm(),
    "bulls-stance": build_bull(),
}

# ---------- shared camera + lighting ----------
rig = collection("Shared_CameraAndLighting")
cam_d = bpy.data.cameras.new("PickupCam")
cam_d.type = "ORTHO"
cam_d.ortho_scale = ORTHO
cam_d.clip_start, cam_d.clip_end = 0.1, 100
cam = bpy.data.objects.new("PickupCamera", cam_d)
rig.objects.link(cam)
dist = 12
target = Vector((0, 0, 1.2))
elev = math.radians(28)  # camera elevation above horizon: shows shoulder tops + neck opening
cam.location = target + Vector((0, -dist * math.cos(elev), dist * math.sin(elev)))
cam.rotation_euler = (math.radians(90) - elev, 0, 0)
scene.camera = cam

key_d = bpy.data.lights.new("KeySun", "SUN")
key_d.energy = 2.6
key_d.angle = math.radians(25)
key_d.color = (1.0, 0.95, 0.88)
key = bpy.data.objects.new("KeySun", key_d)
key.rotation_euler = (math.radians(52), math.radians(8), math.radians(-38))
rig.objects.link(key)

fill_d = bpy.data.lights.new("FillSun", "SUN")
fill_d.energy = 0.7
fill_d.angle = math.radians(60)
fill_d.color = (0.72, 0.82, 1.0)
fill = bpy.data.objects.new("FillSun", fill_d)
fill.rotation_euler = (math.radians(70), 0, math.radians(140))
rig.objects.link(fill)

world = bpy.data.worlds.new("DungeonAmbient")
world.use_nodes = True
bg = world.node_tree.nodes["Background"]
bg.inputs["Color"].default_value = (0.10, 0.09, 0.12, 1)
bg.inputs["Strength"].default_value = 0.6
scene.world = world

# ---------- render settings ----------
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = scene.render.resolution_y = RES
scene.render.film_transparent = True
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.view_settings.view_transform = "Standard"
scene.eevee.taa_render_samples = 32
scene.eevee.use_shadows = True

# arrange suits in a row in the .blend for editing, and render each at origin
SPACING = 5.0
names = list(suits)
for i, n in enumerate(names):
    suits[n].location.x = (i - 1) * SPACING

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "armor_suits.blend"))

# render each suit alone at the origin with the same camera/lights
for n in names:
    for m in names:
        suits[m].hide_render = (m != n)
    for m in names:
        suits[m].location.x = 0.0 if m == n else (names.index(m) - 1) * SPACING
    scene.render.filepath = os.path.join(OUT, f"{n}_hi.png")
    bpy.ops.render.render(write_still=True)

# restore layout and save final blend (renders visible again)
for i, n in enumerate(names):
    suits[n].location.x = (i - 1) * SPACING
    suits[n].hide_render = False
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "armor_suits.blend"))
print("DONE")
