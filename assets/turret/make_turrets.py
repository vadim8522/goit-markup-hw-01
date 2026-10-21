"""Turrets levels 1-8: hex base, half-sphere dome, neon accents, growing barrel count/detail.
Run: python make_turrets.py -- [classic|winter] [levels...]   (needs the bpy and pillow pip packages)
Outputs lvlN/turret_lvlN.fbx|glb + previews and lineup.png next to this script.
Neon parts are separate objects named Neon_* (become Neon-material MeshParts in Roblox).
Barrels point along +Y.
"""
import bpy, bmesh, math, os, sys

ROOT = os.path.dirname(os.path.abspath(__file__))
OUT = ROOT
R = math.radians
THEME = "classic"
PALETTES = {
    "classic": dict(neon=(0.0, 0.9, 1.0), steel=(0.16, 0.18, 0.22), dark=(0.07, 0.08, 0.10), trim=(0.30, 0.33, 0.38)),
    # winter: frosted blue-grey metal, icy neon, plus white snow and pale ice props
    "winter": dict(neon=(0.1, 0.65, 1.0), steel=(0.38, 0.46, 0.58), dark=(0.14, 0.19, 0.28), trim=(0.62, 0.70, 0.80)),
}
# size multiplier per level
SCALE = {1: 1.0, 2: 1.0, 3: 1.05, 4: 1.25, 5: 1.3, 6: 1.4, 7: 1.5, 8: 1.6}


def mat(name, color, emit=0.0, rough=0.55, metal=0.4):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = 0.0 if emit else metal
    if emit:
        b.inputs["Emission Color"].default_value = (*color, 1)
        b.inputs["Emission Strength"].default_value = emit
    m.diffuse_color = (*color, 1)
    return m


class Builder:
    def __init__(self):
        self.parts = []
        pal = PALETTES[THEME]
        self.steel = mat("Steel", pal["steel"])
        self.dark = mat("DarkMetal", pal["dark"])
        self.trim = mat("Trim", pal["trim"])
        self.neon = mat("Neon", pal["neon"], emit=2.5)
        self.snow = mat("Snow", (0.95, 0.97, 1.0), rough=0.9, metal=0.0)
        self.ice = mat("Ice", (0.65, 0.86, 1.0), rough=0.2, metal=0.1)
        self.n = 0

    def _fin(self, obj, m, name):
        self.n += 1
        obj.name = f"{name}_{self.n:02d}" if not name.startswith("Neon_") else f"{name}_{self.n:02d}"
        obj.data.materials.append(m)
        for p in obj.data.polygons:
            p.use_smooth = False
        self.parts.append(obj)
        return obj

    def cyl(self, name, r, h, loc, m, verts=8, rot=(0, 0, 0)):
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=loc, rotation=rot)
        return self._fin(bpy.context.object, m, name)

    def cone(self, name, r1, r2, h, loc, m, verts=8, rot=(0, 0, 0)):
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=h, location=loc, rotation=rot)
        return self._fin(bpy.context.object, m, name)

    def box(self, name, size, loc, m, rot=(0, 0, 0)):
        bpy.ops.mesh.primitive_cube_add(location=loc, rotation=rot)
        o = bpy.context.object
        o.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
        bpy.ops.object.transform_apply(scale=True)
        return self._fin(o, m, name)

    def dome(self, m):
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=7, radius=1.0)
        res = bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:],
                                     plane_co=(0, 0, 0), plane_no=(0, 0, 1), clear_inner=True)
        cut = [e for e in res["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
        bmesh.ops.edgeloop_fill(bm, edges=cut)
        mesh = bpy.data.meshes.new("Dome")
        bm.to_mesh(mesh)
        bm.free()
        d = bpy.data.objects.new("Dome", mesh)
        bpy.context.collection.objects.link(d)
        d.location = (0, 0, 0.56)
        d.scale = (1.15, 1.0, 0.7)
        bpy.context.view_layer.objects.active = d
        d.select_set(True)
        bpy.ops.object.transform_apply(scale=True)
        return self._fin(d, m, "Dome")

    def ico(self, name, r, loc, m, scale=(1, 1, 1)):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=r, location=loc)
        o = bpy.context.object
        o.scale = scale
        bpy.ops.object.transform_apply(scale=True)
        return self._fin(o, m, name)

    # ---- barrel along +Y ----
    def barrel(self, x, z, length, level, r=0.16, y0=0.95, mount=True):
        d, st, nm = self.dark, self.steel, self.neon
        Y = R(90)
        if mount:
            self.box("BarrelMount", (r * 4.4 if level > 1 else 0.7, 0.5, 0.45), (x, y0, z), d)
            if THEME == "winter":
                self.box("SnowCap", (r * 4.4 if level > 1 else 0.7, 0.55, 0.08), (x, y0, z + 0.24), self.snow)
        if level == 1:
            self.cyl("Barrel", r, length, (x, y0 + length / 2, z), st, rot=(Y, 0, 0))
            self.cyl("Muzzle", r * 1.5, 0.3, (x, y0 + length - 0.1, z), d, rot=(Y, 0, 0))
            self.cyl("Neon_BarrelRing", r * 1.25, 0.08, (x, y0 + 0.65, z), nm, rot=(Y, 0, 0))
            self.cyl("Neon_MuzzleTip", r * 0.65, 0.05, (x, y0 + length + 0.07, z), nm, rot=(Y, 0, 0))
            return
        # level 2+: sleeve, tapered tube, cooling fins, vented muzzle brake
        sleeve = 0.45
        self.cyl("BarrelSleeve", r * 1.55, sleeve, (x, y0 + sleeve / 2 + 0.1, z), d, verts=8, rot=(Y, 0, 0))
        tube_len = length - sleeve - 0.45
        self.cone("BarrelTube", r * 0.95, r * 1.3, tube_len, (x, y0 + sleeve + 0.1 + tube_len / 2, z), st, rot=(Y, 0, 0))
        for k in range(3):
            fy = y0 + sleeve + 0.25 + k * (tube_len / 3.2)
            self.cyl("BarrelFin", r * 1.6, 0.07, (x, fy, z), d, rot=(Y, 0, 0))
        self.cyl("Neon_BarrelRing", r * 1.2, 0.06, (x, y0 + sleeve + 0.1 + tube_len * 0.55, z), nm, rot=(Y, 0, 0))
        my = y0 + length - 0.2
        self.cyl("MuzzleBrake", r * 1.75, 0.42, (x, my, z), d, verts=6, rot=(Y, 0, 0))
        for s in (-1, 1):
            self.box("Neon_Vent", (0.04, 0.22, r * 0.6), (x + s * r * 1.55, my, z), nm)
        self.cyl("Neon_MuzzleTip", r * 0.7, 0.05, (x, my + 0.23, z), nm, verts=8, rot=(Y, 0, 0))
        if THEME == "winter":
            for dx, dy, h in ((-0.5, -0.1, 0.28), (0.45, 0.1, 0.2)):
                self.cone("Icicle", r * 0.45, 0.0, h, (x + dx * r * 2, my + dy, z - r * 1.75 - h / 2), self.ice, verts=5, rot=(R(180), 0, 0))


def build(level):
    b = Builder()
    st, dk, nm, tr = b.steel, b.dark, b.neon, b.trim
    Y = R(90)

    # --- base ---
    b.cyl("Base", 1.5, 0.35, (0, 0, 0.175), st, verts=6)
    b.cyl("BaseSkirt", 1.7, 0.12, (0, 0, 0.06), dk, verts=6)
    b.cyl("Neon_BaseRing", 1.2, 0.06, (0, 0, 0.38), nm, verts=12)
    b.cyl("Pivot", 0.95, 0.2, (0, 0, 0.46), dk, verts=12)
    b.dome(st)
    b.cyl("Neon_TopLight", 0.12, 0.08, (0, -0.2, 1.27), nm)

    # --- barrels per level ---
    if level == 1:
        b.barrel(0, 0.72, 1.9, 1)
    elif level == 2:
        b.barrel(0, 0.72, 2.2, 2)
    elif level in (3, 4):
        for x in (-0.38, 0.38):
            b.barrel(x, 0.72, 2.0 if level == 3 else 2.2, level, r=0.14)
    elif level in (5, 6):
        for x in (-0.55, 0.55):
            b.barrel(x, 0.66, 1.9 if level == 5 else 2.1, level, r=0.13)
        b.barrel(0, 0.82, 2.3 if level == 5 else 2.6, level, r=0.17)
    else:  # 7, 8: flank pods, two barrels each side, centre stays open
        for s in (-1, 1):
            b.box("PodBody", (0.62, 0.9, 0.95), (s * 1.25, 0.35, 0.78), st)
            b.box("PodPlate", (0.68, 0.12, 1.0), (s * 1.25, 0.84, 0.78), dk)
            b.box("Neon_PodStrip", (0.04, 0.5, 0.06), (s * 1.57, 0.3, 0.78), nm)
            for z in (0.56, 1.0):
                b.barrel(s * 1.25, z, 2.0 if level == 7 else 2.3, level, r=0.13, y0=0.9, mount=False)
        b.cone("CentreSensor", 0.28, 0.45, 0.45, (0, 0.3, 1.4), dk, verts=8)
        b.cyl("Neon_SensorEye", 0.14, 0.06, (0, 0.52, 1.45), nm, verts=8, rot=(R(80), 0, 0))

    # visor / side strips (single-barrel and twin looks keep the original identity)
    if level < 7:
        b.box("Neon_Visor", (0.7, 0.1, 0.1), (0, 0.6, 1.1), nm)
    for s in (-1, 1):
        if level < 7:
            b.box("Neon_Strip", (0.08, 0.7, 0.07), (s * 1.1, 0.0, 0.78), nm)

    # --- details by level ---
    if level >= 2:
        b.box("BackVent", (0.8, 0.3, 0.25), (0, -0.88, 0.85), dk)
        for z in (0.8, 0.9):
            b.box("Neon_VentSlit", (0.5, 0.04, 0.04), (0, -1.04, z), nm)
        for s in (-1, 1):
            b.box("ArmorPlate", (0.12, 0.7, 0.35), (s * 1.0, 0.1, 1.0), tr, rot=(0, s * R(25), 0))
        b.cyl("Antenna", 0.03, 0.8, (-0.7, -0.5, 1.5), dk, verts=6)
        b.cyl("Neon_AntennaTip", 0.06, 0.06, (-0.7, -0.5, 1.93), nm, verts=6)
        for k in range(6):
            a = R(k * 60)
            b.cyl("BasePylon", 0.12, 0.3, (1.38 * math.cos(a), 1.38 * math.sin(a), 0.45), dk, verts=6)
    if level >= 3:
        for s in (-1, 1):
            b.box("SaddleBag", (0.3, 0.6, 0.35), (s * 1.25, -0.45, 0.6), dk)
            b.box("Neon_BagLight", (0.32, 0.04, 0.05), (s * 1.25, -0.77, 0.6), nm)
        b.cyl("Cupola", 0.45, 0.15, (0, -0.2, 1.3), dk, verts=8)
    if level >= 4:
        b.cyl("BaseTier", 2.0, 0.12, (0, 0, 0.03), tr, verts=6)
        for k in range(6):
            a = R(k * 60)
            b.cyl("Neon_CornerLight", 0.1, 0.05, (1.88 * math.cos(a), 1.88 * math.sin(a), 0.1), nm, verts=6)
    if level >= 5:
        b.cyl("RadarMast", 0.05, 0.6, (0.55, -0.55, 1.5), dk, verts=6)
        b.cyl("RadarDish", 0.32, 0.07, (0.55, -0.55, 1.85), tr, verts=12, rot=(R(-35), 0, 0))
        b.cyl("Neon_RadarCore", 0.07, 0.05, (0.55, -0.62, 1.9), nm, verts=6, rot=(R(-35), 0, 0))
    if level >= 6:
        for k in range(8):
            if k == 2:
                continue
            a = R(k * 45)
            b.box("SkirtPlate", (0.5, 0.18, 0.3), (1.32 * math.cos(a), 1.12 * math.sin(a), 0.62), tr, rot=(0, 0, a + R(90)))
    if level >= 6:
        b.box("MissileRack", (0.9, 0.5, 0.3), (0, -0.7, 1.45), dk)
        for x in (-0.3, -0.1, 0.1, 0.3):
            b.cyl("Neon_MissileTip", 0.05, 0.05, (x, -0.43, 1.45), nm, verts=6, rot=(R(90), 0, 0))
    if level >= 8:
        for k in range(6):
            a = R(k * 60 + 30)
            b.cone("CrownSpike", 0.0, 0.1, 0.4, (0.55 * math.cos(a), 0.55 * math.sin(a) - 0.2, 1.45), tr, verts=4)
        b.ico("Neon_CoreCrystal", 0.22, (0, -0.2, 2.35), nm, scale=(1, 1, 1.6))
        b.cyl("Neon_CoreRing", 0.5, 0.04, (0, -0.2, 2.0), nm, verts=12)
        b.cyl("Neon_BaseRing2", 1.62, 0.04, (0, 0, 0.12), nm, verts=12)
    if THEME == "winter":
        winter_details(b, level)
    return b.parts


def winter_details(b, level):
    sn, ice = b.snow, b.ice
    # snow blanket on the back of the dome, mounds on the base between the pylons
    b.ico("SnowBlanket", 0.62, (0, -0.62, 1.05), sn, scale=(1.15, 1.0, 0.45))
    for k in range(6):
        a = R(k * 60 + 30)
        b.ico("SnowMound", 0.28, (1.3 * math.cos(a), 1.3 * math.sin(a), 0.4), sn, scale=(1.2, 1.2, 0.5))
    # ice crystals around the base rim
    for k in range(6):
        a = R(k * 60 + 30)
        b.cone("IceSpike", 0.14, 0.0, 0.55 + 0.1 * (k % 2), (1.72 * math.cos(a), 1.72 * math.sin(a), 0.3), ice, verts=5)
    if level >= 3:
        b.ico("SnowCupola", 0.4, (0, -0.2, 1.4), sn, scale=(1.0, 1.0, 0.4))
        for s_ in (-1, 1):
            b.box("SnowBag", (0.34, 0.64, 0.07), (s_ * 1.25, -0.45, 0.8), sn)
    if level >= 5:
        b.cyl("SnowDish", 0.3, 0.05, (0.55, -0.55, 1.89), sn, verts=12, rot=(R(-35), 0, 0))
    if level >= 7:
        for s_ in (-1, 1):
            b.box("SnowPod", (0.68, 0.96, 0.08), (s_ * 1.25, 0.35, 1.29), sn)
    if level >= 8:
        for k in range(4):
            a = R(k * 90 + 45)
            b.cone("IceCrown", 0.1, 0.0, 0.35, (0.8 * math.cos(a), 0.8 * math.sin(a) - 0.2, 1.3), ice, verts=5, rot=(0, 0, 0))


def scale_parts(parts, s):
    if s == 1:
        return
    for o in parts:
        o.location = o.location * s
        o.scale = (s, s, s)
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.transform_apply(scale=True)


def render_and_export(level, parts, outdir):
    s = bpy.context.scene
    s.render.engine = "BLENDER_EEVEE"
    s.view_settings.view_transform = "Standard"
    s.render.resolution_x, s.render.resolution_y = 700, 500
    w = bpy.data.worlds.new("w")
    s.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.03, 0.04, 0.07, 1)
    bpy.ops.mesh.primitive_plane_add(size=30, location=(0, 0, 0))
    floor = bpy.context.object
    floor.name = "PreviewFloor"
    floor.data.materials.append(mat("Floor", (0.05, 0.06, 0.08)))
    for loc, e in (((4, -3, 6), 3.0), ((-5, 2, 4), 1.2)):
        bpy.ops.object.light_add(type="SUN", location=loc)
        bpy.context.object.data.energy = e
        bpy.context.object.rotation_euler = (R(50), 0, R(35))
    k = SCALE[level] ** 0.8 * (1.2 if level >= 7 else 1.0)
    for name, loc, rot in (("preview_front.png", (6.5, 8.5, 5.0), (R(64), 0, R(142))),
                           ("preview_side.png", (9.5, 1.0, 3.2), (R(78), 0, R(97)))):
        bpy.ops.object.camera_add(location=tuple(c * k for c in loc), rotation=rot)
        s.camera = bpy.context.object
        s.render.filepath = os.path.join(outdir, name)
        bpy.ops.render.render(write_still=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts:
        o.select_set(True)
    base = os.path.join(outdir, f"turret_lvl{level}")
    bpy.ops.export_scene.fbx(filepath=base + ".fbx", use_selection=True)
    bpy.ops.export_scene.gltf(filepath=base + ".glb", use_selection=True)


def montage(levels):
    from PIL import Image, ImageDraw
    ims = [Image.open(os.path.join(OUT, f"lvl{l}", "preview_front.png")).convert("RGB") for l in levels]
    w, h = ims[0].size
    cols = 4
    rows = (len(ims) + cols - 1) // cols
    sheet = Image.new("RGB", (w * cols, h * rows))
    d = ImageDraw.Draw(sheet)
    for i, (l, im) in enumerate(zip(levels, ims)):
        x, y = (i % cols) * w, (i // cols) * h
        sheet.paste(im, (x, y))
        d.text((x + 12, y + 10), f"LVL {l}", fill=(255, 255, 255))
    sheet.save(os.path.join(OUT, "lineup.png"))


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    THEME = next((a for a in args if a in PALETTES), "classic")
    OUT = ROOT if THEME == "classic" else os.path.join(ROOT, THEME)
    levels = [int(a) for a in args if a.isdigit()] or list(range(1, 9))
    for lv in levels:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        parts = build(lv)
        scale_parts(parts, SCALE[lv])
        outdir = os.path.join(OUT, f"lvl{lv}")
        os.makedirs(outdir, exist_ok=True)
        render_and_export(lv, parts, outdir)
        print("LEVEL", lv, "parts", len(parts), "faces", sum(len(o.data.polygons) for o in parts))
    if len(levels) == 8:
        montage(levels)
