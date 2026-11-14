class_name FieldHUD
extends Control

signal restart_requested

const BODY := preload("res://assets/ui/fonts/Barlow-SemiBold.ttf")
const DISPLAY := preload("res://assets/ui/fonts/BarlowCondensed-Bold.ttf")
const MONO := preload("res://assets/ui/fonts/IBMPlexMono-Medium.ttf")
const WHITE := Color("#eaf1fc")
const SOFT := Color("#b6c7e2")
const GOLD := Color("#ffc079")
const MINT := Color("#90f5bb")
const RED := Color("#ff9281")

var objective: Label
var detail: Label
var weather: Label
var controls: Label
var action: Label
var feedback: Label
var _bars: Array[ProgressBar] = []
var _values: Array[Label] = []
var _card: Panel
var _result: Label
var _reason: Label
var _marker: Label
var _flash: ColorRect
var _fade: Tween


func build() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := _panel(self, Rect2(28, 26, 410, 130))
	_label(panel, "ARTEMIS  /  APAGÓN LUNAR", Rect2(17, 12, 370, 22), 13, MONO, GOLD)
	objective = _label(panel, "", Rect2(16, 35, 382, 49), 35, DISPLAY, WHITE)
	detail = _label(panel, "", Rect2(18, 88, 375, 30), 16, BODY, SOFT)
	var meters := _panel(self, Rect2(963, 26, 289, 223))
	weather = _label(meters, "", Rect2(17, 10, 258, 24), 14, MONO, GOLD)
	var names := ["Aire", "Energía", "Cultivos", "Exposición"]
	var inks := [Color("#81ccff"), GOLD, MINT, RED]
	for idx in range(names.size()):
		var y := 42 + idx * 42
		_label(meters, names[idx], Rect2(17, y, 146, 23), 15, BODY, WHITE)
		var value := _label(meters, "", Rect2(153, y, 117, 23), 12, MONO, inks[idx])
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_values.append(value)
		var progress := ProgressBar.new()
		progress.max_value = 1
		progress.step = 0
		progress.show_percentage = false
		progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
		progress.add_theme_stylebox_override("background", _style(Color("#26364e")))
		progress.add_theme_stylebox_override("fill", _style(inks[idx]))
		meters.add_child(progress)
		progress.position = Vector2(17, y + 25)
		progress.size = Vector2(253, 4)
		_bars.append(progress)
	var footer := _panel(self, Rect2(28, 647, 1224, 48))
	controls = _label(
		footer,
		"WASD  Mover     ESPACIO  Saltar     SHIFT  Turbo     E  Usar     R  Reiniciar",
		Rect2(15, 7, 1194, 34),
		14,
		MONO,
		SOFT
	)
	action = _label(self, "", Rect2(305, 572, 670, 51), 28, DISPLAY, GOLD)
	action.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action.add_theme_constant_override("outline_size", 8)
	feedback = _label(self, "", Rect2(305, 532, 670, 35), 19, BODY, WHITE)
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback.add_theme_constant_override("outline_size", 8)
	_marker = _label(self, "", Rect2(0, 0, 190, 31), 16, MONO, GOLD)
	_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_marker.add_theme_constant_override("outline_size", 9)
	_flash = ColorRect.new()
	_flash.size = Vector2(1280, 720)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color.TRANSPARENT
	add_child(_flash)
	_card = _panel(self, Rect2(390, 241, 500, 226))
	_result = _label(_card, "", Rect2(20, 15, 460, 55), 42, DISPLAY, WHITE)
	_reason = _label(_card, "", Rect2(21, 74, 454, 58), 18, BODY, SOFT)
	_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var retry := Button.new()
	retry.text = "Volver a jugar  [R]"
	retry.position = Vector2(21, 155)
	retry.size = Vector2(458, 48)
	retry.focus_mode = Control.FOCUS_NONE
	retry.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	retry.add_theme_font_override("font", BODY)
	retry.add_theme_font_size_override("font_size", 20)
	retry.add_theme_color_override("font_color", Color("#132238"))
	retry.add_theme_color_override("font_hover_color", Color("#132238"))
	retry.add_theme_color_override("font_pressed_color", Color("#132238"))
	retry.add_theme_stylebox_override("normal", _style(MINT))
	retry.add_theme_stylebox_override("hover", _style(WHITE))
	retry.add_theme_stylebox_override("pressed", _style(GOLD))
	_card.add_child(retry)
	retry.pressed.connect(func() -> void: restart_requested.emit())
	_card.hide()


func update_telemetry(sim: FieldSim, sheltered: bool) -> void:
	var left := maxi(0, ceili(float(sim.config.duration) - sim.elapsed))
	if not sim.online:
		weather.text = "RED APAGADA"
	elif sim.storm_active():
		weather.text = "A CUBIERTO" if sheltered else "ALERTA SOLAR · BUSCA REFUGIO"
	elif sim.storm_wait() <= 6.0:
		weather.text = "TORMENTA EN %ds" % ceili(sim.storm_wait())
	else:
		weather.text = "%02ds PARA CERRAR EL TURNO" % left
	weather.modulate = RED if sim.storm_active() and not sheltered else GOLD
	var counts := [
		sim.air,
		sim.charge,
		sim.harvested + sim.growing / float(sim.config.growth_seconds),
		sim.dose
	]
	var capacities := [
		float(sim.config.air), float(sim.config.charge), 2.0, float(sim.config.dose_limit)
	]
	for idx in range(counts.size()):
		_bars[idx].value = float(counts[idx]) / float(capacities[idx])
		if idx == 2:
			_values[idx].text = "%d / 2" % sim.harvested
		else:
			_values[idx].text = "%d%%" % roundi(_bars[idx].value * 100.0)


func mark(text: String, point: Vector2, tint: Color) -> void:
	_marker.text = text
	_marker.position = point - Vector2(95, 15)
	_marker.modulate = tint
	_marker.visible = not text.is_empty()


func pulse(tint: Color) -> void:
	if _fade:
		_fade.kill()
	_flash.color = Color(tint, 0.24)
	_fade = create_tween()
	_fade.tween_property(_flash, "color:a", 0.0, 0.55)


func finish(title: String, reason: String, success: bool) -> void:
	_result.text = title
	_result.modulate = MINT if success else RED
	_reason.text = reason
	_card.show()
	action.hide()
	_marker.hide()


func _panel(parent: Control, bounds: Rect2) -> Panel:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(Color("#111b33e8"), Color("#506688")))
	parent.add_child(panel)
	panel.position = bounds.position
	panel.size = bounds.size
	return panel


func _label(
	parent: Control, value: String, bounds: Rect2, font_size: int, font: Font, tint: Color
) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = value
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(label)
	label.position = bounds.position
	label.size = bounds.size
	return label


func _style(color: Color, edge: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = edge
	style.set_border_width_all(1)
	return style
