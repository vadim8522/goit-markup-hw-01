"""Turret level 1: hex base, half-sphere dome, single barrel, neon accents.
Run: python make_turret.py  (needs the bpy pip package)
Outputs turret_lvl1.fbx / .glb and preview renders next to this script.
Neon parts are separate objects named Neon_* so they can become Neon-material MeshParts in Roblox.
"""
import bpy, bmesh, math, os

OUT = os.path.dirname(os.path.abspath(__file__))
NEON = (0.0, 0.9, 1.0)

bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name, color, emit=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = 0.55
    b.inputs["Metallic"].default_value = 0.0 if emit else 0.4
    if emit:
        b.inputs["Emission Color"].default_value = (*color, 1)
        b.inputs["Emission Strength"].default_value = emit
    m.diffuse_color = (*color, 1)
    return m


STEEL = mat("Steel", (0.16, 0.18, 0.22))
DARK = mat("DarkMetal", (0.07, 0.08, 0.10))
NEONM = mat("Neon", NEON, emit=2.5)


def finish(obj, m, name):
    obj.name = name
    obj.data.materials.append(m)
    for p in obj.data.polygons:
        p.use_smooth = False
    return obj


def cyl(name, r, h, z, m, verts=8, rot=(0, 0, 0), loc=(0, 0, None)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h,
                                        location=(loc[0], loc[1], z if loc[2] is None else loc[2]),
                                        rotation=rot)
    return finish(bpy.context.object, m, name)


def box(name, size, loc, m):
    bpy.ops.mesh.primitive_cube_add(location=loc)
    o = bpy.context.object
    o.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    bpy.ops.object.transform_apply(scale=True)
    return finish(o, m, name)


# base: hex plinth + dark skirt + neon ring
cyl("Base", 1.5, 0.35, 0.175, STEEL, verts=6)
cyl("BaseSkirt", 1.7, 0.12, 0.06, DARK, verts=6)
cyl("Neon_BaseRing", 1.2, 0.06, 0.38, NEONM, verts=12)
cyl("Pivot", 0.95, 0.2, 0.46, DARK, verts=12)

# dome: UV sphere cut in half (tank-style half-round turret), slightly flattened
bm = bmesh.new()
bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=7, radius=1.0)
res = bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:],
                             plane_co=(0, 0, 0), plane_no=(0, 0, 1), clear_inner=True)
cut = [e for e in res["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
bmesh.ops.edgeloop_fill(bm, edges=cut)
mesh = bpy.data.meshes.new("Dome")
bm.to_mesh(mesh)
bm.free()
dome = bpy.data.objects.new("Dome", mesh)
bpy.context.collection.objects.link(dome)
dome.location = (0, 0, 0.56)
dome.scale = (1.15, 1.0, 0.7)
bpy.context.view_layer.objects.active = dome
dome.select_set(True)
bpy.ops.object.transform_apply(scale=True)
finish(dome, STEEL, "Dome")

# barrel (points along +Y): shroud, tube, muzzle brake, neon rings
box("BarrelMount", (0.7, 0.5, 0.45), (0, 0.95, 0.72), DARK)
cyl("Barrel", 0.16, 1.9, 0, STEEL, verts=8, rot=(math.radians(90), 0, 0), loc=(0, 1.9, 0.72))
cyl("Muzzle", 0.24, 0.3, 0, DARK, verts=8, rot=(math.radians(90), 0, 0), loc=(0, 2.75, 0.72))
cyl("Neon_BarrelRing", 0.2, 0.08, 0, NEONM, verts=8, rot=(math.radians(90), 0, 0), loc=(0, 1.6, 0.72))
cyl("Neon_MuzzleTip", 0.1, 0.05, 0, NEONM, verts=8, rot=(math.radians(90), 0, 0), loc=(0, 2.92, 0.72))

# neon visor slits and side strips on the dome
box("Neon_Visor", (0.7, 0.1, 0.1), (0, 0.6, 1.1), NEONM)
box("Neon_StripL", (0.08, 0.7, 0.07), (-1.1, 0.0, 0.78), NEONM)
box("Neon_StripR", (0.08, 0.7, 0.07), (1.1, 0.0, 0.78), NEONM)
cyl("Neon_TopLight", 0.12, 0.08, 0, NEONM, verts=8, loc=(0, -0.2, 1.27))

parts = [o for o in bpy.context.scene.objects if o.type == "MESH"]

# scene for preview
s = bpy.context.scene
s.render.engine = "BLENDER_EEVEE"
s.view_settings.view_transform = "Standard"
s.render.resolution_x, s.render.resolution_y = 700, 500
w = bpy.data.worlds.new("w")
s.world = w
w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.03, 0.04, 0.07, 1)
w.node_tree.nodes["Background"].inputs[1].default_value = 1.0
bpy.ops.mesh.primitive_plane_add(size=14, location=(0, 0, 0))
floor = bpy.context.object
floor.name = "PreviewFloor"
floor.data.materials.append(mat("Floor", (0.05, 0.06, 0.08)))
for loc, e in (((4, -3, 6), 3.0), ((-5, 2, 4), 1.2)):
    bpy.ops.object.light_add(type="SUN", location=loc)
    bpy.context.object.data.energy = e
    bpy.context.object.rotation_euler = (math.radians(50), 0, math.radians(35))


def shot(name, loc, rot):
    bpy.ops.object.camera_add(location=loc, rotation=rot)
    s.camera = bpy.context.object
    s.render.filepath = os.path.join(OUT, name)
    bpy.ops.render.render(write_still=True)


shot("preview_front.png", (6.5, 8.5, 5.0), (math.radians(64), 0, math.radians(142)))
shot("preview_side.png", (9.5, 1.0, 3.2), (math.radians(78), 0, math.radians(97)))

# export only turret parts (not preview floor)
floor.select_set(False)
bpy.ops.object.select_all(action="DESELECT")
for o in parts:
    o.select_set(True)
bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, "turret_lvl1.fbx"), use_selection=True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "turret_lvl1.glb"), use_selection=True)
tris = sum(len(o.data.polygons) for o in parts)
print("parts", len(parts), "faces", tris)
