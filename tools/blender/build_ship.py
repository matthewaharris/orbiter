"""Builds the player ship ("Skipper") and exports game/assets/models/ship.glb.

Tweak the PROFILE tables below to reshape the hull, then rerun:
    blender --background --factory-startup --python tools/blender/build_ship.py

Hardpoints used by Godot (Godot coordinates, ship faces -Z):
    main engine nozzle  (0, 0, 1.12)
    nacelle nozzles     (+-0.55, -0.05, 1.02)
"""
import math
import os
import sys

import bmesh
import bpy

sys.path.insert(0, os.path.dirname(__file__))
import common  # noqa: E402

RING_VERTS = 24

# (y, half-width, half-height, z-offset): nose at +Y, tail at -Y
HULL_PROFILE = [
    (1.25, 0.005, 0.005, 0.00),
    (1.10, 0.07, 0.05, 0.00),
    (0.85, 0.15, 0.11, 0.01),
    (0.45, 0.24, 0.18, 0.02),
    (0.00, 0.29, 0.21, 0.02),
    (-0.50, 0.30, 0.21, 0.00),
    (-0.85, 0.27, 0.19, 0.00),
    (-0.95, 0.22, 0.16, 0.00),
]
CANOPY_PROFILE = [
    (0.80, 0.01, 0.01, 0.14),
    (0.65, 0.09, 0.07, 0.17),
    (0.40, 0.13, 0.10, 0.20),
    (0.15, 0.12, 0.09, 0.20),
    (0.02, 0.05, 0.04, 0.18),
]
NACELLE_PROFILE = [
    (0.05, 0.01, 0.01, 0.0),
    (-0.05, 0.08, 0.08, 0.0),
    (-0.30, 0.11, 0.11, 0.0),
    (-0.85, 0.11, 0.11, 0.0),
    (-0.98, 0.09, 0.09, 0.0),
]


def loft(name, profile, offset=(0.0, 0.0, 0.0)):
    """Make a closed tube through elliptical rings (y, rx, rz, zoff)."""
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    rings = []
    for y, rx, rz, zoff in profile:
        ring = []
        for i in range(RING_VERTS):
            a = 2 * math.pi * i / RING_VERTS
            ring.append(bm.verts.new((
                offset[0] + rx * math.cos(a),
                offset[1] + y,
                offset[2] + zoff + rz * math.sin(a),
            )))
        rings.append(ring)
    for r0, r1 in zip(rings, rings[1:]):
        for i in range(RING_VERTS):
            j = (i + 1) % RING_VERTS
            bm.faces.new((r0[i], r0[j], r1[j], r1[i]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def slab(name, outline_xy, thickness, z=0.0):
    """Extrude a flat polygon (list of x,y) into a thin plate."""
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bottom = [bm.verts.new((x, y, z - thickness / 2)) for x, y in outline_xy]
    top = [bm.verts.new((x, y, z + thickness / 2)) for x, y in outline_xy]
    bm.faces.new(bottom)
    bm.faces.new(list(reversed(top)))
    n = len(outline_xy)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((bottom[i], bottom[j], top[j], top[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def cylinder(name, radius, depth, location, rotation=(math.pi / 2, 0, 0), verts=24, radius2=None):
    if radius2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth,
                                            location=location, rotation=rotation)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=radius, radius2=radius2, depth=depth,
                                        location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    return obj


def build():
    common.reset_scene()

    hull_mat = common.material("Hull", (0.82, 0.84, 0.88), metallic=0.35, roughness=0.32)
    accent_mat = common.material("Accent", (1.0, 0.38, 0.08), metallic=0.2, roughness=0.4)
    dark_mat = common.material("DarkMetal", (0.05, 0.055, 0.07), metallic=0.9, roughness=0.28)
    glass_mat = common.material("Canopy", (0.05, 0.25, 0.35), metallic=0.6, roughness=0.08,
                                emission=(0.1, 0.8, 1.0), emission_strength=1.5)
    glow_mat = common.material("EngineGlow", (0.3, 0.7, 1.0), emission=(0.35, 0.75, 1.0),
                               emission_strength=12.0)
    nav_red = common.material("NavRed", (1, 0.1, 0.05), emission=(1, 0.1, 0.05), emission_strength=10)
    nav_green = common.material("NavGreen", (0.1, 1, 0.3), emission=(0.1, 1, 0.3), emission_strength=10)

    parts = []

    hull = loft("Hull", HULL_PROFILE)
    common.assign(hull, hull_mat)
    parts.append(hull)

    nose = loft("NoseCap", [(1.27, 0.004, 0.004, 0.0), (1.12, 0.075, 0.055, 0.0), (1.02, 0.11, 0.08, 0.005)])
    common.assign(nose, accent_mat)
    parts.append(nose)

    canopy = loft("Canopy", CANOPY_PROFILE)
    common.assign(canopy, glass_mat)
    parts.append(canopy)

    wing = slab("WingR", [(0.18, 0.35), (0.20, -0.70), (1.15, -0.82), (1.12, -0.58), (0.55, -0.15)],
                thickness=0.05, z=-0.02)
    common.mirror_x(wing)
    common.assign(wing, hull_mat)
    parts.append(wing)

    stripe = slab("WingStripeR", [(0.70, -0.32), (0.74, -0.72), (1.06, -0.78), (1.04, -0.60)],
                  thickness=0.056, z=-0.02)
    common.mirror_x(stripe)
    common.assign(stripe, accent_mat)
    parts.append(stripe)

    # Vertical fin: build the outline in the XY plane (x stands in for height), then tip it upright.
    fin = slab("TailFin", [(0.0, -0.40), (0.0, -0.92), (0.40, -1.02), (0.40, -0.84)], thickness=0.04)
    fin.rotation_euler = (0, -math.pi / 2, 0)
    fin.location = (0, 0, 0.15)
    common.apply_transforms(fin)
    common.assign(fin, accent_mat)
    parts.append(fin)

    for side in (1, -1):
        nac = loft(f"Nacelle{side}", NACELLE_PROFILE, offset=(0.55 * side, 0.0, -0.05))
        common.assign(nac, dark_mat)
        parts.append(nac)
        n_glow = cylinder(f"NacelleGlow{side}", 0.065, 0.02, (0.55 * side, -0.99, -0.05))
        common.assign(n_glow, glow_mat)
        parts.append(n_glow)
        pod = cylinder(f"WingTip{side}", 0.035, 0.3, (1.14 * side, -0.70, -0.02))
        common.assign(pod, nav_green if side > 0 else nav_red)
        parts.append(pod)

    nozzle = cylinder("Nozzle", 0.20, 0.22, (0, -1.04, 0), radius2=0.15)
    common.assign(nozzle, dark_mat)
    parts.append(nozzle)
    core = cylinder("EngineCore", 0.15, 0.02, (0, -1.15, 0))
    common.assign(core, glow_mat)
    parts.append(core)

    for p in parts:
        common.shade_smooth(p, 50)

    ship = common.join(parts, "Ship")
    bpy.ops.object.select_all(action="DESELECT")
    ship.select_set(True)
    common.export_glb("ship.glb")

    common.render_preview("ship.png", cam_location=(2.6, 2.2, 1.7), target=(0, -0.05, 0), lens=55)


if __name__ == "__main__":
    build()
