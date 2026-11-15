"""Separate the two stages of the optimized Apollo GLB for the ascent animation.

blender -b --python tools/separar_modulo_apolo.py -- assets/props_luna/nasa
"""
from pathlib import Path
import sys

import bmesh
import bpy


SEAM_HEIGHT = 1.56


def export_stage(directory, name, clear_below):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(directory / "apollo_descenso.glb"))
    model = next(obj for obj in bpy.context.scene.objects if obj.type == "MESH")
    mesh = bmesh.new()
    mesh.from_mesh(model.data)
    mesh.transform(model.matrix_world)
    bmesh.ops.bisect_plane(
        mesh,
        geom=list(mesh.verts) + list(mesh.edges) + list(mesh.faces),
        dist=0.0001,
        plane_co=(0, 0, SEAM_HEIGHT),
        plane_no=(0, 0, 1),
        clear_inner=clear_below,
        clear_outer=not clear_below,
    )
    mesh.to_mesh(model.data)
    mesh.free()
    model.matrix_world.identity()
    model.name = name
    model.data.calc_loop_triangles()
    print(name, len(model.data.loop_triangles), "triangles")
    bpy.ops.export_scene.gltf(
        filepath=str(directory / f"{name}.glb"),
        export_format="GLB",
        export_animations=False,
        export_texcoords=False,
    )


if __name__ == "__main__":
    folder = Path(sys.argv[sys.argv.index("--") + 1]).resolve()
    export_stage(folder, "apollo_base_lunar", False)
    export_stage(folder, "apollo_etapa_ascenso", True)
