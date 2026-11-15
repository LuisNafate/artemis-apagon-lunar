class_name CrestPilot
extends FieldPilot

const CAT := preload("res://assets/pilotos/astrocat_guia.glb")
const MODEL_HEIGHT := 1.68
const TINT_STRENGTH := 0.32

var tint := Color.WHITE
var animator: AnimationPlayer
var _body: Node3D
var _step := 0.0
var _stride_strength := 0.0
var _load_strength := 0.0
var _clip := &""


func _build_visuals() -> void:
	# Diseno del AstroCat guia aplicado a los pilotos; el tinte distingue a cada jugador.
	_body = Node3D.new()
	rig.add_child(_body)
	var model: Node3D = CAT.instantiate()
	_body.add_child(model)
	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var chain := Transform3D.IDENTITY
	var node: Node = mesh
	while node != null and node != model.get_parent():
		if node is Node3D:
			chain = (node as Node3D).transform * chain
		node = node.get_parent()
	var bounds := chain * mesh.get_aabb()
	model.scale = Vector3.ONE * MODEL_HEIGHT / bounds.size.y
	model.position.y = -bounds.position.y * model.scale.y
	var suit := mesh.get_active_material(0)
	if suit is StandardMaterial3D:
		var tinted := (suit as StandardMaterial3D).duplicate() as StandardMaterial3D
		tinted.albedo_color = Color.WHITE.lerp(tint, TINT_STRENGTH)
		mesh.set_surface_override_material(0, tinted)
	animator = model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for clip: StringName in [&"Idle", &"Walk", &"Run"]:
		animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	_play(&"Idle")
	carrying.position = Vector3(0.46, 0.52, -0.48)
	direction = Vector3.BACK
	rig.rotation.y = PI


func drive(delta: float, axis: Vector2, jump: bool, dash: bool) -> void:
	super.drive(delta, axis, jump, dash)
	var speed := Vector2(velocity.x, velocity.z).length()
	_step = fposmod(_step + speed * delta * 2.8, TAU)
	_stride_strength = move_toward(_stride_strength, clampf(speed / WALK_SPEED, 0, 1), delta * 8)


func animate_gait(delta: float, has_box: bool, seated: bool) -> void:
	if seated:
		_stride_strength = 0.0
	_load_strength = move_toward(_load_strength, float(has_box), delta * 9.0)
	var moving := _stride_strength > 0.15
	_play(&"Walk" if moving else &"Idle")
	animator.speed_scale = clampf(_stride_strength * 1.1, 0.6, 1.4) if moving else 1.0
	_body.position.y = absf(sin(_step)) * 0.02 * _stride_strength


func _play(clip: StringName) -> void:
	if clip == _clip:
		return
	_clip = clip
	animator.play(clip, 0.15)


func animate_replica(
	delta: float, heading: Vector3, moving: bool, has_box: bool, seated: bool
) -> void:
	direction = heading
	rig.rotation.y = lerp_angle(rig.rotation.y, atan2(-heading.x, -heading.z), delta * 13.0)
	_step = fposmod(_step + float(moving) * WALK_SPEED * delta * 2.8, TAU)
	_stride_strength = move_toward(_stride_strength, float(moving), delta * 8.0)
	animate_gait(delta, has_box, seated)
