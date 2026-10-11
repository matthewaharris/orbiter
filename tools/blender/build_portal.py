"""Builds the exit portal ring and exports game/assets/models/portal.glb.

The ring faces Blender -Y (Godot +Z, toward the tactical camera). Godot adds the swirl surface and particles.
    blender --background --factory-startup --python tools/blender/build_portal.py
"""
import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(__file__))
import common  # noqa: E402

RING_RADIUS = 1.5
SEGMENTS = 8


def build():
    common.reset_scene()

    frame_mat = common.material("PortalFrame", (0.06, 0.06, 0.08), metallic=0.95, roughness=0.25)
    trim_mat = common.material("PortalTrim", (0.75, 0.7, 0.62), metallic=0.8, roughness=0.3)
    energy_mat = common.material("PortalEnergy", (0.6, 0.3, 1.0), emission=(0.65, 0.35, 1.0),
                                 emission_strength=5.0)
    parts = []

    upright = (math.pi / 2, 0, 0)

    bpy.ops.mesh.primitive_torus_add(major_radius=RING_RADIUS, minor_radius=0.13, major_segments=96,
                                     minor_segments=16, rotation=upright)
    ring = bpy.context.active_object
    common.assign(ring, frame_mat)
    parts.append(ring)

    bpy.ops.mesh.primitive_torus_add(major_radius=RING_RADIUS - 0.17, minor_radius=0.035, major_segments=96,
                                     minor_segments=8, rotation=upright)
    inner = bpy.context.active_object
    common.assign(inner, energy_mat)
    parts.append(inner)

    for i in range(SEGMENTS):
        a = 2 * math.pi * i / SEGMENTS
        x, z = math.cos(a) * RING_RADIUS, math.sin(a) * RING_RADIUS
        bpy.ops.mesh.primitive_cube_add(size=1, location=(x, 0, z), rotation=(0, -a, 0))
        block = bpy.context.active_object
        block.scale = (0.36, 0.40, 0.30)  # (radial, depth, tangential)
        common.apply_transforms(block)
        common.assign(block, trim_mat)
        parts.append(block)

        bpy.ops.mesh.primitive_cube_add(size=1, location=(x, 0, z), rotation=(0, -a, 0))
        slit = bpy.context.active_object
        slit.scale = (0.38, 0.42, 0.06)
        common.apply_transforms(slit)
        common.assign(slit, energy_mat)
        parts.append(slit)

    for p in parts:
        common.shade_smooth(p, 35)

    portal = common.join(parts, "Portal")
    bpy.ops.object.select_all(action="DESELECT")
    portal.select_set(True)
    common.export_glb("portal.glb")

    common.render_preview("portal.png", cam_location=(2.4, -7.0, 1.6), lens=45)


if __name__ == "__main__":
    build()
