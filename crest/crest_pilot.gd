class_name CrestPilot
extends FieldPilot

const CAT := preload("res://assets/pilotos/astrocat_guia.glb")
const TINT_STRENGTH := 0.32
const MODEL_HEIGHT := 1.68
const EARTH_RATE := 2.8
const LUNAR_RATE := 1.7
const SHADOW_REACH := 8.0
const SEAT_DROP := 0.2
const SEAT_THIGH := 1.3

var tint := Color.WHITE
## Marcha lunar fuera de la base: zancada lenta y rebotona.
var lunar_gait := false
## Sentado (nave o rover): sin zancada ni salto.
var is_seated := false
var suit: StandardMaterial3D
var skeleton: Skeleton3D
var _body: Node3D
var _bone_indices: Dictionary = {}
var _bone_frames: Array[Quaternion] = []
var _step := 0.0
var _stride_strength := 0.0
var _load_strength := 0.0
var _air_strength := 0.0
var _air_time := 0.0
var _airborne := false
var _last_y := NAN
var _shadow: MeshInstance3D
var _dust: CPUParticles3D


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
	_build_effects()


func _build_effects() -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = 0.42
	disc.bottom_radius = 0.42
	disc.height = 0.01
	disc.radial_segments = 20
	disc.rings = 1
	var ink := StandardMaterial3D.new()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ink.albedo_color = Color(0.04, 0.03, 0.06, 0.4)
	_shadow = MeshInstance3D.new()
	_shadow.mesh = disc
	_shadow.material_override = ink
	_shadow.top_level = true
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shadow)
	var grain := SphereMesh.new()
	grain.radius = 0.07
	grain.height = 0.14
	grain.radial_segments = 6
	grain.rings = 3
	var dust_material := StandardMaterial3D.new()
	dust_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dust_material.albedo_color = Color("#b9b2a6")
	grain.material = dust_material
	_dust = CPUParticles3D.new()
	_dust.mesh = grain
	_dust.emitting = false
	_dust.one_shot = true
	_dust.amount = 14
	_dust.lifetime = 0.9
	_dust.explosiveness = 1.0
	_dust.direction = Vector3.UP
	_dust.spread = 80.0
	_dust.initial_velocity_min = 0.6
	_dust.initial_velocity_max = 1.4
	_dust.gravity = Vector3(0, -1.2, 0)
	_dust.scale_amount_min = 0.5
	_dust.scale_amount_max = 1.2
	_dust.position.y = 0.05
	add_child(_dust)


func drive(delta: float, axis: Vector2, jump: bool, dash: bool) -> void:
	super.drive(delta, axis, jump, dash)
	var speed := Vector2(velocity.x, velocity.z).length()
	_step = fposmod(_step + speed * delta * _gait_rate(), TAU)
	_track_air(delta, not is_on_floor())
	_stride_strength = move_toward(_stride_strength, clampf(speed / WALK_SPEED, 0, 1), delta * 8)


func _gait_rate() -> float:
	return LUNAR_RATE if lunar_gait else EARTH_RATE


## Registra el vuelo y levanta polvo al despegar y al aterrizar tras un salto de verdad.
func _track_air(delta: float, in_air: bool) -> void:
	if in_air and not _airborne:
		_airborne = true
		_air_time = 0.0
		if velocity.y > 1.0:
			_puff()
	elif in_air:
		_air_time += delta
	elif _airborne:
		_airborne = false
		if _air_time > 0.3:
			_puff()


func _puff() -> void:
	if _dust != null and is_inside_tree():
		_dust.restart()
		_dust.emitting = true


func animate_gait(delta: float, has_box: bool, seated: bool) -> void:
	is_seated = seated
	if seated:
		_stride_strength = 0.0
	_load_strength = move_toward(_load_strength, float(has_box), delta * 9.0)
	_air_strength = move_toward(_air_strength, float(_airborne and not seated), delta * 7.0)
	var air := _air_strength
	var gait := _stride_strength * (1.0 - air)
	var bounce := 0.07 if lunar_gait else 0.022
	var reach := 1.3 if lunar_gait else 1.0
	var swing := sin(_step) * gait
	_body.position.y = -0.016 * gait + absf(swing) * bounce
	_rotate(&"torso", Vector3(0.06 * gait - 0.1 * air, swing * -0.09, 0.045 * swing))
	_rotate(&"head", Vector3(-0.04 * gait + 0.08 * air, swing * 0.065, -0.06 * swing))
	_rotate(&"tail_1", Vector3(0.04 * swing + 0.25 * air, swing * 0.22, 0))
	_rotate(&"tail_3", Vector3(swing * -0.13 + 0.3 * air, cos(_step) * 0.18 * gait, 0))
	_pose_leg(&"thigh.L", &"shin.L", &"foot.L", _step, gait * reach)
	_pose_leg(&"thigh.R", &"shin.R", &"foot.R", _step + PI, gait * reach)
	# En el aire los brazos suben, salvo el que sostiene la caja.
	var arm_up := air * (1.0 - _load_strength)
	var arm := swing * reach * 0.34
	_rotate(&"upper_arm.L", Vector3(-arm + 1.1 * arm_up, 0, -0.08 * absf(swing) - 0.35 * arm_up))
	_rotate(&"forearm.L", Vector3(maxf(0.0, -swing) * 0.26 + 0.3 * arm_up, 0, 0))
	_rotate(
		&"upper_arm.R", Vector3(lerpf(arm + 1.1 * arm_up, 0.53, _load_strength), 0, 0.35 * arm_up)
	)
	_rotate(
		&"forearm.R",
		Vector3(lerpf(maxf(0.0, swing) * 0.26 + 0.3 * arm_up, 0.38, _load_strength), 0, 0)
	)
	if seated:
		_sit()
	_place_shadow()


## Sentado al volante: las piernas van hacia delante, el cuerpo baja al asiento y los brazos
## alcanzan el manillar.
func _sit() -> void:
	_body.position.y = -SEAT_DROP
	for side in [&"L", &"R"]:
		_rotate(StringName("thigh." + side), Vector3(SEAT_THIGH, 0, 0))
		_rotate(StringName("shin." + side), Vector3(-SEAT_THIGH, 0, 0))
		_rotate(StringName("foot." + side), Vector3(0.3, 0, 0))
		_rotate(StringName("upper_arm." + side), Vector3(0.7, 0, 0))
		_rotate(StringName("forearm." + side), Vector3(0.5, 0, 0))


## Sombra circular bajo el piloto: un rayo hacia abajo da el suelo; se encoge con la altura.
func _place_shadow() -> void:
	if _shadow == null or not is_inside_tree():
		return
	var from := global_position + Vector3.UP * 0.4
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * SHADOW_REACH)
	query.collision_mask = 1
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	_shadow.visible = not hit.is_empty()
	if hit.is_empty():
		return
	var height: float = maxf(0.0, global_position.y - hit.position.y)
	_shadow.global_position = hit.position + Vector3.UP * 0.03
	_shadow.scale = Vector3.ONE * (1.0 / (1.0 + height * 0.35))


func _pose_leg(
	hip: StringName, knee: StringName, ankle: StringName, phase: float, strength: float
) -> void:
	var swing := sin(phase) * strength
	var lift := maxf(0.0, cos(phase)) * strength
	var tuck := _air_strength
	_rotate(hip, Vector3(swing * 0.49 + lift * 0.14 + 0.55 * tuck, 0, 0))
	_rotate(knee, Vector3(-lift * 0.62 - 0.9 * tuck, 0, 0))
	_rotate(ankle, Vector3(lift * 0.25 - swing * 0.21 + 0.3 * tuck, 0, 0))


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
	_step = fposmod(_step + float(moving) * WALK_SPEED * delta * _gait_rate(), TAU)
	_stride_strength = move_toward(_stride_strength, float(moving), delta * 8.0)
	# La réplica no simula física: el vuelo se deduce de la velocidad vertical del reflejo.
	if not is_nan(_last_y):
		_track_air(delta, absf(position.y - _last_y) / maxf(delta, 0.0001) > 1.0)
	_last_y = position.y
	animate_gait(delta, has_box, seated)
