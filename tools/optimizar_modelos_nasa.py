"""Build the game's two NASA-derived GLBs.

Run with Blender: blender -b --python tools/optimizar_modelos_nasa.py -- INPUT_DIR OUTPUT_DIR
INPUT_DIR contains the two original GLBs with the names below.
"""
import argparse
from pathlib import Path
import sys

import bpy
from mathutils import Vector


COLORS = {
    "shell": (0.70, 0.77, 0.86),
    "amber": (0.88, 0.47, 0.17),
    "structure": (0.17, 0.23, 0.30),
    "dark": (0.052, 0.079, 0.14),
    "solar": (0.085, 0.24, 0.45),
}

APOLLO_MATERIALS = {
    "blinn1SG": "amber", "blinn2SG": "structure", "blinn3SG": "shell",
    "blinn4SG": "shell", "blinn5SG": "amber", "blinn6SG": "dark",
    "blinn7SG": "shell", "blinn8SG": "structure", "blinn9SG": "amber",
    "blinn10SG": "shell", "blinn12SG": "structure", "initialShadingGr": "structure",
}

LRO_MATERIALS = {
    "foil_gold": "amber", "foil_silver": "shell", "foil_silver_dish": "shell",
    "shiny_panel": "shell", "tex_01": "structure", "tex_02": "solar", "tex_03": "amber",
}


def make_material(name, color):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1.0)
    shader.inputs["Roughness"].default_value = 0.78
    mat.use_backface_culling = True
    return mat


def triangle_count(obj):
    obj.data.calc_loop_triangles()
    return len(obj.data.loop_triangles)


def place_vertices(mesh, origin, factor):
    for vertex in mesh.vertices:
        vertex.co = (vertex.co - origin) * factor
    mesh.update()


def transform_model(source, target, remap, ratio, span, grounded):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source))
    parts = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    before = sum(triangle_count(obj) for obj in parts)
    colors = {name: make_material(name, value) for name, value in COLORS.items()}

    for obj in parts:
        world = obj.matrix_world.copy()
        obj.parent = None
        obj.matrix_world = world
        obj.data.transform(world)
        obj.matrix_world.identity()
        for slot in obj.material_slots:
            if slot.material is not None:
                source_name = slot.material.name.split(".")[0]
                slot.material = colors[remap.get(source_name, "structure")]
        if not obj.material_slots:
            obj.data.materials.append(colors["structure"])
        bpy.context.view_layer.objects.active = obj
        if len(obj.data.polygons) > 3:
            decimate = obj.modifiers.new("simplify_for_game", "DECIMATE")
            decimate.ratio = ratio
            bpy.ops.object.modifier_apply(modifier=decimate.name)

    bpy.ops.object.select_all(action="DESELECT")
    for obj in parts:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    model = bpy.context.object
    model.name = target.stem

    # Joining may leave duplicate slots. Use a single slot per final color.
    material_keys = [
        slot.material.name if slot.material else "structure" for slot in model.material_slots
    ]
    final_keys = [
        material_keys[poly.material_index] if material_keys else "structure"
        for poly in model.data.polygons
    ]
    model.data.materials.clear()
    key_indices = {}
    for key in dict.fromkeys(final_keys):
        key_indices[key] = len(model.data.materials)
        model.data.materials.append(colors[key])
    for polygon, key in zip(model.data.polygons, final_keys, strict=True):
        polygon.material_index = key_indices[key]

    coords = [vertex.co for vertex in model.data.vertices]
    lo = Vector([min(point[axis] for point in coords) for axis in range(3)])
    hi = Vector([max(point[axis] for point in coords) for axis in range(3)])
    middle = (lo + hi) / 2.0
    if grounded:
        middle.z = lo.z
    place_vertices(model.data, middle, span / max(hi - lo))

    for layer in list(model.data.uv_layers):
        model.data.uv_layers.remove(layer)
    for attr in list(model.data.color_attributes):
        model.data.color_attributes.remove(attr)
    model.data.validate(clean_customdata=True)
    end_count = triangle_count(model)
    bpy.ops.export_scene.gltf(
        filepath=str(target), export_format="GLB", use_selection=True,
        export_texcoords=False, export_attributes=False, export_animations=False,
    )
    print(f"ASSET {target.name}: {before} -> {end_count} triangles")
    if end_count >= before:
        raise RuntimeError(f"No geometry reduction for {target.name}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    args.output.mkdir(parents=True, exist_ok=True)
    for source, name, colors, ratio, span, ground in (
        ("apollo-lunar-module.glb", "apollo_descenso.glb", APOLLO_MATERIALS, 0.072, 4.5, True),
        ("lunar-reconnaissance-orbiter-b.glb", "lro_miniatura.glb", LRO_MATERIALS, 0.21, 3.2, False),
    ):
        transform_model(
            args.input / source, args.output / name, colors, ratio, span, ground
        )


if __name__ == "__main__":
    main()
