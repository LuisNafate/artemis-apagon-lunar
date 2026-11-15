class_name LunarGlobe
extends Control

signal picked(action: String, argument: String)

const MOON := preload("res://assets/props_luna/luna_bases.glb")
const HABITAT := preload("res://assets/props_luna/nasa/apollo_base_lunar.glb")
const PROBE := preload("res://assets/props_luna/nasa/lro_miniatura.glb")
const DISH := preload("res://assets/props_luna/kenney/antena.glb")
const DESK := preload("res://assets/props_luna/kenney/consola.glb")
const TRUCK := preload("res://assets/props_luna/kenney/transporte.glb")
const TITLE := preload("res://assets/ui/fonts/BarlowCondensed-Bold.ttf")
const MONO := preload("res://assets/ui/fonts/IBMPlexMono-Medium.ttf")
const SPACE := Color("#040408")
const CARD := Color("#131317")
const RIM := Color("#d4cdbd")
const TEXT := Color("#f3ecdc")
const DIM := Color("#b9b2a2")
const ROUTE := Color("#5fd6c4")
const COIN := Color("#e8b84a")
const OPEN := Color("#5fd6c4")
const SPIN := 0.09
const REST := 2.4

var _entries: Array[Dictionary] = []
var _cards := {}
var _sockets := {}
var _order: Array[String] = []
var _stars := PackedVector3Array()
var _pivot: Node3D
var _camera: Camera3D
var _ink: Control
var _mode: Label
var _coins: Label
var _dragging := false
var _idle := REST
var _tilt := 0.0
var _passive := false
var _chrome: Array[Control] = []
var _notice: Label
var _notice_left := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var rng := RandomNumberGenerator.new()
	rng.seed = 2116
	for index in range(460):
		_stars.append(Vector3(rng.randf(), rng.randf(), rng.randf()))
	var frame := SubViewportContainer.new()
	frame.stretch = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var view := SubViewport.new()
	view.own_world_3d = true
	view.transparent_bg = true
	view.msaa_3d = Viewport.MSAA_4X
	frame.add_child(view)
	_build_space(view)
	_ink = Control.new()
	_ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ink)
	_ink.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ink.draw.connect(_draw_ink)
	_build_footer()
	resized.connect(queue_redraw)


func _build_space(view: SubViewport) -> void:
	var air := WorldEnvironment.new()
	air.environment = Environment.new()
	air.environment.background_mode = Environment.BG_CLEAR_COLOR
	air.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	air.environment.ambient_light_color = Color("#8d8c86")
	air.environment.ambient_light_energy = 0.16
	view.add_child(air)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-24.0, -38.0, 0.0)
	sun.light_energy = 1.7
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 5.0
	sun.shadow_bias = 0.02
	sun.shadow_normal_bias = 1.2
	view.add_child(sun)
	_camera = Camera3D.new()
	_camera.position = Vector3(0.0, 0.0, 2.62)
	_camera.fov = 30.0
	view.add_child(_camera)
	_pivot = Node3D.new()
	view.add_child(_pivot)
	var moon: Node3D = MOON.instantiate()
	_pivot.add_child(moon)
	var paint := StandardMaterial3D.new()
	paint.vertex_color_use_as_albedo = true
	paint.roughness = 1.0
	for item: Node in moon.find_children("*", "", true, false):
		if item is MeshInstance3D:
			item.material_override = paint
		elif String(item.name).begins_with("socket_"):
			_sockets[String(item.name).trim_prefix("socket_")] = item
	var kits := [
		[
			[DESK, 0.074, Vector3.ZERO],
			[DISH, 0.05, Vector3(0.062, 0, 0.012)],
			[TRUCK, 0.058, Vector3(-0.06, 0, 0.03)]
		],
		[[HABITAT, 0.098, Vector3.ZERO], [DISH, 0.046, Vector3(0.07, 0, -0.02)]],
		[
			[TRUCK, 0.082, Vector3.ZERO],
			[DESK, 0.05, Vector3(0.066, 0, 0.02)],
			[PROBE, 0.044, Vector3(-0.058, 0.012, -0.03)]
		]
	]
	var turn := 0
	for id: String in _sockets:
		var socket: Node3D = _sockets[id]
		var up := socket.position.normalized()
		var side := Vector3.UP.cross(up)
		if side.length() < 0.05:
			side = Vector3.RIGHT
		side = side.normalized()
		var site := Node3D.new()
		site.basis = Basis(side, up, side.cross(up))
		socket.add_child(site)
		for part: Array in kits[turn % kits.size()]:
			var piece := _fit(part[0], part[1])
			piece.position = part[2] - Vector3(0, 0.004, 0)
			site.add_child(piece)
		turn += 1


func _fit(scene: PackedScene, span: float) -> Node3D:
	var holder := Node3D.new()
	var model: Node3D = scene.instantiate()
	holder.add_child(model)
	var bounds := AABB()
	var first := true
	for item: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := item as MeshInstance3D
		var place := Transform3D.IDENTITY
		var step: Node = mesh_node
		while step != model:
			place = (step as Node3D).transform * place
			step = step.get_parent()
		var box := place * mesh_node.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	var longest := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	if longest <= 0.0:
		return holder
	var ratio := span / longest
	var center := bounds.get_center()
	model.scale = Vector3.ONE * ratio
	model.position = -Vector3(center.x, bounds.position.y, center.z) * ratio
	return holder


func _build_footer() -> void:
	var back := Button.new()
	back.text = "VOLVER"
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_override("font", MONO)
	back.add_theme_font_size_override("font_size", 22)
	back.add_theme_color_override("font_color", TEXT)
	back.add_theme_stylebox_override("normal", _plate(Color("#3a2c26"), Color("#8f6f58")))
	back.add_theme_stylebox_override("hover", _plate(Color("#4d3a31"), RIM))
	back.add_theme_stylebox_override("pressed", _plate(Color("#2c211c"), RIM))
	add_child(back)
	back.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	back.offset_left = 30
	back.offset_right = 196
	back.offset_top = -74
	back.offset_bottom = -26
	back.pressed.connect(func() -> void: picked.emit("lobby", ""))
	var purse := _coin(30.0)
	add_child(purse)
	purse.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	purse.offset_left = 220
	purse.offset_right = 250
	purse.offset_top = -65
	purse.offset_bottom = -35
	_coins = _caption(Vector2(262, -64), 21, TEXT)
	_coins.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_coins.offset_left = 262
	_coins.offset_top = -64
	_mode = _caption(Vector2(32, 22), 30, DIM)
	_mode.add_theme_font_override("font", TITLE)
	_notice = _caption(Vector2.ZERO, 20, TEXT)
	_notice.add_theme_stylebox_override("normal", _plate(Color("#3a1d1a"), COIN))
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_notice.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_notice.offset_right = -30
	_notice.offset_top = -72
	_notice.offset_bottom = -30
	_notice.hide()
	_chrome = [back, purse, _coins, _mode]


func _caption(at: Vector2, letters: int, tone: Color) -> Label:
	var label := Label.new()
	label.position = at
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", MONO)
	label.add_theme_font_size_override("font_size", letters)
	label.add_theme_color_override("font_color", tone)
	add_child(label)
	return label


func show_backdrop() -> void:
	_passive = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dragging = false
	_camera.position.z = 2.1
	_camera.h_offset = 0.38
	for item: Control in _chrome:
		item.hide()
	for card: Button in _cards.values():
		card.hide()
	_notice.hide()
	_ink.hide()
	show()


func show_bases(
	heading: String, balance: String, base_entries: Array[Dictionary], notice: String = ""
) -> void:
	_passive = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_camera.position.z = 2.62
	_camera.h_offset = 0.0
	for item: Control in _chrome:
		item.show()
	_ink.show()
	_notice.text = "  %s  " % notice
	_notice.visible = not notice.is_empty()
	_notice_left = 4.0
	_entries = base_entries
	_mode.text = heading
	_coins.text = "%s monedas" % balance
	for card: Button in _cards.values():
		card.queue_free()
	_cards.clear()
	_order.clear()
	for entry: Dictionary in _entries:
		_order.append(entry.id)
		_cards[entry.id] = _make_card(entry)
	_idle = REST
	show()
	_place_cards()


func _make_card(entry: Dictionary) -> Button:
	var card := Button.new()
	card.focus_mode = Control.FOCUS_NONE
	var edge := RIM if entry.owned else Color("#8d8779")
	card.add_theme_stylebox_override("normal", _plate(CARD, edge))
	card.add_theme_stylebox_override("hover", _plate(Color("#1f1f26"), OPEN))
	card.add_theme_stylebox_override("pressed", _plate(Color("#0c0c10"), OPEN))
	var lines := VBoxContainer.new()
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_theme_constant_override("separation", -3)
	lines.position = Vector2(13, 5)
	card.add_child(lines)
	var wide := 0.0
	var tall := 0.0
	for row: Array in [[String(entry.name).to_upper(), 21, TEXT], [entry.note, 15, DIM]]:
		var words: String = row[0]
		var letters: int = row[1]
		var strip := HBoxContainer.new()
		strip.alignment = BoxContainer.ALIGNMENT_CENTER
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strip.add_theme_constant_override("separation", 6)
		lines.add_child(strip)
		var label := Label.new()
		label.text = words
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_override("font", MONO)
		label.add_theme_font_size_override("font_size", letters)
		label.add_theme_color_override("font_color", row[2])
		strip.add_child(label)
		var measure := MONO.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, letters)
		if letters == 15 and entry.priced:
			strip.add_child(_coin(15.0))
			measure.x += 21.0
		wide = maxf(wide, measure.x)
		tall += measure.y
	lines.size = Vector2(wide, tall - 3.0)
	card.custom_minimum_size = Vector2(wide + 26.0, tall + 9.0)
	card.size = card.custom_minimum_size
	card.pressed.connect(func() -> void: picked.emit(entry.action, entry.id))
	if entry.saved:
		var redo := Button.new()
		redo.text = "REINICIAR"
		redo.focus_mode = Control.FOCUS_NONE
		redo.add_theme_font_override("font", MONO)
		redo.add_theme_font_size_override("font_size", 13)
		redo.add_theme_color_override("font_color", DIM)
		redo.add_theme_stylebox_override("normal", _plate(CARD, Color("#8d8779")))
		redo.add_theme_stylebox_override("hover", _plate(Color("#1f1f26"), COIN))
		redo.add_theme_stylebox_override("pressed", _plate(Color("#0c0c10"), COIN))
		redo.position = Vector2(0, card.size.y + 4)
		redo.size = Vector2(card.size.x, 26)
		redo.pressed.connect(func() -> void: picked.emit("reset_confirm", entry.id))
		card.add_child(redo)
	add_child(card)
	return card


func _coin(span: float) -> Control:
	var coin := Control.new()
	coin.custom_minimum_size = Vector2(span, span)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin.draw.connect(
		func() -> void:
			var middle := Vector2(span, span) * 0.5
			coin.draw_circle(middle, span * 0.5, Color("#8a5a16"), true, -1.0, true)
			coin.draw_circle(middle, span * 0.42, COIN, true, -1.0, true)
			coin.draw_arc(middle, span * 0.26, 0.0, TAU, 20, Color("#b98422"), 1.3, true)
			coin.draw_arc(middle, span * 0.36, PI * 1.05, PI * 1.6, 10, Color("#fbe3a0"), 1.4, true)
	)
	return coin


func _plate(fill: Color, stroke: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(fill, 0.94)
	style.border_color = stroke
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	return style


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		_idle = 0.0
	elif event is InputEventMouseMotion and _dragging:
		_pivot.rotation.y += event.relative.x * 0.0085
		_tilt = clampf(_tilt + event.relative.y * 0.0055, -0.45, 0.45)
		_idle = 0.0


func _process(delta: float) -> void:
	if not visible or _pivot == null:
		return
	if not _dragging:
		_idle += delta
		if _idle >= REST:
			_pivot.rotation.y += delta * SPIN
			_tilt = move_toward(_tilt, 0.0, delta * 0.12)
	_pivot.rotation.x = _tilt
	if _passive:
		return
	if _notice.visible:
		_notice_left -= delta
		_notice.modulate.a = clampf(_notice_left, 0.0, 1.0)
		if _notice_left <= 0.0:
			_notice.hide()
	_place_cards()
	_ink.queue_redraw()


func _facing(point: Vector3) -> float:
	return point.normalized().dot((_camera.position - point).normalized())


func _place_cards() -> void:
	if _camera == null or size.x <= 0.0:
		return
	var middle := size * 0.5
	for id: String in _cards:
		var card: Button = _cards[id]
		var socket: Node3D = _sockets.get(id)
		if socket == null:
			card.hide()
			continue
		var point := _pivot.global_transform * socket.position
		var front := _facing(point)
		card.visible = front > 0.16
		if not card.visible:
			continue
		var spot := _camera.unproject_position(point)
		var away := (spot - middle).normalized()
		if away.length() < 0.5:
			away = Vector2.UP
		var reach := 46.0 + card.size.length() * 0.34
		var home := spot + away * reach - card.size * 0.5
		home.x = clampf(home.x, 8.0, size.x - card.size.x - 8.0)
		home.y = clampf(home.y, 8.0, size.y - card.size.y - 84.0)
		card.position = home
		card.modulate.a = clampf((front - 0.16) * 5.0, 0.0, 1.0)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SPACE)
	for star: Vector3 in _stars:
		var spark := 0.35 + star.z * 0.65
		draw_circle(
			Vector2(star.x, star.y) * size,
			0.6 + star.z * star.z * 1.3,
			Color(0.9, 0.93, 1.0, spark)
		)


func _draw_ink() -> void:
	if _camera == null or _order.is_empty():
		return
	for index in range(_order.size()):
		var first: Node3D = _sockets.get(_order[index])
		var second: Node3D = _sockets.get(_order[(index + 1) % _order.size()])
		if first == null or second == null:
			continue
		var start := first.position
		var finish := second.position
		for step in range(1, 14):
			var bend := start.slerp(finish, float(step) / 14.0)
			var point := _pivot.global_transform * (bend * 1.012)
			var front := _facing(point)
			if front > 0.1:
				var glow := clampf((front - 0.1) * 4.0, 0.0, 0.85)
				_ink.draw_circle(_camera.unproject_position(point), 2.1, Color(ROUTE, glow))
	for entry: Dictionary in _entries:
		var card: Button = _cards.get(entry.id)
		var socket: Node3D = _sockets.get(entry.id)
		if card == null or socket == null or not card.visible:
			continue
		var spot := _camera.unproject_position(_pivot.global_transform * socket.position)
		var tone: Color = OPEN if entry.owned else COIN
		var fade := card.modulate.a
		var target := card.position + card.size * 0.5
		_ink.draw_line(spot, target, Color(RIM, 0.75 * fade), 1.6, true)
		_ink.draw_circle(spot, 6.5, Color(CARD, fade), true, -1.0, true)
		_ink.draw_circle(spot, 4.6, Color(tone, fade), true, -1.0, true)
