class_name LunarInterface
extends CanvasLayer

signal selected(action: String, argument: String)

const TITLE := preload("res://assets/ui/fonts/BarlowCondensed-Bold.ttf")
const BODY := preload("res://assets/ui/fonts/Barlow-SemiBold.ttf")
const FILL := Color("#f1dfbf")
const EDGE := Color("#a47556")
const SOFT := Color("#755f52")
const INK := Color("#30251e")
const TEAL := Color("#205851")
const BRICK := Color("#8e3e33")
const CHIP_FILL := Color("#ecd5a8")
const CRATE_NAMES := {
	&"sample": "Caja de muestra",
	&"ice": "Caja de hielo",
	&"ore": "Caja de mineral",
	&"fuel": "Caja de propelente",
	&"food": "Caja de raciones"
}
const AIR_ICON := preload("res://assets/ui/hud/aire.png")
const CHIP_ICONS := [
	AIR_ICON,
	AIR_ICON,
	preload("res://assets/ui/hud/bateria.png"),
	preload("res://assets/ui/hud/agua.png"),
	preload("res://assets/ui/hud/hambre.png")
]
const PROMPTS := [
	["Toma la muestra", "El gato azul se acerca a la mesa y toca Acción."],
	["Pasa la caja", "Acércate a tu compañero y toca Soltar / pasar."],
	["Entrega la muestra", "El gato naranja vuelve a la mesa y toca Entregar."],
	["Empiecen juntos", "Toca Acción en la mesa para iniciar el día."]
]

var joystick := LunarTouch.new()
var play: Control
var globe: LunarGlobe
var menu: PanelContainer
var address: LineEdit
var action_button: Button
var release_button: Button
var jump_button: Button
var details: Label
var location: Label
var alert: Label
var next_step: Label
var feedback: Label
var _title_tween: Tween
var _zone_panel: PanelContainer
var _zone_title: Label
var _zone_buttons: VBoxContainer
var _tapped_name := ""
var _tapped_until := 0
var _lobby_backdrop: Control
var _heading: Label
var _message: Label
var _list: VBoxContainer
var _resources: GridContainer
var _readouts: Array[Label] = []
var _controls: HBoxContainer
var _pause: Button
var _wallet_balance: Label


func build() -> void:
	var root := Control.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var design := Theme.new()
	design.default_font = BODY
	design.default_font_size = 22
	design.set_stylebox("panel", "PanelContainer", _style(FILL, EDGE))
	design.set_color("font_color", "Label", INK)
	design.set_color("font_color", "LineEdit", INK)
	design.set_color("font_placeholder_color", "LineEdit", SOFT)
	design.set_color("caret_color", "LineEdit", INK)
	design.set_stylebox("normal", "LineEdit", _style(Color("#fff2d6"), EDGE))
	design.set_stylebox("focus", "LineEdit", _style(Color("#fff2d6"), TEAL))
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var fill := Color("#43352e") if state == "normal" else Color("#604839")
		if state == "disabled":
			fill = Color("#202937")
		design.set_stylebox(state, "Button", _style(fill, EDGE))
	root.theme = design
	_build_play(root)
	globe = LunarGlobe.new()
	root.add_child(globe)
	globe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	globe.picked.connect(
		func(action: String, argument: String) -> void: selected.emit(action, argument)
	)
	globe.hide()
	_build_lobby_backdrop(root)
	_build_menu(root)


func _build_play(root: Control) -> void:
	play = Control.new()
	root.add_child(play)
	play.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	play.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var header := PanelContainer.new()
	play.add_child(header)
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 250
	header.offset_right = -250
	header.offset_top = 10
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var content := VBoxContainer.new()
	header.add_child(content)
	location = _label(content, "", 29, TITLE)
	_float_text(location)
	_resources = GridContainer.new()
	_resources.columns = 5
	_resources.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play.add_child(_resources)
	_resources.position = Vector2(18, 8)
	_resources.add_theme_constant_override("h_separation", 12)
	_resources.add_theme_constant_override("v_separation", 0)
	var colors := [
		Color("#4d7fc4"), Color("#e0883a"), Color("#e0883a"), Color("#3f6fc0"), Color("#d8602f")
	]
	for index in range(colors.size()):
		var chip := PanelContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		_resources.add_child(chip)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 4)
		chip.add_child(row)
		var icon := TextureRect.new()
		icon.texture = CHIP_ICONS[index]
		icon.custom_minimum_size = Vector2(56, 56)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		var reading := _label(row, "", 24, TITLE)
		reading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_float_text(reading)
		_readouts.append(reading)
	details = _label(content, "", 16)
	_float_text(details)
	details.hide()
	var notes := VBoxContainer.new()
	notes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play.add_child(notes)
	notes.anchor_top = 1.0
	notes.anchor_bottom = 1.0
	notes.anchor_left = 0.5
	notes.anchor_right = 0.5
	notes.offset_left = -300
	notes.offset_right = 300
	notes.offset_top = -120
	notes.offset_bottom = -90
	notes.grow_vertical = Control.GROW_DIRECTION_BEGIN
	feedback = _label(notes, "", 22)
	feedback.hide()
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_float_text(feedback)
	feedback.add_theme_color_override("font_color", Color("#fbefd3"))
	next_step = _label(notes, "", 16)
	next_step.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_float_text(next_step)
	next_step.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_step.custom_minimum_size.x = 580
	next_step.add_theme_constant_override("outline_size", 6)
	alert = _label(content, "", 19, TITLE)
	_float_text(alert)
	alert.add_theme_color_override("font_color", Color("#ff9a72"))
	play.visibility_changed.connect(
		func() -> void:
			if play.visible:
				show_title()
	)
	_wallet_balance = _label(play, "", 20, TITLE)
	_wallet_balance.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_wallet_balance.offset_left = -320
	_wallet_balance.offset_right = -106
	_wallet_balance.offset_top = 26
	_wallet_balance.offset_bottom = 67
	_wallet_balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_wallet_balance.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_float_text(_wallet_balance)
	_wallet_balance.add_theme_color_override("font_color", Color("#ffda7a"))
	_pause = _button(play, "", "menu")
	_pause.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_pause.offset_left = -90
	_pause.offset_top = 14
	_pause.offset_right = -18
	_pause.offset_bottom = 76
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		_pause.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var middle := CenterContainer.new()
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause.add_child(middle)
	middle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bars := VBoxContainer.new()
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bars.add_theme_constant_override("separation", 4)
	middle.add_child(bars)
	for bar_index in range(3):
		var bar := Panel.new()
		var bar_style := StyleBoxFlat.new()
		bar_style.bg_color = Color("#fff2d6")
		bar_style.border_color = Color("#1c1410")
		bar_style.set_border_width_all(2)
		bar_style.set_corner_radius_all(3)
		bar.add_theme_stylebox_override("panel", bar_style)
		bar.custom_minimum_size = Vector2(40, 11)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bars.add_child(bar)
	var bottom := HBoxContainer.new()
	_controls = bottom
	play.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -123
	bottom.offset_left = 19
	bottom.offset_right = -19
	bottom.offset_bottom = -11
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(joystick)
	_zone_panel = PanelContainer.new()
	_zone_panel.add_theme_stylebox_override("panel", _style(FILL, EDGE))
	play.add_child(_zone_panel)
	_zone_panel.anchor_left = 1.0
	_zone_panel.anchor_right = 1.0
	_zone_panel.anchor_top = 1.0
	_zone_panel.anchor_bottom = 1.0
	_zone_panel.offset_left = -250
	_zone_panel.offset_right = -16
	_zone_panel.offset_top = -60
	_zone_panel.offset_bottom = -16
	_zone_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_zone_panel.hide()
	var zone_box := VBoxContainer.new()
	zone_box.add_theme_constant_override("separation", 6)
	_zone_panel.add_child(zone_box)
	_zone_title = _label(zone_box, "", 24, TITLE)
	_zone_title.add_theme_color_override("font_color", INK)
	_zone_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var buttons := VBoxContainer.new()
	_zone_buttons = buttons
	zone_box.add_child(buttons)
	action_button = _button(buttons, "Acción", "action")
	action_button.custom_minimum_size = Vector2(200, 50)
	_emphasize(action_button)
	release_button = _button(buttons, "Soltar / pasar", "release")
	release_button.custom_minimum_size = Vector2(200, 50)
	jump_button = _button(play, "Saltar", "jump")
	jump_button.custom_minimum_size = Vector2(110, 56)
	_emphasize(jump_button)
	jump_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	jump_button.offset_left = -382
	jump_button.offset_right = -266
	jump_button.offset_top = -78
	jump_button.offset_bottom = -16
	play.hide()


func _build_menu(root: Control) -> void:
	menu = PanelContainer.new()
	root.add_child(menu)
	menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	menu.offset_left = -267
	menu.offset_right = 267
	menu.offset_top = -292
	menu.offset_bottom = 292
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	menu.add_child(content)
	_heading = _label(content, "", 43, TITLE)
	_message = _label(content, "", 22)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)


func _build_lobby_backdrop(root: Control) -> void:
	_lobby_backdrop = Control.new()
	_lobby_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_lobby_backdrop)
	_lobby_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var poster := TextureRect.new()
	poster.texture = preload("res://assets/cinematica/artemis-luna.png")
	poster.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	poster.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	poster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lobby_backdrop.add_child(poster)
	poster.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.3, 0.67, 1.0])
	gradient.colors = PackedColorArray(
		[Color("#111117ec"), Color("#1111179c"), Color("#11111700"), Color("#11111700")]
	)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 512
	texture.height = 2
	var shade := TextureRect.new()
	shade.texture = texture
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lobby_backdrop.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var replay := LunarOpening.corner_button("Repetir intro")
	_lobby_backdrop.add_child(replay)
	replay.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	replay.offset_left = -176
	replay.offset_right = -24
	replay.offset_top = 20
	replay.offset_bottom = 68
	replay.pressed.connect(func() -> void: selected.emit("title_replay", ""))
	_lobby_backdrop.hide()


func hide_lobby() -> void:
	_lobby_backdrop.hide()
	menu.hide()


func loading(base_name: String, status: String, progress: float) -> void:
	_prepare_menu(base_name, status)
	menu.offset_top = -106
	menu.offset_bottom = 109
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = 34
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.value = progress
	bar.add_theme_stylebox_override("background", _style(Color("#c09a7c"), EDGE))
	bar.add_theme_stylebox_override("fill", _style(TEAL, Color("#18443e")))
	_list.add_child(bar)


func flight_status(phase: int, progress: float) -> void:
	var flying := phase >= 0
	_controls.visible = not flying
	if flying:
		_zone_panel.hide()
	_pause.visible = not flying
	_wallet_balance.visible = not flying
	_resources.visible = not flying
	details.visible = flying
	if not flying:
		return
	location.text = [
		"Ascenso desde la Luna",
		"Acoplamiento en órbita",
		"Rumbo a la Tierra",
		"Regreso a la Tierra"
	][phase]
	details.text = "Etapa %d de 4  ·  %d %%" % [phase + 1, roundi(progress * 100)]
	next_step.text = [
		"La etapa de ascenso se separa. La base de descenso queda en la Luna.",
		"La tripulación pasa al módulo de mando tras acoplarse.",
		"El módulo de servicio impulsa la nave hacia la Tierra.",
		"La cápsula de mando se separa y entra en la atmósfera."
	][phase]
	alert.hide()


func lobby(profile: LunarProfile, status: String) -> void:
	var subtitle := "ÚLTIMA VENTANA"
	if not status.is_empty():
		subtitle += "\n" + status
	_prepare_menu("ARTEMIS", subtitle)
	_lobby_backdrop.show()
	menu.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	menu.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	menu.offset_left = 58
	menu.offset_right = 454
	menu.offset_top = 61
	menu.offset_bottom = -28
	_heading.modulate = Color.WHITE
	_heading.add_theme_color_override("font_color", Color("#fff0cf"))
	_heading.rotation = -0.037
	_heading.add_theme_font_size_override("font_size", 120)
	_message.add_theme_color_override("font_color", Color("#fff0cf"))
	_message.add_theme_font_size_override("font_size", 18)

	var solo := _lobby_button(_list, "Jugar solo · sin conexión", "bases", "solo", true)
	_lobby_button(_list, "Crear partida en línea", "bases", "host")

	var join_controls := HBoxContainer.new()
	join_controls.add_theme_constant_override("separation", 8)
	_list.add_child(join_controls)
	address = LineEdit.new()
	address.custom_minimum_size.y = 48
	address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	address.add_theme_font_size_override("font_size", 17)
	address.max_length = 100
	address.placeholder_text = "Dirección del anfitrión"
	address.text_submitted.connect(func(_text: String) -> void: selected.emit("join", ""))
	join_controls.add_child(address)
	_lobby_button(join_controls, "Unirme", "join")

	var extras := HBoxContainer.new()
	extras.add_theme_constant_override("separation", 18)
	_list.add_child(extras)
	var roles := LunarOpening.corner_button("Roles")
	var archive := LunarOpening.corner_button("Archivo científico")
	for link in [roles, archive]:
		link.custom_minimum_size = Vector2(110, 48)
		extras.add_child(link)
	roles.pressed.connect(func() -> void: selected.emit("roles", ""))
	archive.pressed.connect(func() -> void: selected.emit("science", ""))
	var balance := _label(_list, "%s monedas" % profile.balance_text(), 16)
	balance.add_theme_color_override("font_color", Color("#fff0cf"))
	solo.grab_focus()


func _lobby_button(
	parent: Control, caption: String, action: String, argument := "", primary := false
) -> Button:
	var button := _button(parent, caption, action, argument)
	button.custom_minimum_size.y = 48
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_override("font", TITLE)
	button.add_theme_font_size_override("font_size", 24)
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		button.add_theme_color_override(state, Color("#251911"))
	var paper := Color("#ffd05b") if primary else Color("#e6c9a0")
	for state in ["normal", "hover", "pressed", "focus"]:
		var fill := paper
		if state == "hover":
			fill = paper.lightened(0.26)
		elif state == "pressed":
			fill = paper.darkened(0.13)
		var sign := _style(fill, Color("#4e3624"))
		sign.set_corner_radius_all(2)
		sign.skew = Vector2(-0.12, 0.0)
		if state == "focus":
			sign.bg_color = Color.TRANSPARENT
			sign.border_color = Color("#fff0cf")
			sign.shadow_size = 0
			sign.set_border_width_all(2)
		button.add_theme_stylebox_override(state, sign)
	return button


func bases(profile: LunarProfile, mode: String, notice: String = "") -> void:
	var single_player := mode == "solo"
	var title := "JUGAR SOLO" if single_player else "CREAR PARTIDA EN LÍNEA"
	_prepare_menu(title, "%s monedas · Elige una base lunar." % profile.balance_text())
	var spots: Array[Dictionary] = []
	var focus := String(profile.data.recent)
	if focus.is_empty() or not profile.open_base(focus):
		focus = ""
		for id: String in profile.rules.bases:
			if profile.open_base(id):
				focus = id
				break
	var order := 0
	_button(_list, "Volver", "lobby")
	for id: String in profile.rules.bases:
		order += 1
		var entry: Dictionary = profile.rules.bases[id]
		var difficulty: String = profile.rules.difficulties[entry.difficulty].label
		_label(_list, entry.terrain, 20).modulate = SOFT
		var owned := profile.open_base(id)
		var has_save := profile.saved_bases(single_player).has(id)
		var suffix := " · partida guardada" if has_save else ""
		if not owned:
			suffix = " · %d monedas" % entry.cost
		var caption := "%s · %s%s" % [entry.name, difficulty, suffix]
		_button(_list, caption, mode if owned else "buy_base", id)
		if has_save:
			_button(_list, "Reiniciar %s…" % entry.name, "reset_confirm", id)
		var note := "%s · misión nueva" % difficulty
		var resume := ""
		if id == focus and owned and not has_save:
			note = "%s · empieza aquí" % difficulty
		if not owned:
			note = "%s - %d" % [difficulty, entry.cost]
		elif has_save:
			var slot: Dictionary = profile.saved_bases(single_player)[id]
			var day := int(slot.get("active", {}).get("days", 0)) + 1
			note = "%s · guardada" % difficulty
			resume = "Continuar día %d" % day
		spots.append(
			{
				"id": id,
				"name": String(entry.name),
				"note": note,
				"owned": owned,
				"priced": not owned,
				"saved": owned and has_save,
				"resume": resume,
				"order": order,
				"focus": id == focus,
				"action": mode if owned else "buy_base"
			}
		)
	menu.hide()
	globe.show_bases(title, profile.balance_text(), spots, notice)
	globe.face_base(focus)


func roles(profile: LunarProfile) -> void:
	_prepare_menu(
		"ROLES", "%s monedas · Un rol por partida. Elige antes de entrar." % profile.balance_text()
	)
	_button(_list, "Volver", "lobby")
	for id in ["", "engineer", "botanist", "geologist"]:
		var entry: Dictionary = profile.rules.roles.get(id, {"label": "Sin rol"})
		var owned: bool = id.is_empty() or id in profile.data.roles
		var picked: bool = id == profile.data.active_role
		var suffix := " · elegido" if picked else ("" if owned else " · 250 monedas")
		_button(_list, entry.label + suffix, "choose_role" if owned else "buy_role", id)
		var description: Dictionary = {
			"engineer": "Montaje un 10% más rápido",
			"botanist": "Una ración extra cada 5 cosechas",
			"geologist": "Una caja extra cada 10 extracciones"
		}
		if description.has(id):
			_label(_list, description[id], 20).modulate = SOFT


func wait_for_guest(base_name: String, host_address: String, status: String) -> void:
	_prepare_menu(
		base_name, "Comparte esta dirección con tu compañero.\n%s\n%s" % [host_address, status]
	)
	_button(_list, "Volver al inicio", "leave")


func session_menu(mode: StringName, status: String = "") -> void:
	var note := "Partida en pausa." if mode == &"solo" else "La base sigue en actividad."
	_prepare_menu("OPCIONES", status if not status.is_empty() else note)
	_button(_list, "Volver a la partida", "back_to_play")
	_button(_list, "Archivo científico", "science")
	_button(_list, "Salir de la partida" if mode == &"guest" else "Guardar y salir", "leave")


func show_science(record_title: String, description: String, index: int, count: int) -> void:
	_prepare_menu("ARCHIVO CIENTÍFICO", "%02d/%02d · %s" % [index + 1, count, record_title])
	_button(_list, "Volver", "close_science")
	var card := _label(_list, description, 22)
	card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button(_list, "Ficha anterior", "previous_science")
	_button(_list, "Ficha siguiente", "next_science")


func confirm_reset(base_name: String, id: String) -> void:
	_prepare_menu(
		"¿Reiniciar esta base?",
		"%s perderá sus días y mejoras. Tus monedas globales se conservan." % base_name
	)
	_button(_list, "Cancelar", "bases")
	_button(_list, "Reiniciar base", "reset", id)


func show_balance(balance: String) -> void:
	_wallet_balance.text = "%s monedas" % balance


func playing() -> void:
	hide_lobby()
	if globe != null:
		globe.hide()
	play.show()


func sync(
	mission: LunarMission,
	player: int,
	spot: StringName,
	sheltered: Array[bool],
	message: String,
	point: Vector3
) -> void:
	var night := mission.shadow_active()
	var cycle := "%s %d" % ["Noche" if night else "Día", mission.days + 1]
	location.text = "%s\n%s" % [cycle, mission.base.name]
	var cold := ["", ""]
	for person in range(2):
		if night and not sheltered[person] and mission.connected[person]:
			cold[person] = " ❄"
	var air_caption := "" if mission.solo else "J1 "
	_readouts[0].text = "%s%d%s" % [air_caption, ceili(mission.pilots[0].air), cold[0]]
	_readouts[1].get_parent().get_parent().visible = not mission.solo
	if not mission.solo:
		var air := (
			"%d%s" % [ceili(mission.pilots[1].air), cold[1]] if mission.connected[1] else "ausente"
		)
		_readouts[1].text = "J2 " + air
	_readouts[2].text = "%.1f/%.0f" % [mission.charge, mission.battery_capacity()]
	_readouts[3].text = "%.1f" % mission.water
	_readouts[4].text = "%d" % ceili(mission.pilots[player].hunger)
	release_button.text = "Soltar / entregar" if mission.solo else "Soltar / pasar"
	var flight: Dictionary = mission.rules.mission
	if mission.phase == &"tutorial":
		if mission.solo:
			next_step.text = (
				"Acércate a la mesa azul y toma la muestra."
				if mission.tutorial_step == 0
				else "Lleva la muestra a la mesa y toca Soltar / entregar."
			)
		else:
			next_step.text = PROMPTS[mission.tutorial_step][1]
	elif mission.returned:
		next_step.text = "Regreso a Tierra completado. Puedes seguir jugando en la base."
	else:
		next_step.text = (
			"Propelente %d/%d   ·   Raciones %d/%d   ·   Radio %s   ·   A bordo %d/%d"
			% [
				mission.fuel_loaded,
				flight.propellant,
				mission.food_loaded,
				flight.food,
				"lista" if mission.earth_ok else "pendiente",
				mission.crew_seated(),
				mission.required_seats()
			]
		)
	_show_alert(mission)
	var deposit := String(spot).begins_with("dep:")
	var named: StringName = mission.deposit_kind(spot) if deposit else spot
	feedback.text = message
	feedback.visible = not message.is_empty() and mission.phase != &"flight"
	var carrying: bool = mission.pilots[player].cargo != 0
	var seated: bool = mission.pilots[player].seated
	var spot_name := String(CrestWorld.NAMES.get(named, ""))
	var tapped := Time.get_ticks_msec() < _tapped_until and not _tapped_name.is_empty()
	var crate: int = 0 if carrying or seated else mission.closest_crate(point)
	var actionable := not spot_name.is_empty() or carrying or seated or crate != 0
	_zone_buttons.visible = actionable
	_zone_panel.visible = actionable or tapped
	if not spot_name.is_empty():
		_zone_title.text = spot_name
	elif carrying or seated:
		_zone_title.text = "Llevas carga" if carrying else "A bordo"
	elif crate != 0:
		_zone_title.text = CRATE_NAMES.get(mission.crates[crate].kind, "Caja")
	else:
		_zone_title.text = _tapped_name
	action_button.text = _action_caption(named)
	if deposit and mission.deposit_left(spot) <= 0:
		action_button.text = "Depósito vacío"
	if seated:
		action_button.text = "Bajar"
	if mission.phase == &"tutorial" and spot == &"training":
		if mission.solo:
			action_button.text = (
				"Tomar muestra" if mission.tutorial_step == 0 else "Entregar muestra"
			)
		elif mission.tutorial_step == 2 and player == 1:
			action_button.text = "Entregar muestra"
	if crate != 0:
		action_button.text = "Recoger caja"


func _show_alert(mission: LunarMission) -> void:
	alert.show()
	if mission.storm_active():
		alert.text = "⚠ Partículas solares   ·   Entra al refugio"
	elif mission.storm_warning() > 0:
		alert.text = "⚠ Al refugio en %d s" % ceili(mission.storm_warning())
	elif mission.energy_cut():
		alert.text = "⚡ Apagón nocturno   ·   Taller y cultivo en pausa"
	elif mission.outage_warning() > 0:
		alert.text = "⚡ Apagón en %d s" % ceili(mission.outage_warning())
	elif mission.phase == &"countdown":
		alert.text = "Despegue en %d s" % ceili(mission.countdown)
	elif mission.radio_cut():
		alert.text = "Radio sin señal"
	elif mission.radio_warning():
		alert.text = "Se aproxima un corte de radio"
	else:
		alert.hide()


func _action_caption(spot: StringName) -> String:
	return String(
		(
			{
				&"ice": "Extraer hielo",
				&"ore": "Extraer mineral",
				&"refinery": "Usar taller",
				&"life": "Comer / aire",
				&"radio": "Usar radio",
				&"pad": "Cargar / subir",
				&"crop": "Cultivar / recoger",
				&"fuel": "Preparar / recoger",
				&"power": "Prioridad"
			}
			. get(spot, "Acción")
		)
	)


func _prepare_menu(title: String, status: String) -> void:
	joystick.clear()
	play.hide()
	if globe != null:
		globe.hide()
	_lobby_backdrop.hide()
	menu.remove_theme_stylebox_override("panel")
	_heading.rotation = 0.0
	_heading.remove_theme_color_override("font_color")
	_message.remove_theme_color_override("font_color")
	menu.show()
	menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	menu.offset_left = -270
	menu.offset_right = 270
	menu.offset_top = -295
	menu.offset_bottom = 295
	_heading.add_theme_font_size_override("font_size", 43)
	_message.add_theme_font_size_override("font_size", 22)
	_heading.modulate = BRICK
	_heading.text = title
	_message.text = status
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()


func _button(parent: Control, caption: String, action: String, argument: String = "") -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(54, 50)
	button.focus_mode = Control.FOCUS_NONE
	parent.add_child(button)
	button.pressed.connect(func() -> void: selected.emit(action, argument))
	return button


func _emphasize(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _style(TEAL, Color("#163c38")))
	button.add_theme_stylebox_override("hover", _style(Color("#286f63"), TEAL))
	button.add_theme_stylebox_override("pressed", _style(Color("#183e39"), TEAL))


func _label(parent: Control, caption: String, font_size: int, font: Font = BODY) -> Label:
	var label := Label.new()
	label.text = caption
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func show_zone(zone_name: String) -> void:
	_tapped_name = zone_name
	_tapped_until = Time.get_ticks_msec() + 3000


func show_title() -> void:
	if _title_tween:
		_title_tween.kill()
	_title_tween = create_tween()
	_title_tween.tween_property(location, "modulate:a", 1.0, 0.25)
	_title_tween.tween_interval(3.5)
	_title_tween.tween_property(location, "modulate:a", 0.0, 0.8).set_trans(Tween.TRANS_SINE)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if play.visible and key.pressed and not key.echo and key.keycode == KEY_SPACE:
		selected.emit("jump", "")


func _input(event: InputEvent) -> void:
	if play == null or not play.visible:
		return
	var height := 1000.0
	if event is InputEventMouseButton:
		var click: InputEventMouseButton = event
		if click.pressed:
			height = click.position.y
	elif event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed:
			height = touch.position.y
	if height < 80.0:
		show_title()


func _float_text(label: Label) -> void:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color("#fff2d6"))
	label.add_theme_color_override("font_outline_color", Color("#1c1410"))
	label.add_theme_constant_override("outline_size", 8)


func _style(fill: Color, stroke: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = stroke
	style.set_border_width_all(2)
	style.border_width_bottom = 4
	style.set_corner_radius_all(7)
	style.shadow_color = Color("#231b2466")
	style.shadow_size = 4
	style.content_margin_left = 15.0
	style.content_margin_right = 15.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style
