class_name ConstructionBay
extends RefCounted

const ZONE := Rect2i(0, 9, 9, 3)
const CONNECTORS := Rect2i(0, 8, 8, 1)
const DIRECTIONS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

var materials := 0
var completed_modules := 0
var garden_boost := 0
var catalog: Dictionary = {}
var pieces: Array[Dictionary] = []
var _occupied: Dictionary = {}


func setup(config: Dictionary) -> void:
	catalog = config.catalog
	materials = int(config.materials)


func footprint(kind: StringName, origin: Vector2i) -> Rect2i:
	var side := int(catalog[kind].size)
	return Rect2i(origin, Vector2i(side, side))


func can_walk(cell: Vector2i) -> bool:
	return _occupied.get(cell, &"") == &"walkway"


func placement_status(kind: StringName, origin: Vector2i) -> String:
	if not catalog.has(kind):
		return "Elige una pieza del catálogo."
	var area := footprint(kind, origin)
	if not ZONE.encloses(area):
		return "Coloca la pieza dentro del sector de ampliación."
	for x in range(area.position.x, area.end.x):
		for y in range(area.position.y, area.end.y):
			if _occupied.has(Vector2i(x, y)):
				return "Hay una pieza en esa huella."
	if not _has_connection(area, kind == &"walkway"):
		return "Conecta la pieza a una pasarela."
	if materials < int(catalog[kind].cost):
		return "Faltan materiales."
	return ""


func place(kind: StringName, origin: Vector2i, minute: int) -> void:
	var plan: Dictionary = catalog[kind]
	var area := footprint(kind, origin)
	materials -= int(plan.cost)
	for x in range(area.position.x, area.end.x):
		for y in range(area.position.y, area.end.y):
			_occupied[Vector2i(x, y)] = kind
	pieces.append(
		{
			"kind": kind,
			"area": area,
			"ready_minute": minute + int(plan.minutes),
			"complete": kind == &"walkway"
		}
	)


func finish_ready(minute: int) -> Array[StringName]:
	var finished: Array[StringName] = []
	for piece in pieces:
		if piece.complete or int(piece.ready_minute) > minute:
			continue
		piece.complete = true
		completed_modules += 1
		var kind: StringName = piece.kind
		var bonus := float(catalog[kind].bonus)
		match kind:
			&"habitat":
				ResourceManager.increase_capacity(&"o2", bonus)
			&"battery":
				ResourceManager.increase_capacity(&"energy", bonus)
			&"greenhouse":
				garden_boost += int(bonus)
		finished.append(kind)
	return finished


func _has_connection(area: Rect2i, walkway: bool) -> bool:
	for x in range(area.position.x, area.end.x):
		for y in range(area.position.y, area.end.y):
			for direction: Vector2i in DIRECTIONS:
				var neighbor := Vector2i(x, y) + direction
				if can_walk(neighbor) or (walkway and CONNECTORS.has_point(neighbor)):
					return true
	return false
