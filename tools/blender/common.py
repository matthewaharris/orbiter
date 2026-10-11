"""Shared helpers for Orbiter's Blender asset scripts.

Run any build script with:
    blender --background --factory-startup --python tools/blender/build_ship.py

Conventions:
  * Model "forward" along Blender +Y  -> Godot -Z (forward) after glTF export.
  * Model "up" along Blender +Z       -> Godot +Y.
"""
import math
import os
import sys

import bpy

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MODELS_DIR = os.path.join(REPO, "game", "assets", "models")
PREVIEW_DIR = os.path.join(REPO, "tools", "blender", "previews")


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name, color, metallic=0.0, roughness=0.5, emission=None, emission_strength=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission is not None:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    return mat


def assign(obj, mat):
    obj.data.materials.clear()
    obj.data.materials.append(mat)


def shade_smooth(obj, angle_deg=40.0):
    """Smooth shading with sharp edges kept above angle_deg."""
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    try:
        bpy.ops.object.shade_auto_smooth(angle=math.radians(angle_deg))
    except Exception:
        bpy.ops.object.shade_smooth()
    obj.select_set(False)


def apply_transforms(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    obj.select_set(False)


def join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    result = bpy.context.view_layer.objects.active
    result.name = name
    return result


def mirror_x(obj):
    mod = obj.modifiers.new("MirrorX", "MIRROR")
    mod.use_axis[0] = True
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)


def export_glb(filename):
    os.makedirs(MODELS_DIR, exist_ok=True)
    path = os.path.join(MODELS_DIR, filename)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_apply=True)
    print(f"[orbiter] exported {path}")
    return path


def render_preview(filename, cam_location, target=(0, 0, 0), lens=50, size=(960, 640)):
    """Render a quick look-dev image so changes can be reviewed without opening Blender."""
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    scene = bpy.context.scene

    world = bpy.data.worlds.new("PreviewWorld")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.01, 0.012, 0.025, 1)
    scene.world = world

    cam_data = bpy.data.cameras.new("PreviewCam")
    cam_data.lens = lens
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = cam_location
    tgt = bpy.data.objects.new("PreviewTarget", None)
    scene.collection.objects.link(tgt)
    tgt.location = target
    track = cam.constraints.new("TRACK_TO")
    track.target = tgt
    track.track_axis = "TRACK_NEGATIVE_Z"
    track.up_axis = "UP_Y"
    scene.camera = cam

    for name, loc, energy, color in [
        ("Key", (4, -3, 5), 800, (1.0, 0.92, 0.85)),
        ("Rim", (-4, 4, 2), 600, (0.5, 0.7, 1.0)),
        ("Fill", (-3, -4, -1), 150, (0.8, 0.6, 1.0)),
    ]:
        ld = bpy.data.lights.new(name, "AREA")
        ld.energy = energy
        ld.color = color
        ld.size = 3
        lo = bpy.data.objects.new(name, ld)
        scene.collection.objects.link(lo)
        lo.location = loc
        c = lo.constraints.new("TRACK_TO")
        c.target = tgt
        c.track_axis = "TRACK_NEGATIVE_Z"
        c.up_axis = "UP_Y"

    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    if "BLENDER_EEVEE" in engines:
        scene.render.engine = "BLENDER_EEVEE"
    elif "BLENDER_EEVEE_NEXT" in engines:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    else:
        scene.render.engine = "CYCLES"
        scene.cycles.samples = 32
    scene.render.resolution_x, scene.render.resolution_y = size
    scene.render.filepath = os.path.join(PREVIEW_DIR, filename)
    scene.view_settings.view_transform = "AgX" if "AgX" in [
        v.identifier for v in scene.view_settings.bl_rna.properties["view_transform"].enum_items
    ] else "Filmic"
    try:
        bpy.ops.render.render(write_still=True)
        print(f"[orbiter] preview {scene.render.filepath}")
    except Exception as exc:  # preview is a nice-to-have; never block the export
        print(f"[orbiter] preview render failed: {exc}", file=sys.stderr)
