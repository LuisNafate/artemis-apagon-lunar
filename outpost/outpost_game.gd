extends Control

const BODY := preload("res://assets/ui/fonts/Barlow-Regular.ttf")
const SEMI := preload("res://assets/ui/fonts/Barlow-SemiBold.ttf")
const DISPLAY := preload("res://assets/ui/fonts/BarlowCondensed-Bold.ttf")
const MONO := preload("res://assets/ui/fonts/IBMPlexMono-Medium.ttf")
const INK := Color("#0b1323")
const PANEL := Color("#141f34")
const EDGE := Color("#354765")
const WHITE := Color("#eff2ef")
const SOFT := Color("#abbcd3")
const MINT := Color("#6de7c2")
const GOLD := Color("#ffbd73")
const RED := Color("#fb8f88")
const RESOURCE_NAMES := ["Aire", "Agua", "Comida", "Batería", "Exposición"]
const RESOURCE_COLORS := [Color("#a9e2ff"), Color("#87bdfb"), MINT, GOLD, RED]

var sim := OutpostSim.new()
var orders: Dictionary
var _forecast: Dictionary
var _map: OutpostMap
var _timeline: Array[Label] = []
var _resource_values: Array[Label] = []
var _resource_bars: Array[ProgressBar] = []
var _threat: Label
var _threat_detail: Label
var _preview_status: Label
var _crew: Label
var _operation: Label
var _objective: Label
var _hint: Label
var _scenario: Button
var _shelter: Button
var _repair: Button
var _bridge: Button
var _confirm: Button
var _result: Panel
var _result_title: Label
var _result_detail: Label
var _result_retry: Button
var _result_next: Button
var _tone: AudioStreamPlayer


func _ready() -> void:
	_build_interface()
	_tone = AudioStreamPlayer.new()
	_tone.volume_db = -15.0
	add_child(_tone)
	restart(0)


func restart(index: int) -> void:
	sim.reset(index)
	orders = {
		"life": false,
		"farm": false,
		"shelter": false,
		"inside": false,
		"repair": "",
		"bridge": false
	}
	_result.hide()
	_result_retry.release_focus()
	_forecast = sim.preview(orders)
	_render()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_1:
			_toggle(&"life")
		KEY_2:
			_toggle(&"farm")
		KEY_3:
			_toggle(&"shelter")
		KEY_E:
			_toggle(&"inside")
		KEY_SPACE:
			_advance()
		KEY_R:
			restart(sim.scenario)
		KEY_TAB:
			_next_scenario()
		_:
			return
	get_viewport().set_input_as_handled()


func _toggle(key: StringName) -> void:
	if not sim.result.is_empty():
		return
	orders[key] = not orders[key]
	if key == &"inside":
		orders.shelter = orders.inside
	_render()
	_play_feedback([510.0] if orders[key] else [350.0])


func _queue_repair() -> void:
	var branch := _repair_target()
	if not branch.is_empty():
		orders.repair = "" if orders.repair == branch else branch
		_render()


func _queue_bridge() -> void:
	orders.bridge = not orders.bridge
	_render()


func _repair_target() -> String:
	if not sim.result.is_empty():
		return ""
	var cut: String = sim.events()[sim.turn][3]
	if not cut.is_empty():
		return cut
	if not sim.state.north:
		return "north"
	return "south" if not sim.state.south else ""


func _next_scenario() -> void:
	restart((sim.scenario + 1) % sim.config.scenarios.size())


func _advance() -> void:
	if not sim.result.is_empty():
		return
	var previous_harvests := int(sim.state.harvests)
	var report := sim.resolve(orders)
	var harvest := int(sim.state.harvests) > previous_harvests
	orders.repair = ""
	orders.bridge = false
	if sim.result.is_empty():
		_render()
		if harvest:
			_preview_status.text = "Cosechaste 4 raciones."
			_preview_status.modulate = MINT
		_play_feedback([440.0, 659.0, 880.0] if harvest else [490.0, 610.0])
	else:
		_update_resources(report)
		_confirm.disabled = true
		_shelter.disabled = true
		_repair.disabled = true
		_bridge.disabled = true
		_result_title.text = _victory_title() if sim.won else "Turno interrumpido"
		_result_title.modulate = MINT if sim.won else RED
		_result_detail.text = (
			(
				"2 tripulantes a salvo · %d cosechas · %d/8 exposición."
				% [sim.state.harvests, sim.state.dose]
			)
			if sim.won
			else report.result
		)
		_result.visible = true
		_play_feedback([440.0, 554.0, 659.0, 880.0] if sim.won else [392.0, 280.0, 196.0])


func _victory_title() -> String:
	if int(sim.state.dose) <= 1 and int(sim.state.kits) > 0:
		return "Puesto a salvo · Oro"
	return "Puesto a salvo"


func _play_feedback(notes: Array) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var rate := 16000
	var samples := 1280
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	var data := PackedByteArray()
	data.resize(2 * samples * notes.size())
	for note in range(notes.size()):
		for index in range(samples):
			var time := float(index) / rate
			var envelope := minf(time * 150.0, 1.0) * (1.0 - float(index) / samples)
			var wave := sin(TAU * float(notes[note]) * time) * envelope
			data.encode_s16((note * samples + index) * 2, roundi(wave * 11000))
	stream.data = data
	_tone.stream = stream
	_tone.play()


func _render() -> void:
	_forecast = sim.preview(orders)
	_map.planned = _forecast
	_map.orders = orders
	_map.queue_redraw()
	var event: Array = sim.events()[sim.turn]
	_scenario.text = "%s  [Tab]" % sim.config.scenarios[sim.scenario].name
	_crew.text = "2 TRIPULANTES  /  %s" % ("EN REFUGIO" if orders.inside else "EN SERVICIO")
	_threat.text = event[0]
	_threat_detail.text = "SOLAR  %d    ·    RADIACIÓN  %d" % [event[1], event[2]]
	_threat.modulate = GOLD if int(event[2]) > 0 or not String(event[3]).is_empty() else WHITE
	for index in range(_timeline.size()):
		var tick := _timeline[index]
		var forecast_event: Array = sim.events()[index]
		tick.modulate = MINT if index < sim.turn else SOFT
		if index == sim.turn:
			tick.modulate = GOLD
		var symbol := "R" if int(forecast_event[2]) > 0 else "E"
		if not String(forecast_event[3]).is_empty():
			symbol = "C" if symbol == "E" else "R+C"
		tick.text = "%02d   %s" % [index + 1, symbol]
	_update_resources(_forecast)
	_preview_status.text = "Confirma cuando la proyección te convenga."
	if not _forecast.result.is_empty():
		_preview_status.text = _forecast.result
	_preview_status.modulate = GOLD if not _forecast.result.is_empty() else SOFT
	_objective.text = (
		"COSECHAS  %d / %d     ·     BROTES  %d / 2"
		% [sim.state.harvests, sim.config.minimum_harvests, sim.state.growth]
	)
	_operation.text = (
		"DEMANDA  %d    ·    PIEZAS  %d → %d"
		% [_forecast.load, sim.state.kits, _forecast.state.kits]
	)
	_set_commands()


func _set_commands() -> void:
	var target := _repair_target()
	_shelter.text = "Salir del refugio  [E]" if orders.inside else "Entrar al refugio  [E]"
	_repair.disabled = (
		target.is_empty() or (int(_forecast.state.kits) <= 0 and orders.repair.is_empty())
	)
	var branch := "Norte" if target == "north" else "Sur"
	_repair.text = (
		"Cancelar reparación" if not orders.repair.is_empty() else "Reparar %s · 1" % branch
	)
	if target.is_empty():
		_repair.text = "Ramal sin averías"
	_bridge.text = "Derivación instalada" if sim.state.bridge else "Instalar derivación · 1"
	if orders.bridge:
		_bridge.text = "Cancelar derivación"
	_bridge.disabled = sim.state.bridge or (int(_forecast.state.kits) <= 0 and not orders.bridge)
	_confirm.disabled = false
	_shelter.disabled = false
	_hint.text = _context_tip()


func _context_tip() -> String:
	if sim.turn == 0:
		return "Activa soporte vital y cultivo en el mapa. Compara las reservas antes de confirmar."
	if int(_forecast.radiation) > 0:
		return (
			"Tripulación a cubierto. Revisa la exposición prevista."
			if orders.inside
			else "Entra al refugio. Baja la exposición y se pausa el cultivo."
		)
	if not _repair_target().is_empty():
		return "Prepara una reparación o conecta ambos ramales con una derivación."
	return "El cultivo necesita dos turnos con energía. Una cosecha usa 2 de agua y da 4 raciones."


func _update_resources(report: Dictionary) -> void:
	for index in range(OutpostSim.KEYS.size()):
		var key: StringName = OutpostSim.KEYS[index]
		var old := int(sim.state[key])
		var next := int(report.state[key])
		var cap := int(sim.config.limits[key])
		_resource_values[index].text = "%d  →  %d" % [old, next]
		_resource_bars[index].value = float(next) / cap
		var risky := (next >= cap - 2) if key == &"dose" else (next <= 1)
		_resource_values[index].modulate = RED if risky else RESOURCE_COLORS[index]


func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = INK
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label(self, "ARTEMIS", Rect2(29, 15, 190, 49), 47, DISPLAY, WHITE)
	_label(self, "PUESTO LUNAR", Rect2(220, 33, 222, 22), 14, MONO, MINT)
	_crew = _label(self, "", Rect2(665, 26, 345, 28), 13, MONO, SOFT)
	_scenario = _button(self, "", Rect2(1003, 23, 249, 38), _next_scenario)
	_build_map()
	_build_sidebar()
	_build_result()


func _build_map() -> void:
	for index in range(8):
		var chip := _panel(self, Rect2(29 + index * 107, 81, 98, 36), PANEL)
		var label := _label(chip, "", Rect2(0, 0, 98, 36), 13, MONO, SOFT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_timeline.append(label)
	_map = OutpostMap.new()
	_map.position = Vector2(29, 132)
	_map.size = Vector2(844, 421)
	add_child(_map)
	_map.module_pressed.connect(_toggle)
	_label(
		self, "E  GENERACIÓN     R  RADIACIÓN     C  CORTE", Rect2(30, 560, 550, 22), 12, MONO, SOFT
	)
	_operation = _label(self, "", Rect2(576, 560, 390, 22), 12, MONO, WHITE)
	var footer := _panel(self, Rect2(29, 595, 844, 96), PANEL)
	_hint = _label(footer, "", Rect2(16, 8, 810, 28), 16, SEMI, WHITE)
	_shelter = _button(footer, "", Rect2(16, 44, 243, 38), func() -> void: _toggle(&"inside"))
	_repair = _button(footer, "", Rect2(270, 44, 242, 38), _queue_repair)
	_bridge = _button(footer, "", Rect2(523, 44, 304, 38), _queue_bridge)


func _build_sidebar() -> void:
	var side := _panel(self, Rect2(891, 81, 361, 610), PANEL)
	_label(side, "PRÓXIMO TURNO", Rect2(18, 14, 325, 22), 12, MONO, GOLD)
	_threat = _label(side, "", Rect2(18, 37, 323, 42), 34, DISPLAY, WHITE)
	_threat_detail = _label(side, "", Rect2(18, 85, 324, 23), 13, MONO, SOFT)
	for index in range(RESOURCE_NAMES.size()):
		var y := 132 + index * 64
		var tint: Color = RESOURCE_COLORS[index]
		_label(side, RESOURCE_NAMES[index], Rect2(18, y, 170, 24), 19, SEMI, WHITE)
		var value := _label(side, "", Rect2(193, y, 147, 24), 17, MONO, tint)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_resource_values.append(value)
		var bar := ProgressBar.new()
		bar.max_value = 1
		bar.step = 0.0
		bar.show_percentage = false
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_theme_stylebox_override("background", _style(Color("#26354f"), Color.TRANSPARENT))
		bar.add_theme_stylebox_override("fill", _style(tint, Color.TRANSPARENT))
		side.add_child(bar)
		bar.position = Vector2(18, y + 33)
		bar.size = Vector2(322, 5)
		_resource_bars.append(bar)
	_objective = _label(side, "", Rect2(18, 455, 321, 23), 13, MONO, MINT)
	_preview_status = _label(side, "", Rect2(18, 488, 318, 48), 15, BODY, SOFT)
	_preview_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm = _button(side, "Confirmar turno  [Espacio]", Rect2(18, 548, 322, 45), _advance, true)


func _build_result() -> void:
	_result = _panel(self, Rect2(228, 232, 490, 211), Color("#19283f"))
	_result_title = _label(_result, "", Rect2(20, 14, 447, 49), 42, DISPLAY, WHITE)
	_result_detail = _label(_result, "", Rect2(23, 75, 444, 58), 19, BODY, WHITE)
	_result_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_retry = _button(
		_result,
		"Reintentar  [R]",
		Rect2(22, 152, 208, 42),
		func() -> void: restart(sim.scenario),
		true
	)
	_result_next = _button(_result, "Cambiar misión", Rect2(240, 152, 228, 42), _next_scenario)


func _panel(parent: Control, bounds: Rect2, color: Color) -> Panel:
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", _style(color, EDGE))
	parent.add_child(panel)
	panel.position = bounds.position
	panel.size = bounds.size
	return panel


func _label(
	parent: Control, value: String, bounds: Rect2, font_size: int, font: Font, color: Color
) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text = value
	parent.add_child(label)
	label.position = bounds.position
	label.size = bounds.size
	return label


func _button(
	parent: Control, value: String, bounds: Rect2, command: Callable, primary: bool = false
) -> Button:
	var button := Button.new()
	button.text = value
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", SEMI)
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", INK if primary else WHITE)
	button.add_theme_color_override("font_hover_color", INK if primary else WHITE)
	button.add_theme_color_override("font_pressed_color", INK if primary else WHITE)
	button.add_theme_color_override("font_disabled_color", SOFT)
	button.add_theme_stylebox_override(
		"normal", _style(MINT if primary else Color("#22324d"), EDGE)
	)
	button.add_theme_stylebox_override(
		"hover", _style(Color("#99f3d7") if primary else Color("#354c69"), MINT)
	)
	button.add_theme_stylebox_override(
		"pressed", _style(GOLD if primary else Color("#334969"), GOLD)
	)
	button.add_theme_stylebox_override("disabled", _style(Color("#18243a"), EDGE))
	parent.add_child(button)
	button.position = bounds.position
	button.size = bounds.size
	button.pressed.connect(command)
	return button


func _style(color: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	return style
