"""Build the level boss and export it as glTF.

The blind critic flagged the boss twice: "the same primitive as a foot soldier, only bigger…
no weapon, no armour, no scale silhouette". A boss has to be recognisable as a different KIND
of thing at thumbnail size, so this one gets a crested helmet, heavy pauldrons, a wide stance
and a club — a silhouette you can read with the colours removed.

    ~/tools3d/.venv/bin/python tools/make_boss.py
"""
import math
import os
import sys

import bpy
from mathutils import Matrix


def box(name, size, loc, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = (size[0], size[1], size[2])
    o.rotation_euler = tuple(math.radians(r) for r in rot)
    return o


def build():
    p = []
    p.append(box("legL", (0.26, 0.26, 0.72), (-0.26, 0.0, 0.36)))
    p.append(box("legR", (0.26, 0.26, 0.72), (0.26, 0.0, 0.36)))
    p.append(box("footL", (0.32, 0.42, 0.16), (-0.26, 0.06, 0.08)))
    p.append(box("footR", (0.32, 0.42, 0.16), (0.26, 0.06, 0.08)))
    p.append(box("torso", (0.78, 0.44, 0.68), (0, 0, 1.06)))
    p.append(box("belt", (0.84, 0.48, 0.14), (0, 0, 0.74)))
    # pauldrons — the widest point, which is what makes the silhouette read as heavy
    p.append(box("shoulderL", (0.34, 0.46, 0.30), (-0.52, 0, 1.30), rot=(0, 18, 0)))
    p.append(box("shoulderR", (0.34, 0.46, 0.30), (0.52, 0, 1.30), rot=(0, -18, 0)))
    p.append(box("armL", (0.20, 0.20, 0.56), (-0.54, 0.06, 0.92), rot=(12, 0, 0)))
    p.append(box("armR", (0.20, 0.20, 0.56), (0.54, -0.06, 0.92), rot=(-12, 0, 0)))
    p.append(box("helmet", (0.46, 0.40, 0.30), (0, 0, 1.62)))
    p.append(box("helmet_top", (0.34, 0.32, 0.12), (0, 0, 1.82)))
    # helmet crest — one shape does more for recognition at 60 px than any amount of detail
    p.append(box("crest", (0.10, 0.34, 0.20), (0, -0.02, 1.74)))
    p.append(box("visor", (0.34, 0.09, 0.09), (0, -0.17, 1.61)))
    # club, held out to one side so it breaks the outline
    p.append(box("haft", (0.17, 0.17, 0.80), (0.62, 0.06, 1.06), rot=(0, -14, 0)))
    p.append(box("head_club", (0.32, 0.32, 0.36), (0.74, 0.06, 1.48)))

    for o in p:
        o.select_set(True)
    bpy.context.view_layer.objects.active = p[0]
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = "Boss"
    return obj


def paint(obj):
    me = obj.data
    col = me.color_attributes.new(name="Col", type="BYTE_COLOR", domain="CORNER")
    me.color_attributes.active_color = col
    me.attributes.active_color_index = me.color_attributes.find(col.name)
    zs = [v.co.z for v in me.vertices]
    lo, hi = min(zs), max(zs)
    span = max(hi - lo, 1e-6)
    for poly in me.polygons:
        for li in poly.loop_indices:
            t = (me.vertices[me.loops[li].vertex_index].co.z - lo) / span
            c = 0.52 if t < 0.34 else (0.74 if t < 0.52 else (0.95 if t < 0.84 else 1.15))
            col.data[li].color = (c, c, c, 1.0)


def main() -> int:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    obj = build()
    paint(obj)
    mat = bpy.data.materials.new("BossMat")
    mat.use_nodes = True
    mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (1, 1, 1, 1)
    obj.data.materials.append(mat)

    me = obj.data
    obj.location = (0, 0, 0)
    obj.scale = (1, 1, 1)
    obj.rotation_euler = (0, 0, 0)
    zs = [v.co.z for v in me.vertices]
    lo, hi = min(zs), max(zs)
    me.transform(Matrix.Translation((0.0, 0.0, -lo)))
    k = 1.0 / max(hi - lo, 1e-6)
    me.transform(Matrix.Diagonal((k, k, k, 1.0)))
    zs2 = [v.co.z for v in me.vertices]
    assert abs(min(zs2)) < 1e-5 and abs(max(zs2) - 1.0) < 1e-5, \
        "boss must span exactly 0.0..1.0 in z, got %.4f..%.4f" % (min(zs2), max(zs2))

    out = os.path.expanduser("~/gate-rush-godot/assets/boss.glb")
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_yup=True,
                              export_apply=True, export_vertex_color="ACTIVE")
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    print("wrote %s  (%d tris, %d verts)" % (out, tris, len(me.vertices)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
