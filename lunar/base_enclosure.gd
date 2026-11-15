class_name BaseEnclosure
extends Node3D

## Muro alrededor de la plataforma plana de la base, con una puerta corredera en el muro este.
## Todo sale de `open_world.base_wall` y `base_flat_rect`. La colision (capa 1) es de 2,4 m de
## alto, mas que lo que llega el salto; el hueco de la puerta nunca tiene colision. El lado sur,
## que da a la camara, se ve como un murete con cristal para no tapar la base.

const BELOW := 0.3
const GLASS := Color(0.62, 0.8, 1.0, 0.26)

## Apertura de la puerta: 0 cerrada, 1 abierta.
var openness := 0.0
var _settings: Dictionary
var _wall: Dictionary
var _flat := Rect2()
var _target := 0.0
var _leaf: MeshInstance3D
var _rects: Array[Rect2] = []


func _init(settings: Dictionary = {}) -> void:
	_settings = settings
	if not settings.is_empty():
		_wall = settings.base_wall
		_flat = flat_rect(settings)


## Centro del hueco de la puerta, a Y = 0.
static func door_at(settings: Dictionary) -> Vector3:
	var center: Array = settings.base_wall.door_center
	return Vector3(float(center[0]), 0.0, float(center[1]))


static func flat_rect(settings: Dictionary) -> Rect2:
	var values: Array = settings.base_flat_rect
	return Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))


func door_point() -> Vector3:
	return door_at(_settings)


## Punto de fuera, a unos 2 m de la puerta, por el que se sale.
func outside_point() -> Vector3:
	return door_point() + Vector3(float(_wall.outside_distance), 0.0, 0.0)


func is_open() -> bool:
	return _target > 0.5


## Huellas (XZ) de las piezas con colision del muro: el hueco de la puerta no esta.
func wall_rects() -> Array[Rect2]:
	return _rects


func build() -> void:
	var thick := float(_wall.thickness)
	var door := door_point()
	var half := float(_wall.door_width) * 0.5
	var left := _flat.position.x - thick
	var wide := _flat.size.x + thick * 2.0
	_piece(Rect2(left, _flat.position.y - thick, wide, thick), false)
	_piece(Rect2(left, _flat.end.y, wide, thick), true)
	_piece(Rect2(left, _flat.position.y, thick, _flat.size.y), false)
	var north := door.z - half - _flat.position.y
	_piece(Rect2(_flat.end.x, _flat.position.y, thick, north), false)
	var south := _flat.end.y - (door.z + half)
	_piece(Rect2(_flat.end.x, door.z + half, thick, south), false)
	_build_door(thick, half)


## Abre la puerta si algun piloto conectado esta a menos de `open_distance`.
func update_door(pilots: Array[Vector3]) -> void:
	var door := door_point()
	_target = 0.0
	for pilot in pilots:
		if Vector2(pilot.x - door.x, pilot.z - door.z).length() < float(_wall.open_distance):
			_target = 1.0


func _process(delta: float) -> void:
	if _leaf == null:
		return
	openness = move_toward(openness, _target, delta / float(_wall.door_seconds))
	_leaf.position.z = door_point().z - openness * (float(_wall.door_width) + 0.1)


func _piece(rect: Rect2, glass: bool) -> void:
	var height := float(_wall.height)
	var center := rect.get_center()
	_rects.append(rect)
	var body := StaticBody3D.new()
	body.position = Vector3(center.x, (height - BELOW) * 0.5, center.y)
	var shape := BoxShape3D.new()
	shape.size = Vector3(rect.size.x, height + BELOW, rect.size.y)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	if not glass:
		FieldWorld.box(self, body.position, shape.size, CrestWorld.FRAME.lightened(0.12))
		return
	var low := float(_wall.south_height)
	var base_size := Vector3(rect.size.x, low + BELOW, rect.size.y)
	FieldWorld.box(
		self,
		Vector3(center.x, (low - BELOW) * 0.5, center.y),
		base_size,
		CrestWorld.FRAME.lightened(0.12)
	)
	var pane := BoxMesh.new()
	pane.size = Vector3(rect.size.x, height - low, rect.size.y)
	var material := StandardMaterial3D.new()
	material.albedo_color = GLASS
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pane.material = material
	var glass_item := MeshInstance3D.new()
	glass_item.mesh = pane
	glass_item.position = Vector3(center.x, (low + height) * 0.5, center.y)
	glass_item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glass_item)


## Dintel fijo y hoja corredera por fuera del muro, que se desliza hacia el norte.
func _build_door(thick: float, half: float) -> void:
	var door := door_point()
	var height := float(_wall.height)
	FieldWorld.box(
		self,
		Vector3(door.x, height - 0.15, door.z),
		Vector3(thick, 0.3, half * 2.0),
		CrestWorld.AMBER,
		true
	)
	_leaf = FieldWorld.box(
		self,
		Vector3(_flat.end.x + thick + 0.06, (height - 0.3) * 0.5, door.z),
		Vector3(0.1, height - 0.3, half * 2.0),
		CrestWorld.DECK
	)
