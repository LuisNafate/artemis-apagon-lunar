class_name MissionHUD
extends Control

signal begin_requested
signal practice_requested
signal action_requested
signal pause_requested
signal reset_requested
signal build_toggled
signal blueprint_selected(kind: StringName)
signal diagnosis_selected(answer: StringName)

const BODY := preload("res://assets/ui/fonts/Barlow-Regular.ttf")
const SEMI := preload("res://assets/ui/fonts/Barlow-SemiBold.ttf")
const DISPLAY := preload("res://assets/ui/fonts/BarlowCondensed-Bold.ttf")
const MONO := preload("res://assets/ui/fonts/IBMPlexMono-Medium.ttf")
const ICONS := preload("res://assets/ui/resources.png")
const INK := Color("#111a2b")
const BORDER := Color("#36435b")
const WHITE := Color("#f2e5d3")
const SOFT := Color("#aebdd1")
const GOLD := Color("#edb67b")
const MINT := Color("#9ee1c8")
const RED := Color("#ff9c8d")
const COLORS := [Color("#81b8df"), Color("#beaee0"), MINT, GOLD]
const RESOURCES := [&"o2", &"co2", &"water", &"energy"]
const NAMES := ["Oxígeno", "Dióxido de carbono", "Agua", "Batería"]
const UNITS := ["kg", "kg", "kg", "kWh"]

var _phase: Label
var _clock: Label
var _feed: Label
var _solar: Label
var _crew: Label
var _mission_status: Label
var _suit: Label
var _steps: Array[Label] = []
var _meters: Array[ProgressBar] = []
var _numbers: Array[Label] = []
var _pause: Button
var _reset: Button
var _action: Button
var _station: Label
var _station_info: Label
var _build: Button
var _build_toolbar: Panel
var _build_hint: Label
var _build_buttons: Dictionary = {}
var _materials: Label
var _overlay: Panel
var _overlay_title: Label
var _overlay_tag: Label
var _overlay_body: Label
var _overlay_button: Button
var _overlay_secondary: Button
var _crew_report: Label
var _drill_card: Panel
var _drill_title: Label
var _drill_tip: Label
var _diagnosis: Panel
var _phase_id := AdversarialDirector.Phase.BRIEFING


func _ready() -> void:
	_build_header()
	_build_sidebar()
	_build_footer()
	_build_overlay()
	EventBus.message_posted.connect(_on_message)


func render(data: Dictionary) -> void:
	_phase_id = data.phase
	var active := _phase_id == AdversarialDirector.Phase.ACTIVE
	var paused := _phase_id == AdversarialDirector.Phase.PAUSED
	_clock.text = (
		"%02d:%02d / %02d:%02d"
		% [data.minute / 60, data.minute % 60, data.duration / 60, data.duration % 60]
	)
	_crew.text = "TELEMETRÍA   /   %d TRIPULANTES" % data.crew
	var phase_names := ["EN ESPERA", "TURNO ACTIVO", "EN PAUSA", "COMPLETO", "INTERRUMPIDO"]
	_phase.text = phase_names[_phase_id]
	if int(data.drill) in range(1, 7) and active:
		_phase.text = "PRÁCTICA GUIADA"
		_clock.text = "RELOJ DETENIDO"
	_phase.modulate = RED if _phase_id == AdversarialDirector.Phase.FAILED else MINT
	_pause.disabled = not (active or paused)
	_pause.text = "Reanudar" if paused else "Pausa"
	_reset.disabled = _phase_id == AdversarialDirector.Phase.BRIEFING
	_build.disabled = not active or data.suit_stage in [EVA.Stage.OUTSIDE, EVA.Stage.CALIBRATED]
	_materials.text = "%d MATERIALES" % data.materials
	_solar.text = (
		"SOLAR  %.2f kW   ·   RED %s"
		% [data.solar_kw, "ACTIVA" if data.essential_powered else "SIN ENERGÍA"]
	)
	_solar.modulate = RED if data.solar == SolarArray.Condition.DUSTY else SOFT
	for index in range(RESOURCES.size()):
		var key: StringName = RESOURCES[index]
		var value: float = data.reserves[key]
		var cap: float = data.capacity[key]
		_meters[index].value = value / cap
		_numbers[index].text = "%.3f / %.2f %s" % [value, cap, UNITS[index]]
		var risky := (value / cap > 0.8) if key == &"co2" else (value / cap < 0.18)
		if risky:
			_numbers[index].text += "  ·  ALERTA"
		_numbers[index].modulate = RED if risky else WHITE

	_render_steps(data)
	_render_overlay(data)
	_render_drill(data)


func _render_steps(data: Dictionary) -> void:
	var crop_ready: bool = data.crop >= data.crop_goal
	var cleaned: bool = data.solar == SolarArray.Condition.CLEANED
	var outside: bool = data.suit_stage in [EVA.Stage.OUTSIDE, EVA.Stage.CALIBRATED]
	_step(0, "Restablece soporte vital", data.support, not data.support)
	_step(1, "Cultivo · %d de %d min" % [data.crop, data.crop_goal], crop_ready, data.garden)
	var solar_line := "Supervisa la generación solar"
	if cleaned:
		solar_line = "Generación recuperada"
	elif data.solar == SolarArray.Condition.DUSTY:
		solar_line = "Limpia los paneles solares"
	_step(2, solar_line, cleaned, data.solar == SolarArray.Condition.DUSTY)
	_step(
		3,
		(
			"Vuelve a la esclusa"
			if data.suit_stage == EVA.Stage.CALIBRATED
			else "Calibra la baliza y regresa"
		),
		data.suit_stage == EVA.Stage.COMPLETE,
		outside or (crop_ready and cleaned)
	)
	if data.reception:
		_step(
			4, "Atiende 2 tripulaciones · %d/2" % data.served, int(data.served) == 2, data.waiting
		)
	else:
		_step(4, "Conecta un módulo nuevo", data.built_modules > 0, data.built_modules == 0)
	_suit.visible = outside
	if outside:
		_suit.text = "TRAJE  ·  %d MIN DE O₂" % ceili(data.suit_o2 / data.suit_rate)
		_suit.modulate = RED if data.suit_o2 / data.suit_capacity < 0.25 else GOLD
	_mission_status.text = _next_task(data)
	_mission_status.visible = not outside
	_crew_report.visible = data.reception
	if data.reception:
		_crew_report.text = "%s · %d camas libres" % [data.crew_report, data.berths]


func _next_task(data: Dictionary) -> String:
	if data.filter_fault or (data.reception and data.waiting):
		return (
			"Revisa la alerta de CO₂." if data.filter_fault else "Prepara camas y ve a Recepción."
		)
	if data.suit_stage == EVA.Stage.COMPLETE:
		return (
			"Mantén estables las reservas."
			if data.built_modules > 0
			else "Construye y conecta un módulo."
		)
	if data.solar == SolarArray.Condition.DUSTY:
		return "Ve a Solar y limpia los paneles."
	if not data.support or not data.garden:
		return "Ve a Cultivo y riégalo." if data.support else "Ve a Soporte vital y actívalo."
	if data.crop == data.crop_goal and data.solar == SolarArray.Condition.CLEANED:
		return "Ve a Esclusa y prepara la salida."
	return (
		"Construye mientras crece el cultivo."
		if data.built_modules == 0
		else "Vigila la energía y el cultivo."
	)


func _render_overlay(data: Dictionary) -> void:
	_overlay.visible = _phase_id != AdversarialDirector.Phase.ACTIVE
	_overlay_secondary.visible = (
		_phase_id in [AdversarialDirector.Phase.BRIEFING, AdversarialDirector.Phase.PAUSED]
	)
	match _phase_id:
		AdversarialDirector.Phase.BRIEFING:
			_overlay_tag.text = "ACADEMIA ARTEMIS"
			_overlay_tag.modulate = GOLD
			_overlay_title.text = "Recepción lunar"
			_overlay_body.text = "Recibe a tus primeros cadetes. Después, aloja a Alfa y Bravo."
			_overlay_button.text = "Practicar"
			_overlay_secondary.text = "Iniciar misión"
		AdversarialDirector.Phase.PAUSED:
			_overlay_tag.text = "SIMULACIÓN EN PAUSA"
			_overlay_tag.modulate = GOLD
			_overlay_title.text = "Turno en pausa"
			_overlay_body.text = "Reanuda el turno para seguir operando el hábitat."
			_overlay_button.text = "Reanudar turno"
			_overlay_secondary.text = "Reiniciar"
		AdversarialDirector.Phase.SUCCESS, AdversarialDirector.Phase.FAILED:
			var success := _phase_id == AdversarialDirector.Phase.SUCCESS
			_overlay_tag.text = "INFORME FINAL   /   %d MIN" % data.minute
			_overlay_tag.modulate = MINT if success else RED
			_overlay_title.text = "Misión completada" if success else "Turno interrumpido"
			_overlay_body.text = data.result
			_overlay_button.text = "Preparar otro turno"
			if data.drill == TrainingDrill.Step.COMPLETE:
				_overlay_title.text = "Práctica completada"
				_overlay_button.text = "Iniciar misión"


func _render_drill(data: Dictionary) -> void:
	var step := int(data.drill)
	_drill_card.visible = _phase_id == AdversarialDirector.Phase.ACTIVE and step in range(1, 7)
	if not _drill_card.visible:
		return
	var tasks := [
		["Activa soporte vital", "Haz clic en Soporte vital, acércate y pulsa E."],
		["Riega el cultivo", "Ve a Cultivo y pulsa E. Usa agua de la reserva."],
		["Corrige la avería", "Ve a Soporte vital. Diagnostica la falla y cambia el filtro."],
		["Coloca una pasarela", "Pulsa B. Pon una pasarela junto a una marca verde."],
		["Construye un hábitat", "Elige Hábitat y colócalo al lado de la pasarela."],
		["Recibe a los cadetes", "Pulsa Esc para cerrar planos. Ve a Recepción y pulsa E."],
	]
	_drill_title.text = "%d / 6   %s" % [step, tasks[step - 1][0]]
	_drill_tip.text = tasks[step - 1][1]


func set_station(title: String, action: String, explanation: String) -> void:
	var selected := not title.is_empty()
	_station.text = title if selected else "CONTROL DE SUPERFICIE"
	_station_info.text = explanation if selected else "Selecciona un módulo o una celda del mapa."
	_action.visible = selected and _phase_id == AdversarialDirector.Phase.ACTIVE
	_action.text = "%s   [E]" % action
	_action.disabled = not explanation.is_empty()
	if selected and explanation.is_empty():
		_station_info.text = "En alcance. La estación está lista."


func show_blueprint(kind: StringName, plan: Dictionary, status: String) -> void:
	var building := kind != &""
	_build_toolbar.visible = building
	_build.text = "Cerrar planos [B]" if building else "Construir [B]"
	if not building:
		return
	for key: StringName in _build_buttons:
		_build_buttons[key].modulate = GOLD if key == kind else WHITE
	_build_hint.text = "%s  ·  %s" % [plan.benefit, status]


func show_diagnosis(open: bool) -> void:
	_diagnosis.visible = open and _phase_id == AdversarialDirector.Phase.ACTIVE


func reset_message() -> void:
	_on_message("Sistema preparado para iniciar el turno.", false)


func _on_message(message: String, urgent: bool) -> void:
	_feed.text = message
	_feed.modulate = RED if urgent else WHITE


func _build_header() -> void:
	var header := _panel(self, Rect2(0, 0, 960, 82), Color("#101929"))
	_icon(header, 4, Rect2(24, 23, 32, 32))
	_label(header, "ARTEMIS PROTOCOL", Rect2(69, 13, 510, 43), 37, DISPLAY)
	_label(header, "LUNAR HABITAT   /   ENTRENAMIENTO", Rect2(71, 54, 470, 16), 12, MONO, GOLD)
	_phase = _label(header, "", Rect2(542, 17, 166, 20), 12, MONO, MINT)
	_clock = _label(header, "", Rect2(542, 36, 166, 28), 17, MONO)
	_pause = _button(header, "Pausa", Rect2(721, 24, 85, 34), false)
	_pause.pressed.connect(func() -> void: pause_requested.emit())
	_reset = _button(header, "Reiniciar", Rect2(814, 24, 118, 34), false)
	_reset.pressed.connect(func() -> void: reset_requested.emit())

	var strip := _panel(self, Rect2(24, 104, 384, 37), Color("#141e32"))
	_label(strip, "POLO SUR  /  PLATAFORMA DE ENTRENAMIENTO", Rect2(12, 7, 360, 20), 12, MONO, SOFT)


func _build_sidebar() -> void:
	var aside := _panel(self, Rect2(960, 0, 320, 720), INK)
	_label(aside, "ESTADO DEL HÁBITAT", Rect2(22, 18, 280, 40), 26, DISPLAY)
	_crew = _label(aside, "", Rect2(23, 60, 270, 18), 12, MONO, SOFT)
	for index in range(RESOURCES.size()):
		var y := 97 + index * 67
		_icon(aside, index, Rect2(22, y + 5, 20, 20))
		_label(aside, NAMES[index], Rect2(52, y, 250, 23), 17, SEMI)
		_numbers.append(_label(aside, "", Rect2(53, y + 23, 242, 18), 12, MONO))
		var bar := ProgressBar.new()
		bar.max_value = 1.0
		bar.step = 0.0
		bar.show_percentage = false
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_theme_stylebox_override("background", _style(Color("#2b374e"), Color.TRANSPARENT))
		bar.add_theme_stylebox_override("fill", _style(COLORS[index], Color.TRANSPARENT))
		aside.add_child(bar)
		bar.position = Vector2(53, y + 47)
		bar.size = Vector2(244, 5)
		_meters.append(bar)
	_solar = _label(aside, "", Rect2(23, 367, 273, 27), 12, MONO, SOFT)
	_crew_report = _label(aside, "", Rect2(23, 392, 275, 22), 13, SEMI, GOLD)

	var card := _panel(aside, Rect2(15, 417, 290, 281), Color("#182439"))
	_label(card, "LISTA DE MISIÓN", Rect2(15, 12, 260, 31), 23, DISPLAY)
	for index in range(5):
		var row := _label(card, "", Rect2(15, 48 + 31 * index, 262, 26), 16, SEMI)
		_steps.append(row)
	_mission_status = _label(card, "", Rect2(15, 218, 259, 38), 15, BODY, SOFT)
	_suit = _label(card, "", Rect2(15, 220, 259, 32), 14, MONO, GOLD)


func _build_footer() -> void:
	var slab := _panel(self, Rect2(0, 606, 960, 114), Color("#101929"))
	_feed = _label(slab, "", Rect2(31, 7, 895, 25), 16, SEMI)
	reset_message()
	_station = _label(slab, "", Rect2(31, 43, 460, 19), 12, MONO, GOLD)
	_station_info = _label(slab, "", Rect2(31, 65, 475, 22), 16, BODY)
	_action = _button(slab, "", Rect2(514, 44, 220, 43), true)
	_action.pressed.connect(func() -> void: action_requested.emit())
	_build = _button(slab, "Construir [B]", Rect2(750, 44, 180, 43), false)
	_build.pressed.connect(func() -> void: build_toggled.emit())
	_label(
		slab,
		"CLIC / WASD  Mover    E  Operar    ESC  Pausa",
		Rect2(31, 92, 625, 18),
		11,
		MONO,
		SOFT
	)
	_materials = _label(slab, "", Rect2(750, 91, 180, 18), 11, MONO, GOLD)
	_build_toolbar = _panel(slab, Rect2(15, 34, 730, 78), Color("#17253a"))
	var index := 0
	var catalog := AdversarialDirector.construction.catalog
	for kind: StringName in catalog:
		var plan: Dictionary = catalog[kind]
		var button := _button(
			_build_toolbar,
			"%s · %d" % [plan.title, int(plan.cost)],
			Rect2(8 + index * 179, 8, 171, 34),
			false
		)
		button.pressed.connect(func() -> void: blueprint_selected.emit(kind))
		_build_buttons[kind] = button
		index += 1
	_build_hint = _label(_build_toolbar, "", Rect2(9, 47, 711, 22), 14, SEMI, MINT)
	_build_toolbar.hide()
	_diagnosis = _panel(slab, Rect2(15, 34, 730, 78), Color("#17253a"))
	_label(
		_diagnosis,
		"Hay energía, pero el CO₂ sube. ¿Qué sistema revisarías?",
		Rect2(10, 3, 699, 25),
		15,
		SEMI,
		GOLD
	)
	var filter := _button(_diagnosis, "Extracción de CO₂", Rect2(10, 31, 205, 37), false)
	filter.pressed.connect(func() -> void: diagnosis_selected.emit(&"co2"))
	var power := _button(_diagnosis, "Generación solar", Rect2(225, 31, 205, 37), false)
	power.pressed.connect(func() -> void: diagnosis_selected.emit(&"solar"))
	_diagnosis.hide()


func _build_overlay() -> void:
	_overlay = _panel(self, Rect2(26, 160, 345, 224), Color("#151e30"))
	_overlay_tag = _label(_overlay, "", Rect2(19, 16, 306, 20), 12, MONO, GOLD)
	_overlay_title = _label(_overlay, "", Rect2(18, 39, 311, 53), 37, DISPLAY)
	_overlay_body = _label(_overlay, "", Rect2(20, 96, 304, 65), 16, BODY, SOFT)
	_overlay_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_overlay_button = _button(_overlay, "", Rect2(19, 172, 159, 36), true)
	_overlay_button.pressed.connect(_primary_overlay_action)
	_overlay_secondary = _button(_overlay, "Reiniciar", Rect2(184, 172, 140, 36), false)
	_overlay_secondary.pressed.connect(_secondary_overlay_action)
	_drill_card = _panel(self, Rect2(24, 151, 365, 82), Color("#17263a"))
	_drill_title = _label(_drill_card, "", Rect2(12, 5, 342, 26), 21, DISPLAY, GOLD)
	_drill_tip = _label(_drill_card, "", Rect2(12, 33, 339, 41), 16, BODY)
	_drill_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _primary_overlay_action() -> void:
	match _phase_id:
		AdversarialDirector.Phase.BRIEFING:
			practice_requested.emit()
		AdversarialDirector.Phase.PAUSED:
			pause_requested.emit()
		_:
			if AdversarialDirector.drill.step == TrainingDrill.Step.COMPLETE:
				begin_requested.emit()
			else:
				reset_requested.emit()


func _secondary_overlay_action() -> void:
	if _phase_id == AdversarialDirector.Phase.BRIEFING:
		begin_requested.emit()
	else:
		reset_requested.emit()


func _step(index: int, text: String, done: bool, current: bool) -> void:
	var prefix := "✓" if done else ("›" if current else "·")
	_steps[index].text = "%s   %s" % [prefix, text]
	_steps[index].modulate = MINT if done else (GOLD if current else SOFT)


func _panel(parent: Control, bounds: Rect2, color: Color) -> Panel:
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", _style(color, BORDER))
	parent.add_child(panel)
	panel.position = bounds.position
	panel.size = bounds.size
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	return panel


func _label(
	parent: Control, text: String, bounds: Rect2, size_px: int, face: Font, color: Color = WHITE
) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", face)
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	label.text = text
	parent.add_child(label)
	label.position = bounds.position
	label.size = bounds.size
	return label


func _button(parent: Control, text: String, bounds: Rect2, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_override("font", SEMI)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", INK if primary else WHITE)
	button.add_theme_color_override("font_hover_color", INK if primary else WHITE)
	button.add_theme_color_override("font_pressed_color", INK if primary else WHITE)
	button.add_theme_color_override("font_focus_color", INK if primary else WHITE)
	button.add_theme_color_override("font_disabled_color", SOFT)
	button.add_theme_stylebox_override(
		"normal", _style(GOLD if primary else Color("#1f2a40"), BORDER)
	)
	button.add_theme_stylebox_override(
		"hover", _style(WHITE if primary else Color("#30405c"), GOLD)
	)
	button.add_theme_stylebox_override(
		"pressed", _style(Color("#d6a16c") if primary else Color("#34445f"), GOLD)
	)
	button.add_theme_stylebox_override("disabled", _style(Color("#202a3e"), BORDER))
	button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, WHITE))
	parent.add_child(button)
	button.position = bounds.position
	button.size = bounds.size
	return button


func _icon(parent: Control, index: int, bounds: Rect2) -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas = ICONS
	atlas.region = Rect2(index * 16, 0, 16, 16)
	var icon := TextureRect.new()
	icon.texture = atlas
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)
	icon.position = bounds.position
	icon.size = bounds.size


func _style(color: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	return style
