class_name RoverBody
extends CharacterBody3D

## El rover como cuerpo cinematico: un cilindro vertical que desliza por el relieve (capa 1)
## y un modelo que se orienta y se inclina con el terreno. El cilindro no gira, asi el giro del
## modelo nunca lo mete en un muro; con un radio de 1 m cabe por la puerta de 3 m.

const MODEL := preload("res://assets/props_luna/estaciones/antena_rover.glb")
const LAYER := 1

var yaw := 0.0
var _spec: Dictionary = RoverSpec.data
var _pivot := Node3D.new()
var _tag := Label3D.new()
var _up := Vector3.UP
var _tray := Node3D.new()
var _tray_kinds: Array = []


func _init() -> void:
	name = "RoverBody"
	collision_layer = LAYER
	collision_mask = LAYER
	floor_snap_length = 1.0
	var shape := CylinderShape3D.new()
	shape.radius = float(_spec.collision_radius)
	shape.height = float(_spec.collision_height)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = shape.height * 0.5
	add_child(collider)
	add_child(_pivot)
	var model: Node3D = MODEL.instantiate()
	PaperMaterial.restyle(model, false)
	var size := float(_spec.model_scale)
	model.scale = Vector3.ONE * size
	model.position.y = float(_spec.model_half_height) * size
	_pivot.add_child(model)
	_tag.font = CrestWorld.MONO
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.position = Vector3.UP * 2.3
	_tag.no_depth_test = true
	_tag.pixel_size = 0.019
	_tag.outline_size = 12
	_tag.hide()
	add_child(_tag)
	add_child(_tray)


## Direccion de proa (plano XZ) para un giro dado: con giro 0 el rover mira al norte (-Z).
static func heading_of(angle: float) -> Vector2:
	return Vector2(-sin(angle), -cos(angle))


## Coloca el rover sin movimiento (carga de partida, aparcado, regreso al amanecer).
func place(point: Vector3, angle: float) -> void:
	position = point
	yaw = angle
	velocity = Vector3.ZERO
	_apply_pose(1.0, null)


## `heading` es la direccion deseada (plano XZ, largo 0..1) relativa a la camara ya resuelta.
func drive(delta: float, heading: Vector2, terrain: ChunkStreamer) -> void:
	var speed := float(_spec.speed)
	var desired := Vector3(heading.x, 0.0, heading.y) * speed
	var acceleration := float(_spec.acceleration)
	velocity.x = move_toward(velocity.x, desired.x, delta * acceleration)
	velocity.z = move_toward(velocity.z, desired.z, delta * acceleration)
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= float(_spec.gravity) * delta
	if heading.length_squared() > 0.012:
		var wanted := atan2(-heading.x, -heading.y)
		yaw = lerp_angle(yaw, wanted, minf(1.0, delta * float(_spec.turn_rate)))
	move_and_slide()
	_apply_pose(delta, terrain)


## Sin conductor: se queda quieto sobre el suelo.
func hold(delta: float, terrain: ChunkStreamer) -> void:
	velocity = Vector3.ZERO
	_apply_pose(delta, terrain)


## Copia de un cliente: sigue la posicion que manda el anfitrion.
func follow(delta: float, point: Vector3, angle: float, terrain: ChunkStreamer) -> void:
	var gap := position.distance_squared_to(point)
	var rate := minf(delta * float(_spec.replica_rate), 1.0)
	position = point if gap > 16.0 else position.lerp(point, rate)
	yaw = lerp_angle(yaw, angle, rate)
	_apply_pose(delta, terrain)


## Cajas de la bandeja trasera; solo se reconstruyen si cambia la lista.
func show_tray(kinds: Array, host: Node, templates: Dictionary) -> void:
	if kinds == _tray_kinds:
		return
	_tray_kinds = kinds.duplicate()
	for child in _tray.get_children():
		child.queue_free()
	var anchor: Array = _spec.tray_anchor
	var spacing := float(_spec.tray_spacing)
	for index in range(kinds.size()):
		var box := Node3D.new()
		LunarCargoVisual.build(host, templates, box, StringName(kinds[index]))
		var slot := (float(index) - (kinds.size() - 1) * 0.5) * spacing
		box.position = Vector3(float(anchor[0]) + slot, float(anchor[1]), float(anchor[2]))
		_tray.add_child(box)


func show_driver(tag: String, tint: Color) -> void:
	_tag.visible = not tag.is_empty()
	_tag.text = tag
	_tag.modulate = tint


## Giro y cabeceo del modelo: la normal se saca de la altura del terreno bajo la proa, la popa
## y los costados, porque el cuerpo de colision no se inclina.
func _apply_pose(delta: float, terrain: ChunkStreamer) -> void:
	var normal := Vector3.UP
	if terrain != null and terrain.is_ready_at(position):
		normal = _normal_at(terrain)
	var rate := 1.0 if terrain == null else minf(1.0, delta * float(_spec.tilt_rate))
	_up = _up.slerp(normal, rate).normalized()
	var turn := yaw + deg_to_rad(float(_spec.model_yaw_degrees))
	_pivot.basis = Basis(Quaternion(Vector3.UP, _up)) * Basis(Vector3.UP, turn)
	_tray.basis = Basis(Quaternion(Vector3.UP, _up)) * Basis(Vector3.UP, yaw)


func _normal_at(terrain: ChunkStreamer) -> Vector3:
	var reach := float(_spec.tilt_sample)
	var ahead := heading_of(yaw) * reach
	var side := Vector2(-ahead.y, ahead.x)
	var samples := [
		position + Vector3(ahead.x, 0.0, ahead.y),
		position - Vector3(ahead.x, 0.0, ahead.y),
		position + Vector3(side.x, 0.0, side.y),
		position - Vector3(side.x, 0.0, side.y)
	]
	var heights: Array[float] = []
	for point: Vector3 in samples:
		var height := terrain.height_at(point)
		if height == -INF:
			return Vector3.UP
		heights.append(height)
	var forward := Vector3(ahead.x, heights[0] - heights[1], ahead.y)
	var right := Vector3(side.x, heights[2] - heights[3], side.y)
	var normal := right.cross(forward).normalized()
	return normal if normal.y > 0.0 else -normal
