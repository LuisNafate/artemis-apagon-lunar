"""Render one diagnostic pose per native Blender action; the file is not modified."""

import bpy
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "animations"
OUT.mkdir(exist_ok=True)

scene = bpy.context.scene
rig = bpy.data.objects["AstroCat_Rig"]
camera = bpy.data.objects["ThreeQuarter_R"]
camera.data.ortho_scale = 4.20
camera.rotation_euler = (Vector((0, 0, 1.90)) - camera.location).to_track_quat("-Z", "Y").to_euler()
scene.camera = camera
scene.render.resolution_x = scene.render.resolution_y = 400
scene.cycles.samples = 12
for track in rig.animation_data.nla_tracks:
    track.mute = True

for name, fraction in {"Idle": .25, "Walk": .27, "Run": .28, "Jump": .45, "Wave": .44}.items():
    action = bpy.data.actions[name]
    rig.animation_data.action = action
    rig.animation_data.action_slot = action.slots[0]
    start, stop = action.frame_range
    scene.frame_set(round(start + (stop-start)*fraction))
    scene.render.filepath = str(OUT/(name+".png"))
    bpy.ops.render.render(write_still=True)
