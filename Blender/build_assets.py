"""Author Purrfect Territory 3D's kit in Blender and export GLBs.

    /Applications/Blender.app/Contents/MacOS/Blender --background --python Blender/build_assets.py

Produces:
    Assets/Models/cat.glb        one stylised cat, origin at its feet
    Assets/Models/tile.glb       bevelled 1 x 1 x 0.12 tile
    Assets/Models/tray.glb       rounded board tray with a raised rim
    Assets/Models/yarn.glb       decorative yarn ball
    Assets/Blender/purrfect_kit.blend

Everything is original geometry built from primitives; no third-party assets.
"""
from __future__ import annotations

import math
import pathlib

import bpy
from mathutils import Vector

ROOT = pathlib.Path(__file__).resolve().parent.parent
MODELS = ROOT / "Assets" / "Models"
SOURCE = ROOT / "Assets" / "Blender"
MODELS.mkdir(parents=True, exist_ok=True)
SOURCE.mkdir(parents=True, exist_ok=True)


def reset() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name: str, color, roughness=0.55, metallic=0.0, emission=None, strength=0.0):
    existing = bpy.data.materials.get(name)
    if existing:
        return existing
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf is None:
        return mat
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    for key in ("Emission Color", "Emission"):
        if key in bsdf.inputs:
            bsdf.inputs[key].default_value = (*(emission or color), 1.0)
            break
    if "Emission Strength" in bsdf.inputs:
        bsdf.inputs["Emission Strength"].default_value = strength
    return mat


def smooth(obj) -> None:
    for poly in obj.data.polygons:
        poly.use_smooth = True


def bevel(obj, width=0.05, segments=3) -> None:
    mod = obj.modifiers.new("bevel", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    mod.angle_limit = math.radians(40)


def sphere(name, location, scale, mat, segments=28, rings=18, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=1.0, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    obj.rotation_euler = rotation
    obj.data.materials.append(mat)
    smooth(obj)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return obj


def cone(name, location, radius, depth, mat, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cone_add(vertices=24, radius1=radius, radius2=0.02, depth=depth, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = rotation
    obj.data.materials.append(mat)
    smooth(obj)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return obj


def cube(name, location, scale, mat, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    obj.rotation_euler = rotation
    obj.data.materials.append(mat)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return obj


def torus(name, location, major, minor, mat, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major, minor_radius=minor, major_segments=36, minor_segments=12, location=location
    )
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = rotation
    obj.data.materials.append(mat)
    smooth(obj)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return obj


def join(objects, name):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    merged = bpy.context.object
    merged.name = name
    return merged


def export(name: str, objects) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.export_scene.gltf(
        filepath=str(MODELS / f"{name}.glb"),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
    )
    print("exported", name)


# ---------------------------------------------------------------------------
# the cat
# ---------------------------------------------------------------------------

def build_cat():
    fur = material("FurCream", (0.98, 0.90, 0.78), 0.62)
    fur_light = material("FurLight", (1.0, 0.97, 0.92), 0.6)
    pink = material("NosePink", (0.94, 0.55, 0.62), 0.45)
    dark = material("EyeDark", (0.09, 0.08, 0.11), 0.35)
    collar = material("CollarMint", (0.34, 0.76, 0.66), 0.4)
    bell = material("BellGold", (0.95, 0.78, 0.30), 0.25, 0.85)
    blush = material("Blush", (0.95, 0.63, 0.63), 0.7)

    parts = []
    # body, facing -Y so the model looks toward the camera after import
    body = sphere("Body", (0, 0, 0.52), (0.46, 0.40, 0.52), fur)
    parts.append(body)
    chest = sphere("Chest", (0, -0.20, 0.60), (0.28, 0.22, 0.32), fur_light)
    parts.append(chest)
    # head sits high and slightly forward, with a big rounded muzzle
    head = sphere("Head", (0, -0.10, 1.02), (0.40, 0.36, 0.36), fur)
    parts.append(head)
    muzzle = sphere("Muzzle", (0, -0.40, 0.94), (0.19, 0.12, 0.13), fur_light)
    parts.append(muzzle)
    nose = sphere("Nose", (0, -0.50, 0.97), (0.045, 0.035, 0.035), pink)
    parts.append(nose)
    for side in (-1, 1):
        ear = cone(
            f"Ear{side}",
            (side * 0.22, -0.06, 1.33),
            0.14,
            0.30,
            fur,
            rotation=(math.radians(-6), 0, side * math.radians(-14)),
        )
        parts.append(ear)
        inner = cone(
            f"EarInner{side}",
            (side * 0.22, -0.09, 1.34),
            0.085,
            0.22,
            pink,
            rotation=(math.radians(-6), 0, side * math.radians(-14)),
        )
        parts.append(inner)
        eye = sphere(f"Eye{side}", (side * 0.145, -0.40, 1.08), (0.055, 0.045, 0.065), dark)
        parts.append(eye)
        glint = sphere(f"Glint{side}", (side * 0.125, -0.445, 1.10), (0.017, 0.012, 0.017), fur_light)
        parts.append(glint)
        cheek = sphere(f"Cheek{side}", (side * 0.245, -0.32, 0.98), (0.07, 0.035, 0.05), blush)
        parts.append(cheek)
        paw = sphere(f"Paw{side}", (side * 0.24, -0.34, 0.10), (0.13, 0.16, 0.09), fur_light)
        parts.append(paw)
        hind = sphere(f"Hind{side}", (side * 0.28, 0.22, 0.14), (0.15, 0.19, 0.11), fur_light)
        parts.append(hind)
        # whiskers are thin tapered cones
        for index, tilt in enumerate((-0.05, 0.02, 0.09)):
            whisker = cone(
                f"Whisker{side}_{index}",
                (side * 0.30, -0.42, 0.96 + tilt),
                0.008,
                0.30,
                fur_light,
                rotation=(0, math.radians(90), side * math.radians(78)),
            )
            parts.append(whisker)

    # a tail that curls up beside the body
    tail_curve = bpy.data.curves.new("TailCurve", type="CURVE")
    tail_curve.dimensions = "3D"
    tail_curve.bevel_depth = 0.065
    tail_curve.bevel_resolution = 3
    spline = tail_curve.splines.new("BEZIER")
    spline.bezier_points.add(3)
    points = [
        ((0.30, 0.34, 0.22), (0.0, 0.1, 0.0)),
        ((0.52, 0.26, 0.52), (0.0, 0.0, 0.15)),
        ((0.50, 0.06, 0.86), (0.0, -0.1, 0.05)),
        ((0.34, -0.04, 0.98), (0.0, 0.0, 0.0)),
    ]
    for point, handle in zip(spline.bezier_points, points):
        point.co = Vector(handle[0])
        point.handle_left_type = "AUTO"
        point.handle_right_type = "AUTO"
    tail = bpy.data.objects.new("Tail", tail_curve)
    bpy.context.collection.objects.link(tail)
    tail.data.materials.append(fur)
    bpy.context.view_layer.objects.active = tail
    tail.select_set(True)
    bpy.ops.object.convert(target="MESH")
    tail = bpy.context.object
    smooth(tail)
    parts.append(tail)

    # collar and bell
    neck = torus("Collar", (0, -0.04, 0.80), 0.34, 0.055, collar, rotation=(math.radians(80), 0, 0))
    parts.append(neck)
    tag = sphere("Bell", (0, -0.36, 0.74), (0.062, 0.055, 0.062), bell)
    parts.append(tag)

    cat = join(parts, "Cat")
    cat.location = (0, 0, 0)
    return cat


# ---------------------------------------------------------------------------
# board kit
# ---------------------------------------------------------------------------

def build_tile():
    wood = material("TileCream", (0.99, 0.95, 0.87), 0.5)
    tile = cube("Tile", (0, 0, 0), (0.94, 0.94, 0.12), wood)
    bevel(tile, 0.07, 3)
    bpy.ops.object.modifier_apply(modifier="bevel")
    smooth(tile)
    return tile


def build_tray():
    wood = material("TrayWalnut", (0.30, 0.19, 0.22), 0.45)
    felt = material("TrayFelt", (0.17, 0.12, 0.19), 0.85)
    base = cube("TrayBase", (0, 0, -0.16), (11.4, 11.4, 0.22), wood)
    bevel(base, 0.22, 4)
    bpy.ops.object.modifier_apply(modifier="bevel")
    smooth(base)
    lining = cube("TrayLining", (0, 0, -0.02), (10.9, 10.9, 0.06), felt)
    bevel(lining, 0.15, 3)
    bpy.ops.object.modifier_apply(modifier="bevel")
    smooth(lining)
    tray = join([base, lining], "Tray")
    return tray


def build_yarn():
    wool = material("YarnRose", (0.93, 0.52, 0.60), 0.75)
    string = material("YarnTwine", (0.98, 0.86, 0.72), 0.7)
    ball = sphere("YarnBall", (0, 0, 0.22), (0.22, 0.22, 0.22), wool)
    wrap_a = torus("WrapA", (0, 0, 0.22), 0.21, 0.014, string, rotation=(math.radians(20), math.radians(15), 0))
    wrap_b = torus("WrapB", (0, 0, 0.22), 0.20, 0.014, string, rotation=(math.radians(-25), math.radians(70), 0))
    wrap_c = torus("WrapC", (0, 0, 0.22), 0.205, 0.014, string, rotation=(math.radians(75), math.radians(-10), 0))
    return join([ball, wrap_a, wrap_b, wrap_c], "Yarn")


def main() -> None:
    reset()
    cat = build_cat()
    export("cat", [cat])

    reset()
    tile = build_tile()
    export("tile", [tile])

    reset()
    tray = build_tray()
    export("tray", [tray])

    reset()
    yarn = build_yarn()
    export("yarn", [yarn])

    # keep one editable scene with everything for future art passes
    reset()
    build_tray()
    build_tile()
    build_yarn()
    build_cat()
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "purrfect_kit.blend"))
    print("saved", SOURCE / "purrfect_kit.blend")


main()
