class_name LunarInterface
extends CanvasLayer

signal selected(action: String, argument: String)

const TITLE := preload("res://assets/ui/fonts/BarlowCondensed-Bold.ttf")
const BODY := preload("res://assets/ui/fonts/Barlow-SemiBold.ttf")
const FILL := Color("#121d2df2")
const EDGE := Color("#364d65")
const SOFT := Color("#c8d7e8")
const PROMPTS := [
	["Toma la muestra", "El gato azul se acerca a la mesa y toca Acción."],
	["Pasa la caja", "Acércate a tu compañero y toca Soltar / pasar."],
	["Entrega la muestra", "El gato naranja vuelve a la mesa y toca Entregar."],
	["Empiecen juntos", "Toca Acción en la mesa para iniciar el día."]
]

var joystick := LunarTouch.new()
var play: Control
var menu: PanelContainer
var address: LineEdit
var action_button: Button
var details: Label
var location: Label
var alert: Label
var next_step: Label
var feedback: Label
var _heading: Label
var _message: Label
var _list: VBoxContainer


func build() -> void:
	var root := Control.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var design := Theme.new()
	design.default_font = BODY
	design.default_font_size = 22
	design.set_stylebox("panel", "PanelContainer", _style(FILL, EDGE))
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var fill := Color("#233d56") if state == "normal" else Color("#365879")
		if state == "disabled":
			fill = Color("#202937")
		design.set_stylebox(state, "Button", _style(fill, EDGE))
	root.theme = design
	_build_play(root)
	_build_menu(root)


func _build_play(root: Control) -> void:
	play = Control.new()
	root.add_child(play)
	play.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	play.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var header := PanelContainer.new()
	play.add_child(header)
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 16
	header.offset_right = -16
	header.offset_top = 12
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var content := VBoxContainer.new()
	header.add_child(content)
	location = _label(content, "", 30, TITLE)
	details = _label(content, "", 23)
	next_step = _label(content, "", 22)
	alert = _label(content, "", 25, TITLE)
	alert.modulate = CrestWorld.AMBER
	var pause := _button(play, "Menú", "menu")
	pause.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	pause.offset_left = -140
	pause.offset_top = 24
	pause.offset_right = -32
	pause.offset_bottom = 78
	var bottom := HBoxContainer.new()
	play.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -123
	bottom.offset_left = 19
	bottom.offset_right = -19
	bottom.offset_bottom = -11
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(joystick)
	feedback = _label(bottom, "", 23)
	feedback.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var buttons := VBoxContainer.new()
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(buttons)
	action_button = _button(buttons, "Acción", "action")
	action_button.custom_minimum_size = Vector2(210, 55)
	_button(buttons, "Soltar / pasar", "release").custom_minimum_size = Vector2(210, 55)
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


func lobby(profile: LunarProfile, status: String) -> void:
	_prepare_menu(
		"ARTEMIS · ÚLTIMA VENTANA",
		(
			"Elige una base o únete a otro astronauta.\nSaldo · %s monedas\n%s"
			% [profile.balance_text(), status]
		)
	)
	if not String(profile.data.recent).is_empty():
		_button(_list, "Continuar", "host", profile.data.recent)
	_button(_list, "Ver bases lunares", "bases")
	_button(_list, "Roles", "roles")
	address = LineEdit.new()
	address.custom_minimum_size.y = 52
	address.max_length = 100
	address.placeholder_text = "Dirección del anfitrión"
	_list.add_child(address)
	_button(_list, "Unirme a una partida", "join")
	_button(_list, "Archivo científico", "science")


func bases(profile: LunarProfile) -> void:
	_prepare_menu(
		"BASES LUNARES", "%s monedas · Elige dónde alojar tu partida." % profile.balance_text()
	)
	_button(_list, "Volver", "lobby")
	for id: String in profile.rules.bases:
		var entry: Dictionary = profile.rules.bases[id]
		var difficulty: String = profile.rules.difficulties[entry.difficulty].label
		_label(_list, entry.terrain, 20).modulate = SOFT
		var owned := profile.open_base(id)
		var has_save: bool = profile.data.bases.has(id)
		var suffix := " · partida guardada" if has_save else ""
		if not owned:
			suffix = " · %d monedas" % entry.cost
		var title := "%s · %s%s" % [entry.name, difficulty, suffix]
		_button(_list, title, "host" if owned else "buy_base", id)
		if has_save:
			_button(_list, "Reiniciar %s…" % entry.name, "reset_confirm", id)


func roles(profile: LunarProfile) -> void:
	_prepare_menu(
		"ROLES",
		"%s monedas · Un rol por partida. Elige antes de conectar." % profile.balance_text()
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


func session_menu(is_host: bool) -> void:
	_prepare_menu("OPCIONES", "La base sigue en actividad mientras este menú está abierto.")
	_button(_list, "Volver a la partida", "back_to_play")
	_button(_list, "Archivo científico", "science")
	_button(_list, "Guardar y salir" if is_host else "Salir de la partida", "leave")


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


func playing() -> void:
	menu.hide()
	play.show()


func sync(
	mission: LunarMission, player: int, spot: StringName, sheltered: Array[bool], message: String
) -> void:
	var night := mission.shadow_active()
	var cycle := "%s %d" % ["Noche" if night else "Día", mission.days + 1]
	location.text = "%s  ·  %s" % [mission.base.name, cycle]
	var cold := ["", ""]
	for person in range(2):
		if night and not sheltered[person] and mission.connected[person]:
			cold[person] = " ❄"
	var partner_air := (
		"%d%s" % [ceili(mission.pilots[1].air), cold[1]] if mission.connected[1] else "ausente"
	)
	details.text = (
		"Aire azul %d%s   ◇   naranja %s      Batería %.1f/%.0f      Agua %.1f      Hambre %d"
		% [
			ceili(mission.pilots[0].air),
			cold[0],
			partner_air,
			mission.charge,
			mission.battery_capacity(),
			mission.water,
			ceili(mission.pilots[player].hunger)
		]
	)
	var flight: Dictionary = mission.rules.mission
	if mission.phase == &"tutorial":
		next_step.text = PROMPTS[mission.tutorial_step][1]
	elif mission.returned:
		next_step.text = "Regreso a Tierra completado. Puedes seguir jugando en la base."
	else:
		next_step.text = (
			"Regreso a Tierra · Propelente %d/%d · Raciones %d/%d · Radio %s · A bordo %d/2"
			% [
				mission.fuel_loaded,
				flight.propellant,
				mission.food_loaded,
				flight.food,
				"lista" if mission.earth_ok else "pendiente",
				mission.crew_seated()
			]
		)
	_show_alert(mission)
	feedback.text = (
		message
		if not message.is_empty()
		else String(CrestWorld.NAMES.get(spot, "Toca el destino o usa el joystick"))
	)
	action_button.text = "Bajar" if mission.pilots[player].seated else _action_caption(spot)
	if mission.phase == &"tutorial" and mission.tutorial_step == 2 and player == 1:
		action_button.text = "Entregar muestra"


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
	menu.show()
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


func _label(parent: Control, caption: String, font_size: int, font: Font = BODY) -> Label:
	var label := Label.new()
	label.text = caption
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _style(fill: Color, stroke: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = stroke
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 15.0
	style.content_margin_right = 15.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style
