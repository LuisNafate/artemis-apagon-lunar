class_name OutpostMap
extends Control

signal module_pressed(key: StringName)

const POS := {
	&"solar": Vector2(116, 208),
	&"life": Vector2(386, 109),
	&"farm": Vector2(599, 318),
	&"shelter": Vector2(387, 318)
}
const GRID := Color("#24324d")
const STEEL := Color("#bac8d6")
const DARK := Color("#222d46")
const MINT := Color("#6de7c2")
const GOLD := Color("#ffbd73")
const CYAN := Color("#85c9f8")
const RED := Color("#fb8f88")
const DISPLAY := preload("res://assets/ui/fonts/BarlowCondensed-Bold.ttf")
const MONO := preload("res://assets/ui/fonts/IBMPlexMono-Medium.ttf")

var planned: Dictionary = {}
var orders: Dictionary = {}
var _stars: PackedVector2Array
var _craters: Array[Vector3] = []
var _elapsed := 0.0


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var rng := RandomNumberGenerator.new()
	rng.seed = 98642
	for index in range(580):
		_stars.append(Vector2(rng.randi_range(4, 839), rng.randi_range(4, 417)))
	for index in range(23):
		_craters.append(
			Vector3(rng.randi_range(5, 839), rng.randi_range(4, 417), rng.randf_range(5.0, 45.0))
		)


func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for key: StringName in [&"life", &"farm", &"shelter"]:
			if Rect2(POS[key] - Vector2(72, 54), Vector2(144, 125)).has_point(event.position):
				module_pressed.emit(key)
				accept_event()
				return


func _draw() -> void:
	var field := Rect2(Vector2.ZERO, size)
	draw_rect(Rect2(Vector2.ZERO, size), Color("#111c30"))
	for point in _stars:
		draw_rect(Rect2(point, Vector2(2, 1)), GRID)
	for crater in _craters:
		var p := Vector2(crater.x, crater.y)
		if not field.grow(-crater.z).has_point(p):
			continue
		draw_circle(p, crater.z, Color("#17233a"))
		draw_arc(p, crater.z, 0.2, 2.3, 30, Color("#2d3b55"), 1.0, true)
		draw_arc(p, crater.z - 3.0, 3.3, 5.8, 30, Color("#101a2e"), 2.0, true)
	for x in range(16, 844, 24):
		draw_line(Vector2(x, 0), Vector2(x, 422), Color("#20305080"))
	for y in range(14, 422, 24):
		draw_line(Vector2(0, y), Vector2(844, y), Color("#20305080"))
	draw_rect(Rect2(Vector2.ZERO, size), Color("#364761"), false)
	if planned.is_empty():
		return

	var next: Dictionary = planned.state
	_wire(
		[Vector2(172, 208), Vector2(253, 208), Vector2(253, 109), POS.life],
		next.north,
		planned.cut == "north",
		"NORTE",
		Vector2(263, 96)
	)
	_wire(
		[Vector2(172, 208), Vector2(253, 208), Vector2(253, 318), POS.farm],
		next.south,
		planned.cut == "south",
		"SUR",
		Vector2(268, 303)
	)
	_wire(
		[POS.life, Vector2(493, 109), Vector2(493, 318)],
		next.bridge,
		false,
		"DERIVACIÓN",
		Vector2(503, 220)
	)
	_draw_event_panel(Vector2(674, 38))
	_station(&"solar", "Paneles solares", true, CYAN)
	_station(&"life", "1  Soporte vital", planned.powered.life, MINT)
	_station(&"farm", "2  Cultivo", planned.powered.farm, MINT)
	_station(&"shelter", "3  Refugio", planned.powered.shelter, GOLD)
	_draw_crew(POS.shelter + Vector2(-14, 2) if orders.inside else POS.life + Vector2(31, -9))


func _draw_event_panel(point: Vector2) -> void:
	var warning := int(planned.radiation) > 0
	var bar := Rect2(point, Vector2(144, 132))
	var tint := GOLD if warning else CYAN
	draw_rect(bar, Color("#141e31"))
	draw_rect(bar, tint, false)
	var center := point + Vector2(72, 53)
	for radius in [10.0, 21.0, 33.0]:
		draw_arc(center, radius, 0, TAU, 28, Color(tint, 0.58), 1.0, true)
	draw_line(center - Vector2(33, 0), center + Vector2(33, 0), Color(tint, 0.45))
	draw_line(center - Vector2(0, 33), center + Vector2(0, 33), Color(tint, 0.45))
	var signal_point := center + Vector2.from_angle(_elapsed * 0.68) * 31.0
	draw_line(center, signal_point, tint, 2.0, true)
	draw_string(
		MONO,
		point + Vector2(12, 111),
		"ALERTA SOLAR" if warning else "CIELO ESTABLE",
		HORIZONTAL_ALIGNMENT_CENTER,
		120,
		11,
		tint
	)


func _wire(
	points: PackedVector2Array, live: bool, danger: bool, label: String, at: Vector2
) -> void:
	var color := RED if danger and not live else (CYAN if live else Color("#536483"))
	draw_polyline(points, Color("#0a1224"), 10, true)
	draw_polyline(points, color, 3, true)
	draw_string(MONO, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, color)
	if live:
		for index in range(points.size() - 1):
			var from := points[index]
			var to := points[index + 1]
			var progression := fposmod(_elapsed * 0.8 + 0.28 * index, 1.0)
			draw_circle(from.lerp(to, progression), 3.0, Color("#def3fe"))


func _station(key: StringName, name_text: String, online: bool, tint: Color) -> void:
	var p: Vector2 = POS[key]
	var box := Rect2(p - Vector2(63, 49), Vector2(126, 95))
	var edge := tint if online else Color("#617493")
	draw_rect(Rect2(box.position + Vector2(7, 8), box.size), Color("#090f20"))
	draw_rect(box, DARK)
	draw_rect(box, edge, false, 2)
	draw_rect(Rect2(box.position, Vector2(126, 4)), edge)
	match key:
		&"solar":
			_draw_solar(p)
		&"life":
			_draw_life(p)
		&"farm":
			_draw_farm(p, online)
		_:
			_draw_shelter(p)
	var state := "EN LÍNEA" if online else ("EN ESPERA" if orders[key] else "APAGADO")
	var cost := {"life": "3", "farm": "2", "shelter": "1"}
	if cost.has(key):
		state += " · %s E" % cost[key]
	draw_string(
		DISPLAY,
		p - Vector2(60, -67),
		name_text,
		HORIZONTAL_ALIGNMENT_CENTER,
		120,
		19,
		Color("#eef2ef")
	)
	draw_string(MONO, p - Vector2(60, -84), state, HORIZONTAL_ALIGNMENT_CENTER, 120, 10, edge)


func _draw_solar(p: Vector2) -> void:
	for column in range(4):
		for row in range(3):
			var box := Rect2(p + Vector2(-48 + column * 24, -30 + row * 17), Vector2(22, 15))
			draw_rect(box, Color("#356395") if (column + row) % 2 else Color("#416f9d"))
			draw_rect(box, CYAN, false)
			draw_line(box.position + Vector2(5, 3), box.position + Vector2(18, 3), CYAN)
	draw_rect(Rect2(p + Vector2(-22, 26), Vector2(44, 10)), STEEL)


func _draw_life(p: Vector2) -> void:
	for index in range(3):
		var box := Rect2(p + Vector2(-47 + 32 * index, -29), Vector2(27, 46))
		draw_rect(box, STEEL)
		draw_rect(Rect2(box.position + Vector2(4, 7), Vector2(19, 26)), Color("#293e57"))
		for level in range(3):
			draw_line(
				box.position + Vector2(8, 13 + level * 7),
				box.position + Vector2(18, 13 + level * 7),
				MINT,
				2
			)
	draw_line(p + Vector2(-36, 17), p + Vector2(-36, 29), GOLD, 3)
	draw_line(p + Vector2(-36, 29), p + Vector2(41, 29), GOLD, 3)


func _draw_farm(p: Vector2, online: bool) -> void:
	for row in range(2):
		var box := Rect2(p + Vector2(-51, -30 + row * 32), Vector2(103, 25))
		draw_rect(box, Color("#6f929a"))
		draw_rect(box.grow(-3), Color("#2f5e56"))
		for plant in range(7):
			var center := box.position + Vector2(11 + 13 * plant, 13)
			var leaf := MINT if online else Color("#639087")
			draw_circle(center, 5, leaf)
			draw_line(center - Vector2(4, 5), center + Vector2(3, 5), Color("#b2e3ab"), 1)


func _draw_shelter(p: Vector2) -> void:
	draw_rect(Rect2(p - Vector2(41, 31), Vector2(82, 62)), Color("#637186"))
	draw_rect(
		Rect2(p - Vector2(32, 22), Vector2(64, 44)),
		Color("#57473b") if orders.inside else Color("#343d52")
	)
	for index in range(10):
		draw_rect(Rect2(p + Vector2(-42 + index * 8, -31), Vector2(4, 6)), GOLD)
	draw_rect(Rect2(p + Vector2(-12, 20), Vector2(24, 12)), Color("#212b44"))


func _draw_crew(p: Vector2) -> void:
	for index in range(2):
		var person := p + Vector2(index * 23, index * 5)
		draw_circle(person + Vector2(2, 8), 10, Color("#0a1428"))
		draw_rect(Rect2(person - Vector2(6, 2), Vector2(12, 16)), STEEL)
		draw_circle(person - Vector2(0, 5), 8, Color("#fcf3d8"))
		draw_rect(Rect2(person - Vector2(5, 7), Vector2(11, 6)), Color("#435e87"))
