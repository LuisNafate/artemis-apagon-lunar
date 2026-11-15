class_name FieldPilot
extends CharacterBody3D

const WALK_SPEED := 6.8
const DASH_SPEED := 16.0
const JUMP_SPEED := 6.4

var rig: Node3D
var feet: Array[Node3D] = []
var carrying: Node3D
var direction := Vector3.FORWARD
var dash_left := 0.0
var dash_cooldown := 0.0
var _stride := 0.0


func build() -> void:
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.55
	capsule.radius = 0.32
	var collider := CollisionShape3D.new()
	collider.shape = capsule
	collider.position.y = 0.775
	add_child(collider)
	floor_snap_length = 0.18
	rig = Node3D.new()
	add_child(rig)
	carrying = Node3D.new()
	carrying.position = Vector3(0.43, 0.69, -0.36)
	rig.add_child(carrying)
	carrying.hide()
	_build_visuals()


func _build_visuals() -> void:
	var shell := Color("#e5eaff")
	var dark := Color("#232e4b")
	var gold := Color("#ffaa56")
	FieldWorld.box(rig, Vector3(0, 0.82, 0), Vector3(0.59, 0.62, 0.39), shell)
	FieldWorld.box(rig, Vector3(0, 0.94, 0.28), Vector3(0.46, 0.63, 0.32), dark)
	FieldWorld.box(rig, Vector3(0, 1.00, 0.45), Vector3(0.28, 0.09, 0.04), gold, true)
	FieldWorld.ball(rig, Vector3(0, 1.33, -0.01), Vector3(0.68, 0.63, 0.65), shell)
	FieldWorld.ball(rig, Vector3(0, 1.35, -0.27), Vector3(0.53, 0.38, 0.28), Color("#385d91"))
	FieldWorld.box(
		rig, Vector3(0.08, 1.43, -0.40), Vector3(0.17, 0.04, 0.025), Color("#93d8ee"), true
	)
	for side in [-1.0, 1.0]:
		FieldWorld.box(rig, Vector3(side * 0.37, 0.76, 0.0), Vector3(0.18, 0.54, 0.22), shell)
		FieldWorld.box(rig, Vector3(side * 0.37, 0.61, -0.03), Vector3(0.19, 0.14, 0.22), gold)
		var leg := Node3D.new()
		leg.position = Vector3(side * 0.16, 0.5, 0.0)
		rig.add_child(leg)
		feet.append(leg)
		FieldWorld.box(leg, Vector3(0, -0.16, 0), Vector3(0.23, 0.37, 0.24), shell)
		FieldWorld.box(leg, Vector3(0, -0.36, -0.055), Vector3(0.24, 0.17, 0.35), dark)
	FieldWorld.box(carrying, Vector3.ZERO, Vector3(0.44, 0.44, 0.44), gold, true)


func drive(delta: float, axis: Vector2, jump: bool, dash: bool) -> void:
	var heading := Vector3(axis.x, 0, axis.y)
	var has_input := heading.length_squared() > 0.01
	if has_input:
		direction = heading.normalized()
	if dash and dash_cooldown <= 0.0:
		dash_left = 0.26
		dash_cooldown = 1.25
	if is_on_floor():
		if jump:
			velocity.y = JUMP_SPEED
	else:
		velocity.y -= 16.0 * delta
	var desired := heading * WALK_SPEED
	if dash_left > 0.0:
		desired = direction * DASH_SPEED
		velocity.x = desired.x
		velocity.z = desired.z
	else:
		var acceleration := 35.0 if is_on_floor() else 13.0
		velocity.x = move_toward(velocity.x, desired.x, delta * acceleration)
		velocity.z = move_toward(velocity.z, desired.z, delta * acceleration)
	dash_left = maxf(0.0, dash_left - delta)
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	move_and_slide()
	rig.rotation.y = lerp_angle(rig.rotation.y, atan2(-direction.x, -direction.z), delta * 13.0)
	var swing := 0.45 if is_on_floor() and has_input else 0.0
	_stride += delta * 15.0
	for index in range(feet.size()):
		feet[index].rotation.x = sin(_stride + PI * index) * swing
