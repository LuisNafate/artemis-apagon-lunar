class_name LunarMap
extends Node2D

const LANDSCAPE := preload("res://assets/tilemaps/lunar_horizon.png")
const DECK := preload("res://assets/tilemaps/deck.png")
const CRATES := preload("res://assets/sprites_25d/crates.png")
const LIFE := preload("res://assets/sprites_25d/life.png")
const GARDEN := preload("res://assets/sprites_25d/garden.png")
const SOLAR := preload("res://assets/sprites_25d/solar.png")
const AIRLOCK := preload("res://assets/sprites_25d/airlock.png")
const BEACON := preload("res://assets/sprites_25d/beacon.png")
const BATTERY := preload("res://assets/sprites_25d/battery.png")
const MODULE_ART := {&"habitat": LIFE, &"greenhouse": GARDEN, &"battery": BATTERY}
const MONO := preload("res://assets/ui/fonts/IBMPlexMono-Medium.ttf")

const BOARD := Rect2i(0, 0, 9, 9)
const DOCK := Rect2i(9, 0, 3, 4)
const OUTSIDE := Rect2i(9, 4, 4, 4)
const SPAWN := Vector2i(4, 4)
const EXIT_CELL := Vector2i(9, 6)
const ENTRY_CELL := Vector2i(8, 6)
const DIRECTIONS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
const CRATE_CELLS := [Vector2i(0, 0), Vector2i(8, 0), Vector2i(8, 8)]

var stations: Array[Station] = []
var astronaut: AstronautController
var hover := Vector2i(-100, -100)
var outside := false
var blueprint: StringName = &""
var preview_error := ""
var visitors: CrewVisuals
var dock_open := false
var _modules: Dictionary = {}
var _depth: Node2D


func _ready() -> void:
	_depth = Node2D.new()
	_depth.name = "Depth"
	_depth.y_sort_enabled = true
	add_child(_depth)
	_add_station(&"life", "SOPORTE VITAL", Rect2i(2, 1, 2, 2), LIFE, -48)
	_add_station(&"garden", "CULTIVO", Rect2i(1, 5, 2, 2), GARDEN, -46)
	_add_station(&"solar", "SOLAR", Rect2i(6, 1, 2, 2), SOLAR, -46)
	_add_station(&"airlock", "ESCLUSA", Rect2i(6, 5, 2, 2), AIRLOCK, -45)
	_add_station(&"beacon", "BALIZA", Rect2i(11, 5, 1, 1), BEACON, -47)
	for cell: Vector2i in CRATE_CELLS:
		_add_crates(cell)
	astronaut = AstronautController.new()
	astronaut.name = "Astronaut"
	_depth.add_child(astronaut)
	astronaut.place(SPAWN)
	visitors = CrewVisuals.new()
	visitors.name = "CrewVisuals"
	add_child(visitors)
	visitors.setup(self, _depth)


func refresh_reception(show_dock: bool, training_complete: bool) -> void:
	dock_open = show_dock
	var dock: Station
	for station in stations:
		if station.key == &"reception":
			dock = station
			break
	if show_dock and dock == null:
		_add_station(&"reception", "RECEPCIÓN", Rect2i(11, 0, 1, 1), CRATES, -35)
	elif not show_dock and dock != null:
		stations.erase(dock)
		dock.queue_free()
	visitors.synchronize(AdversarialDirector.reception.waves, training_complete)


static func project(cell: Vector2) -> Vector2:
	return Vector2(16.0 * (cell.x - cell.y), 8.0 * (cell.x + cell.y))


func ground_cell(point: Vector2) -> Vector2i:
	return Vector2i(
		roundi(point.x / 32.0 + point.y / 16.0), roundi(point.y / 16.0 - point.x / 32.0)
	)


func can_walk(cell: Vector2i, base_only: bool = false) -> bool:
	var external := outside and not base_only
	var area := OUTSIDE if external else BOARD
	var dock_tile := dock_open and DOCK.has_point(cell)
	var expansion := not external and (dock_tile or AdversarialDirector.construction.can_walk(cell))
	if (not area.has_point(cell) and not expansion) or cell in CRATE_CELLS:
		return false
	for station in stations:
		if station.footprint.has_point(cell):
			return false
	return true


func station_at(point: Vector2) -> Station:
	var picked: Station
	for station in stations:
		var label := Rect2(
			station.position + Vector2(-38, station.label_offset - 14), Vector2(76, 25)
		)
		if label.has_point(point) or station.contains_art(to_global(point)):
			if picked == null or station.position.y >= picked.position.y:
				picked = station
	return picked


func in_reach(station: Station, cell: Vector2i) -> bool:
	if station.key == &"airlock":
		return cell == (EXIT_CELL if outside else ENTRY_CELL)
	if not can_walk(cell):
		return false
	for direction: Vector2i in DIRECTIONS:
		if station.footprint.has_point(cell + direction):
			return true
	return false


func route(
	from: Vector2i, target: Vector2i, station: Station = null, base_only: bool = false
) -> Array[Vector2i]:
	var queue: Array[Vector2i] = [from]
	var parents: Dictionary = {from: from}
	var index := 0
	while index < queue.size():
		var cell := queue[index]
		index += 1
		if (station == null and cell == target) or (station != null and in_reach(station, cell)):
			var path: Array[Vector2i] = []
			while cell != from:
				path.push_front(cell)
				cell = parents[cell]
			return path
		for direction: Vector2i in DIRECTIONS:
			var next := cell + direction
			if can_walk(next, base_only) and not parents.has(next):
				parents[next] = cell
				queue.push_back(next)
	return []


func berth_entrance(origin: Vector2i) -> Vector2i:
	var footprint := AdversarialDirector.construction.footprint(&"habitat", origin)
	for x in range(footprint.position.x, footprint.end.x):
		for y in range(footprint.position.y, footprint.end.y):
			for direction: Vector2i in DIRECTIONS:
				var cell := Vector2i(x, y) + direction
				if AdversarialDirector.construction.can_walk(cell):
					return cell
	return origin


func refresh_construction() -> void:
	var bay := AdversarialDirector.construction
	var installed := {}
	for piece in bay.pieces:
		if piece.kind == &"walkway" or not piece.complete:
			continue
		var origin: Vector2i = piece.area.position
		installed[origin] = true
		if _modules.has(origin):
			continue
		var sprite := Sprite2D.new()
		sprite.texture = MODULE_ART[piece.kind]
		sprite.offset = Vector2(0, -7)
		sprite.position = _footprint_center(piece.area)
		_depth.add_child(sprite)
		_modules[origin] = sprite
	for origin: Vector2i in _modules.keys():
		if not installed.has(origin):
			_modules[origin].free()
			_modules.erase(origin)
	queue_redraw()


func _footprint_center(area: Rect2i) -> Vector2:
	return project(Vector2(area.position) + (Vector2(area.size) - Vector2.ONE) * 0.5)


func _outline(area: Rect2i) -> PackedVector2Array:
	var start := Vector2(area.position) - Vector2(0.5, 0.5)
	var end := Vector2(area.end) - Vector2(0.5, 0.5)
	return PackedVector2Array(
		[
			project(start),
			project(Vector2(end.x, start.y)),
			project(end),
			project(Vector2(start.x, end.y)),
			project(start)
		]
	)


func _paint_construction() -> void:
	var bay := AdversarialDirector.construction
	if blueprint != &"":
		for x in range(ConstructionBay.ZONE.position.x, ConstructionBay.ZONE.end.x):
			for y in range(ConstructionBay.ZONE.position.y, ConstructionBay.ZONE.end.y):
				draw_polyline(_outline(Rect2i(x, y, 1, 1)), Color("#8096b27d"), 1)
		draw_polyline(_outline(ConstructionBay.ZONE), Color("#86b5ce"), 1)
		for x in range(ConstructionBay.CONNECTORS.position.x, ConstructionBay.CONNECTORS.end.x):
			var point := project(Vector2(x, ConstructionBay.CONNECTORS.position.y)) + Vector2(-8, 4)
			draw_line(point - Vector2(4, 2), point + Vector2(4, 2), Color("#9be8d5"), 1)
	for piece in bay.pieces:
		var area: Rect2i = piece.area
		if piece.kind == &"walkway":
			var target := Rect2(project(area.position) - Vector2(16, 8), Vector2(32, 20))
			draw_texture_rect_region(DECK, target, Rect2(96, 0, 32, 20))
			draw_polyline(_outline(area), Color("#91b4c9"), 1)
		elif not piece.complete:
			var border := _outline(area)
			draw_colored_polygon(border.slice(0, 4), Color("#d994563f"))
			draw_polyline(border, Color("#e0ae6b"), 1)


func _add_station(
	key: StringName, title: String, rect: Rect2i, art: Texture2D, label_y: float
) -> void:
	var station := Station.new()
	station.name = title.replace(" ", "_")
	station.key = key
	station.title = title
	station.footprint = rect
	station.label_offset = label_y
	station.position = project(Vector2(rect.position) + (Vector2(rect.size) - Vector2.ONE) * 0.5)
	_depth.add_child(station)
	station.setup(art)
	stations.append(station)


func _add_crates(cell: Vector2i) -> void:
	var prop := Node2D.new()
	var sprite := Sprite2D.new()
	prop.position = project(cell)
	sprite.position = Vector2(0, -7)
	sprite.texture = CRATES
	_depth.add_child(prop)
	prop.add_child(sprite)


func _draw() -> void:
	draw_texture(LANDSCAPE, Vector2(-240, -139))
	for diagonal in range(17):
		for x in range(9):
			var cell := Vector2i(x, diagonal - x)
			if not BOARD.has_point(cell):
				continue
			var point := project(cell)
			var variant := (cell.x * 5 + cell.y * 3) % 3
			if cell.x == 4 or cell.y == 4:
				variant = 3
			draw_texture_rect_region(
				DECK, Rect2(point - Vector2(16, 8), Vector2(32, 20)), Rect2(variant * 32, 0, 32, 20)
			)
			if (cell.x in [0, 8] and cell.y % 2 == 0) or (cell.y in [0, 8] and cell.x % 2 == 0):
				draw_rect(Rect2(point - Vector2(1, 1), Vector2(3, 2)), Color("#efba7c"))
	for x in range(8, 13):
		var p := project(Vector2(x, 6))
		draw_line(p - Vector2(3, 1), p + Vector2(3, 2), Color("#efbd7f"), 2)
	if dock_open:
		_paint_dock()
	_paint_construction()
	if outside:
		var near_edge := Vector2(OUTSIDE.position) - Vector2(0.5, 0.5)
		var far_edge := Vector2(OUTSIDE.end) - Vector2(0.5, 0.5)
		var zone := PackedVector2Array(
			[
				project(near_edge),
				project(Vector2(far_edge.x, near_edge.y)),
				project(far_edge),
				project(Vector2(near_edge.x, far_edge.y)),
				project(near_edge)
			]
		)
		draw_polyline(zone, Color("#936b57"), 1)
	if blueprint == &"" and can_walk(hover):
		var p := project(hover)
		draw_polyline(
			PackedVector2Array(
				[
					p + Vector2(-15, 0),
					p + Vector2(0, -7),
					p + Vector2(15, 0),
					p + Vector2(0, 7),
					p + Vector2(-15, 0)
				]
			),
			Color("#eed49d"),
			1
		)
	for cell in astronaut.path:
		draw_rect(Rect2(project(cell) - Vector2.ONE, Vector2(3, 2)), Color("#ecd1a2"))


func _paint_dock() -> void:
	for x in range(DOCK.position.x, DOCK.end.x):
		for y in range(DOCK.position.y, DOCK.end.y):
			var point := project(Vector2(x, y))
			var target := Rect2(point - Vector2(16, 8), Vector2(32, 20))
			draw_texture_rect_region(DECK, target, Rect2(96 if y == 2 else 32, 0, 32, 20))
			if x == DOCK.end.x - 1:
				draw_rect(Rect2(point - Vector2(1, 1), Vector2(3, 2)), Color("#9be8d5"))
	draw_polyline(_outline(DOCK), Color("#8cabc3"), 1)


func paint_labels(canvas: Node2D) -> void:
	for station in stations:
		var pos := station.position + Vector2(0, station.label_offset)
		var size := MONO.get_string_size(station.title, HORIZONTAL_ALIGNMENT_LEFT, -1, 8)
		var sub_size := MONO.get_string_size(station.status, HORIZONTAL_ALIGNMENT_LEFT, -1, 7)
		var width := maxf(size.x, sub_size.x) + 8
		var rect := Rect2(pos - Vector2(width / 2.0, 12), Vector2(width, 25))
		canvas.draw_rect(rect, Color("#1a2337"))
		canvas.draw_rect(
			rect,
			station.accent if station.highlighted or station.selected else Color("#536078"),
			false,
			1.0
		)
		canvas.draw_string(
			MONO,
			pos - Vector2(size.x / 2.0, 1),
			station.title,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			8,
			Color("#f4e1ca")
		)
		var sub_pos := pos + Vector2(0, 11)
		canvas.draw_string(
			MONO,
			sub_pos - Vector2(sub_size.x / 2.0, 0),
			station.status,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			7,
			station.accent
		)
	_paint_build_labels(canvas)


func _paint_build_labels(canvas: Node2D) -> void:
	var bay := AdversarialDirector.construction
	for piece in bay.pieces:
		if piece.kind == &"walkway" or piece.complete:
			continue
		var center := _footprint_center(piece.area)
		var left := int(piece.ready_minute) - AdversarialDirector.minute
		var text := "EN OBRA · %d MIN" % left
		canvas.draw_rect(Rect2(center - Vector2(35, 9), Vector2(70, 14)), Color("#17263b"))
		canvas.draw_string(
			MONO, center - Vector2(31, -1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("#efbd7f")
		)
	if blueprint == &"" or not ConstructionBay.ZONE.has_point(hover):
		return
	var area := bay.footprint(blueprint, hover)
	var outline := _outline(area)
	var color := Color("#9be8d5") if preview_error.is_empty() else Color("#ff9c8d")
	canvas.draw_colored_polygon(outline.slice(0, 4), Color(color, 0.26))
	canvas.draw_polyline(outline, color, 1)
	if blueprint != &"walkway" and preview_error.is_empty():
		var sprite: Texture2D = MODULE_ART[blueprint]
		var offset := sprite.get_size() * 0.5 + Vector2(0, 7)
		canvas.draw_texture(sprite, _footprint_center(area) - offset, Color(1, 1, 1, 0.55))
