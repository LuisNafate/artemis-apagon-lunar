class_name LunarFlightView
extends CanvasLayer

const ASCENT := preload("res://assets/props_luna/nasa/apollo_etapa_ascenso.glb")

var _root: Control
var _ascent: Node3D
var _service: Node3D
var _command: Node3D
var _sky: LunarBackdrop
var _mando_label: Label3D
var _ascent_label: Label3D
var _entry_heat: MeshInstance3D


func build() -> void:
	layer = 0
	_root = Control.new()
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky = LunarBackdrop.new()
	_sky.orbital = true
	_root.add_child(_sky)
	_sky.configure("orbita", {"earth": "visible", "relief": 0.0})
	var holder := SubViewportContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.stretch = true
	holder.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_root.add_child(holder)
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var view := SubViewport.new()
	view.own_world_3d = true
	view.transparent_bg = true
	holder.add_child(view)
	var camera := Camera3D.new()
	camera.position = Vector3(1, 3.7, 13)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 9.8
	view.add_child(camera)
	camera.look_at(Vector3(0, 1.3, 0))
	camera.make_current()
	var lamp := DirectionalLight3D.new()
	lamp.rotation_degrees = Vector3(-26, -25, 15)
	lamp.light_energy = 1.35
	view.add_child(lamp)
	_ascent = ASCENT.instantiate()
	view.add_child(_ascent)
	_ascent.rotation.z = PI * 0.5
	var orbiter := Node3D.new()
	view.add_child(orbiter)
	_service = Node3D.new()
	orbiter.add_child(_service)
	_hull(_service, Vector3(-1.3, 0, 0), 0.76, 0.76, 2.42, Color("#cad3d7"))
	_hull(_service, Vector3(-2.81, 0, 0), 0.54, 0.25, 0.58, Color("#4b5262"))
	_hull(_service, Vector3(-0.15, 0, 0), 0.78, 0.78, 0.17, Color("#aa7a53"))
	_command = Node3D.new()
	orbiter.add_child(_command)
	_hull(_command, Vector3(0.47, 0, 0), 0.76, 0.28, 1.11, Color("#f4e6d0"))
	_hull(_command, Vector3(1.13, 0, 0), 0.26, 0.26, 0.24, Color("#a7815f"))
	FieldWorld.box(_command, Vector3(0.54, 0.15, 0.58), Vector3(0.3, 0.14, 0.11), CrestWorld.FRAME)

	_mando_label = _caption(view, "NAVE ORBITAL")
	_mando_label.position = Vector3(-1.23, -0.98, 0.68)
	_ascent_label = _caption(view, "ETAPA DE ASCENSO")
	_entry_heat = FieldWorld.ball(
		_command, Vector3(-0.28, 0, -0.05), Vector3(0.52, 1.57, 1.59), Color("#e0824b"), true
	)
	_entry_heat.hide()

	_root.hide()


func present(phase: int, progress: float) -> void:
	_root.visible = phase >= 1
	if phase < 1:
		return
	_sky.planet_scale = 0.87 if phase < 3 else 0.87 + progress * 0.42
	_sky.update_sky(0.016, false)
	_service.visible = phase < 3
	_ascent.visible = phase == 1
	_mando_label.visible = phase == 1
	_ascent_label.visible = phase == 1
	_entry_heat.visible = phase == 3 and progress > 0.14
	_ascent.position = Vector3(lerpf(9.0, 3.56, smoothstep(0.0, 0.85, progress)), 0.05, 0)
	_ascent.scale = Vector3.ONE * 0.66
	_ascent_label.position = _ascent.position + Vector3(-1.57, -0.96, 0.68)
	_command.position = Vector3.ZERO
	_service.position = Vector3.ZERO
	if phase >= 2:
		var travel := (
			Vector3(4.1, 1.9, 0) * progress
			if phase == 2
			else Vector3(-1.8, 0.32, 0).lerp(Vector3(5, 3, 0), progress)
		)
		_command.position = travel
		_service.position = travel
		_command.rotation.z = 0
		_service.rotation.z = 0.12 + 0.42 * progress
		_service.rotation.z = _command.rotation.z
	else:
		_command.rotation.z = 0
		_service.rotation.z = 0


func _caption(parent: Node, text: String) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = CrestWorld.MONO
	label.font_size = 30
	label.pixel_size = 0.0135
	label.modulate = Color("#ebdec3")
	label.outline_modulate = Color("#221c22")
	label.outline_size = 12
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)
	return label


func _hull(
	parent: Node3D, point: Vector3, base: float, tip: float, length: float, tint: Color
) -> void:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = base
	mesh.top_radius = tip
	mesh.height = length
	mesh.radial_segments = 20
	var piece := FieldWorld._mesh(parent, point, mesh, tint, false)
	piece.rotation.z = -PI * 0.5
