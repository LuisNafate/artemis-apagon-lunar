"""Reimport the delivery in Blender and check the skeleton, clips, UV and texture data."""

import bpy
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CLIPS = {"Idle", "Walk", "Run", "Jump", "Wave"}


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def gltf_json():
    data = (ROOT / "AstroCat.glb").read_bytes()
    magic, version, size = struct.unpack_from("<4sII", data)
    assert (magic, version, size) == (b"glTF", 2, len(data))
    length, kind = struct.unpack_from("<II", data, 12)
    assert kind == 0x4E4F534A
    return json.loads(data[20:20+length])


def mesh_report():
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    rigs = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
    assert len(meshes) == 1 and len(rigs) == 1
    rig = rigs[0]
    assert len(rig.data.bones) == 20
    assert len(meshes[0].data.materials) == 2
    triangles = 0
    for obj in meshes:
        assert obj.data.uv_layers.active, obj.name
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
        for vertex in obj.data.vertices:
            assert abs(sum(group.weight for group in vertex.groups)-1.0) < 0.001
            point = obj.matrix_world @ vertex.co
            for group in vertex.groups:
                name = obj.vertex_groups[group.group].name
                if name.startswith(("upper_arm.", "forearm.", "hand.", "thigh.", "shin.", "foot.")):
                    assert point.x * (1 if name.endswith(".L") else -1) > -.02, name
        assert any(mod.type == "ARMATURE" and mod.object == rig for mod in obj.modifiers)
    assert 8000 <= triangles <= 15000
    return rig, meshes[0], triangles


def clip_motion(rig, obj):
    available = {clip.name.split("|")[-1].strip(): clip for clip in bpy.data.actions}
    matches = {}
    for name in CLIPS:
        actions = [action for label, action in available.items() if label == name or label.endswith(name)]
        assert len(actions) == 1, (name, list(available))
        matches[name] = actions[0]
    state = rig.animation_data_create()
    for track in state.nla_tracks:
        track.mute = True
    actual = {}
    scene = bpy.context.scene
    for name, action in sorted(matches.items()):
        state.action = action
        armature_slots = [slot for slot in action.slots if slot.target_id_type == "OBJECT"]
        assert armature_slots
        state.action_slot = armature_slots[0]
        start, stop = action.frame_range
        snapshots = []
        for fraction in (0, .24, .48, .71):
            frame = round(start+(stop-start)*fraction)
            scene.frame_set(frame)
            obj_evaluated = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
            shape = obj_evaluated.to_mesh()
            snapshots.append([v.co.copy() for v in shape.vertices])
            obj_evaluated.to_mesh_clear()
        motion = max((a-b).length for snapshot in snapshots[1:] for a,b in zip(snapshots[0],snapshot))
        assert motion > .012, (name, motion)
        actual[name] = {"frames": [round(start), round(stop)], "max_point_motion_m": round(motion,4)}
    return actual


def verify():
    spec = gltf_json()
    assert len(spec["skins"]) == 1
    assert len(spec["meshes"]) == 1
    primitives = spec["meshes"][0]["primitives"]
    assert len(primitives) == 2
    assert {a["name"] for a in spec["animations"]} == CLIPS
    assert all(a["channels"] and a["samplers"] for a in spec["animations"])
    assert len(spec["images"]) == 3 and all("bufferView" in img for img in spec["images"])
    assert all({"POSITION","NORMAL","TEXCOORD_0","JOINTS_0","WEIGHTS_0"} <= set(p["attributes"])
               for p in primitives)
    report = {"blender": bpy.app.version_string, "gltf": {}, "fbx": {}}
    for fmt, op in (("gltf", bpy.ops.import_scene.gltf), ("fbx", bpy.ops.import_scene.fbx)):
        reset()
        ext = "glb" if fmt == "gltf" else fmt
        options = {"disable_bone_shape": True} if fmt == "gltf" else {}
        op(filepath=str(ROOT / ("AstroCat."+ext)), **options)
        rig, obj, count = mesh_report()
        report[fmt] = {"triangles": count, "bones": len(rig.data.bones), "mesh_objects": 1,
                       "materials": len(obj.data.materials), "actions": clip_motion(rig,obj)}
    print(json.dumps(report, indent=2))
    report["note"] = "Las cinco animaciones se incluyen en AstroCat.glb, AstroCat.fbx y AstroCat.blend."
    folder = ROOT / "animations"
    folder.mkdir(exist_ok=True)
    (folder/"verification.json").write_text(json.dumps(report, indent=2, ensure_ascii=False)+"\n", encoding="utf-8")


if __name__ == "__main__":
    verify()
