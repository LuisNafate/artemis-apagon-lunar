class_name CrestPilot
extends FieldPilot

const CAT := preload("res://assets/pilotos/astrocat_guia.glb")
const TINT_STRENGTH := 0.32
const MODEL_HEIGHT := 1.68

var tint := Color.WHITE
var suit: StandardMaterial3D
var skeleton: Skeleton3D
var _body: Node3D
var _bone_indices: Dictionary = {}
var _bone_frames: Array[Quaternion] = []
var _step := 0.0
var _stride_strength := 0.0
var _load_strength := 0.0


func _build_visuals() -> void:
	_body = Node3D.new()
	rig.add_child(_body)
	var model: Node3D = CAT.instantiate()
	_body.add_child(model)
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var facing := Quaternion(Vector3.UP, PI)
	model.quaternion = facing
	for bone in range(skeleton.get_bone_count()):
		_bone_indices[StringName(skeleton.get_bone_name(bone))] = bone
		var frame := skeleton.get_bone_global_rest(bone).basis.get_rotation_quaternion()
		_bone_frames.append(facing * frame)
	skeleton.reset_bone_poses()

	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var bounds := (
		(model.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
	)
	model.scale = Vector3.ONE * MODEL_HEIGHT / bounds.size.y
	model.position.y = -bounds.position.y * model.scale.y
	var original := mesh.get_active_material(0) as StandardMaterial3D
	suit = original.duplicate() as StandardMaterial3D
	suit.albedo_color = Color.WHITE.lerp(tint, TINT_STRENGTH)
	mesh.set_surface_override_material(0, suit)
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
	var swing := sin(_step) * _stride_strength
	_body.position.y = -0.016 * _stride_strength + absf(swing) * 0.022
	_rotate(&"torso", Vector3(0.06 * _stride_strength, swing * -0.09, 0.045 * swing))
	_rotate(&"head", Vector3(-0.04 * _stride_strength, swing * 0.065, -0.06 * swing))
	_rotate(&"tail_1", Vector3(0.04 * swing, swing * 0.22, 0))
	_rotate(&"tail_3", Vector3(swing * -0.13, cos(_step) * 0.18 * _stride_strength, 0))
	_pose_leg(&"thigh.L", &"shin.L", &"foot.L", _step)
	_pose_leg(&"thigh.R", &"shin.R", &"foot.R", _step + PI)
	_rotate(&"upper_arm.L", Vector3(-swing * 0.34, 0, -0.08 * absf(swing)))
	_rotate(&"forearm.L", Vector3(maxf(0.0, -swing) * 0.26, 0, 0))
	_rotate(&"upper_arm.R", Vector3(lerpf(swing * 0.34, 0.53, _load_strength), 0, 0))
	_rotate(&"forearm.R", Vector3(lerpf(maxf(0.0, swing) * 0.26, 0.38, _load_strength), 0, 0))


func _pose_leg(hip: StringName, knee: StringName, ankle: StringName, phase: float) -> void:
	var swing := sin(phase) * _stride_strength
	var lift := maxf(0.0, cos(phase)) * _stride_strength
	_rotate(hip, Vector3(swing * 0.49 + lift * 0.14, 0, 0))
	_rotate(knee, Vector3(-lift * 0.62, 0, 0))
	_rotate(ankle, Vector3(lift * 0.25 - swing * 0.21, 0, 0))


func _rotate(bone: StringName, angles: Vector3) -> void:
	var index: int = _bone_indices[bone]
	# Convert the gameplay pose from character axes into the imported joint's rest axes.
	var frame := _bone_frames[index]
	var offset := frame.inverse() * Quaternion.from_euler(angles) * frame
	var rest := skeleton.get_bone_rest(index).basis.get_rotation_quaternion()
	skeleton.set_bone_pose_rotation(index, (rest * offset).normalized())


func animate_replica(
	delta: float, heading: Vector3, moving: bool, has_box: bool, seated: bool
) -> void:
	direction = heading
	rig.rotation.y = lerp_angle(rig.rotation.y, atan2(-heading.x, -heading.z), delta * 13.0)
	_step = fposmod(_step + float(moving) * WALK_SPEED * delta * 2.8, TAU)
	_stride_strength = move_toward(_stride_strength, float(moving), delta * 8.0)
	animate_gait(delta, has_box, seated)
