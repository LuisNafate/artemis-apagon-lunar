# gdlint: disable=max-file-lines
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
const COIN_ICON := preload("res://assets/ui/hud/moneda.png")
const LOGO := preload("res://assets/ui/titulo_artemis_gato.png")
const JUMP_ICON := preload("res://assets/ui/hud/saltar.png")
const LOGO_WAVES := preload("res://assets/ui/logo_ondas.gdshader")
const CHIP_FILL := Color("#ecd5a8")
const ROLE_CARDS := {
	"engineer": preload("res://assets/ui/roles/engineer.png"),
	"botanist": preload("res://assets/ui/roles/botanist.png"),
	"geologist": preload("res://assets/ui/roles/geologist.png")
}
const ROLE_PERKS := {
	"engineer": "Montaje un 10% más rápido",
	"botanist": "Una ración extra cada 5 cosechas",
	"geologist": "Una caja extra cada 10 extracciones"
}
const AIR_ICON := preload("res://assets/ui/hud/aire.png")
const STRENGTH := {"X": "muy fuerte", "M": "fuerte", "C": "mediana"}
const MONTHS := ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]
const CHIP_ICONS := [
	AIR_ICON,
	AIR_ICON,
	preload("res://assets/ui/hud/bateria.png"),
	preload("res://assets/ui/hud/agua.png"),
	preload("res://assets/ui/hud/hambre.png"),
	preload("res://assets/ui/hud/radiacion.png")
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
var _objective_hint: Label
var _drop_body: VBoxContainer
var _objective_marker: Button
var _title_tween: Tween
var _zone_panel: PanelContainer
var _zone_title: Label
var _zone_detail: Label
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
var _wallet_icon: TextureRect
var _logo: TextureRect
var _poster: TextureRect
var _sparks: CPUParticles2D
var _lobby_tweens: Array[Tween] = []
var _paper: Control
var _storm_edges: TextureRect
var _flash: ColorRect
var _flash_tween: Tween


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
	_build_storm_layers()
	_objective_marker = _button(play, "", "objective_route")
	_objective_marker.focus_mode = Control.FOCUS_NONE
	_objective_marker.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_objective_marker.custom_minimum_size = Vector2(196, 46)
	LunarButtonKit.apply(_objective_marker, &"seguimiento", 18)
	_objective_marker.tooltip_text = "Toca para caminar hasta el objetivo."
	_objective_marker.hide()
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
	_resources.columns = 6
	_resources.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play.add_child(_resources)
	_resources.position = Vector2(18, 8)
	_resources.add_theme_constant_override("h_separation", 12)
	_resources.add_theme_constant_override("v_separation", 0)
	var colors := [
		Color("#4d7fc4"),
		Color("#e0883a"),
		Color("#e0883a"),
		Color("#3f6fc0"),
		Color("#d8602f"),
		Color("#f4ad2e")
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
	# El objetivo y el siguiente paso van en un desplegable bajo los recursos para no
	# taparse con el panel de la zona ni con los botones de abajo.
	var drop := VBoxContainer.new()
	drop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drop.add_theme_constant_override("separation", 6)
	play.add_child(drop)
	drop.anchor_left = 0.0
	drop.anchor_right = 0.0
	drop.offset_left = 18
	drop.offset_right = 428
	drop.offset_top = 74
	drop.offset_bottom = 74
	drop.grow_vertical = Control.GROW_DIRECTION_END
	var drop_toggle := Button.new()
	drop_toggle.text = "Objetivo  +"
	drop_toggle.focus_mode = Control.FOCUS_NONE
	drop_toggle.custom_minimum_size = Vector2(190, 42)
	drop_toggle.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	LunarButtonKit.apply(drop_toggle, &"seguimiento", 16)
	drop.add_child(drop_toggle)
	_drop_body = VBoxContainer.new()
	_drop_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drop_body.add_theme_constant_override("separation", 6)
	drop.add_child(_drop_body)
	_drop_body.hide()
	drop_toggle.pressed.connect(
		func() -> void:
			_drop_body.visible = not _drop_body.visible
			drop_toggle.text = "Objetivo  -" if _drop_body.visible else "Objetivo  +"
	)
	_objective_hint = _label(_drop_body, "", 17)
	_objective_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_float_text(_objective_hint)
	_objective_hint.add_theme_constant_override("outline_size", 2)
	_objective_hint.add_theme_stylebox_override("normal", _tag_style(Color("#e8821c")))
	_objective_hint.hide()
	next_step = _label(_drop_body, "", 16)
	next_step.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_float_text(next_step)
	next_step.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_step.custom_minimum_size.x = 410
	next_step.add_theme_constant_override("outline_size", 2)
	next_step.add_theme_stylebox_override("normal", _tag_style(Color("#47c9c4")))
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
	_wallet_balance.offset_left = -310
	_wallet_balance.offset_right = -128
	_wallet_balance.offset_top = 26
	_wallet_balance.offset_bottom = 67
	_wallet_balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_wallet_balance.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_float_text(_wallet_balance)
	_wallet_icon = TextureRect.new()
	_wallet_icon.texture = COIN_ICON
	_wallet_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_wallet_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_wallet_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play.add_child(_wallet_icon)
	_wallet_icon.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_wallet_icon.offset_left = -144
	_wallet_icon.offset_right = -98
	_wallet_icon.offset_top = 20
	_wallet_icon.offset_bottom = 66
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
	_zone_panel.offset_left = -456
	_zone_panel.offset_right = -124
	_zone_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
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
	_zone_detail = _label(zone_box, "", 17)
	_zone_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_zone_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zone_detail.add_theme_color_override("font_color", INK)
	var buttons := VBoxContainer.new()
	_zone_buttons = buttons
	zone_box.add_child(buttons)
	action_button = _button(buttons, "Acción", "action")
	action_button.custom_minimum_size = Vector2(240, 50)
	release_button = _button(buttons, "Soltar / pasar", "release")
	release_button.custom_minimum_size = Vector2(240, 50)
	for zone_button: Button in [action_button, release_button]:
		zone_button.add_theme_font_size_override("font_size", 16)
		zone_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	jump_button = _button(play, "", "jump")
	jump_button.custom_minimum_size = Vector2(88, 88)
	LunarButtonKit.apply(jump_button, &"mejorar")
	jump_button.icon = JUMP_ICON
	jump_button.expand_icon = true
	jump_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	jump_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	jump_button.add_theme_constant_override("icon_max_width", 44)
	jump_button.tooltip_text = "Saltar"
	jump_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	jump_button.offset_left = -108
	jump_button.offset_right = -16
	jump_button.offset_top = -104
	jump_button.offset_bottom = -16
	play.move_child(_objective_marker, -1)
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
	_logo = TextureRect.new()
	_logo.texture = LOGO
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo.custom_minimum_size = Vector2(520.0, 230.0)
	var waves := ShaderMaterial.new()
	waves.shader = LOGO_WAVES
	_logo.material = waves
	content.add_child(_logo)
	content.move_child(_logo, 1)
	_logo.hide()
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
	_poster = poster
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

	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.25, 0.75, 1.0])
	fade.colors = PackedColorArray(
		[Color("#ffe9b000"), Color("#ffe9b0d0"), Color("#ffe9b0d0"), Color("#ffe9b000")]
	)
	_sparks = CPUParticles2D.new()
	_sparks.amount = 60
	_sparks.lifetime = 16.0
	_sparks.preprocess = 16.0
	_sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_sparks.emission_rect_extents = Vector2(640.0, 8.0)
	_sparks.direction = Vector2(0.18, -1.0)
	_sparks.spread = 14.0
	_sparks.gravity = Vector2.ZERO
	_sparks.initial_velocity_min = 16.0
	_sparks.initial_velocity_max = 44.0
	_sparks.scale_amount_min = 1.5
	_sparks.scale_amount_max = 4.5
	_sparks.color_ramp = fade
	_lobby_backdrop.add_child(_sparks)

	var replay := LunarOpening.corner_button("Repetir intro")
	_lobby_backdrop.add_child(replay)
	_pop_on_hover(replay)
	replay.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	replay.offset_left = -176
	replay.offset_right = -24
	replay.offset_top = 20
	replay.offset_bottom = 68
	replay.pressed.connect(func() -> void: selected.emit("title_replay", ""))
	_lobby_backdrop.hide()


func hide_lobby() -> void:
	_close_dossier()
	_lobby_backdrop.hide()
	menu.hide()


func dossier(profile: LunarProfile) -> void:
	_prepare_menu("", "")
	menu.hide()
	var sheet := LunarDossier.new()
	menu.get_parent().add_child(sheet)
	sheet.build(profile)
	sheet.closed.connect(func() -> void: selected.emit("close_dossier", ""))
	_paper = sheet


func _close_dossier() -> void:
	if _paper != null:
		_paper.queue_free()
		_paper = null


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
	_wallet_icon.visible = not flying
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
	details.text = LunarLanguage.t("Etapa %d de 4  ·  %d %%") % [phase + 1, roundi(progress * 100)]
	next_step.text = [
		"La etapa de ascenso se separa. La base de descenso queda en la Luna.",
		"La tripulación pasa al módulo de mando tras acoplarse.",
		"El módulo de servicio impulsa la nave hacia la Tierra.",
		"La cápsula de mando se separa y entra en la atmósfera."
	][phase]
	alert.hide()


func lobby(profile: LunarProfile, status: String) -> void:
	var subtitle := "ÚLTIMA VENTANA"
	if profile.campaign_finished():
		subtitle += LunarLanguage.t("\nCampaña completada")
	if not status.is_empty():
		subtitle += "\n" + status
	_prepare_menu("ARTEMIS", subtitle)
	_lobby_backdrop.show()
	_start_backdrop()
	menu.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	menu.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	menu.offset_left = 58
	menu.offset_right = 454
	menu.offset_top = 61
	menu.offset_bottom = -28
	_heading.modulate = Color.WHITE
	_heading.add_theme_color_override("font_color", Color("#fff0cf"))
	_heading.hide()
	_logo.show()
	_message.add_theme_color_override("font_color", Color("#fff0cf"))
	_message.add_theme_font_size_override("font_size", 18)

	var solo := _lobby_button(_list, "Jugar", "bases", "solo", true)
	var recent := String(profile.data.recent)
	if profile.data.recent_mode == "solo" and profile.saved_bases(true).has(recent):
		_lobby_button(_list, "Continuar misión", "solo", recent)
	address = null
	if profile.rules.solo_mode.get("show_online", true):
		_online_choices()

	var extras := HBoxContainer.new()
	extras.add_theme_constant_override("separation", 18)
	_list.add_child(extras)
	var roles := LunarOpening.corner_button("Roles")
	var archive := LunarOpening.corner_button("Archivo científico")
	for link in [roles, archive]:
		link.custom_minimum_size = Vector2(150, 50)
		LunarButtonKit.apply(link, &"soltar", 20)
		extras.add_child(link)
		_animate_button(link, _list.get_child_count() + 1, false)
	roles.pressed.connect(func() -> void: selected.emit("roles", ""))
	archive.pressed.connect(func() -> void: selected.emit("science", ""))
	var wallet := HBoxContainer.new()
	wallet.add_theme_constant_override("separation", 8)
	_list.add_child(wallet)
	var coin := TextureRect.new()
	coin.texture = COIN_ICON
	coin.custom_minimum_size = Vector2(38.0, 38.0)
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.pivot_offset = Vector2(19.0, 19.0)
	wallet.add_child(coin)
	var balance := _label(wallet, LunarLanguage.t("%s monedas") % profile.balance_text(), 22, TITLE)
	_float_text(balance)
	balance.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var spin := coin.create_tween().set_loops()
	spin.tween_interval(1.8)
	spin.tween_property(coin, "scale:x", 0.12, 0.28).set_trans(Tween.TRANS_SINE)
	spin.tween_property(coin, "scale:x", 1.0, 0.28).set_trans(Tween.TRANS_SINE)
	_animate_lobby()
	solo.grab_focus()


func _online_choices() -> void:
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


func _lobby_button(
	parent: Control, caption: String, action: String, argument := "", primary := false
) -> Button:
	var button := _button(parent, caption, action, argument)
	button.custom_minimum_size.y = 48
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	LunarButtonKit.apply(button, &"mejorar" if primary else &"accion", 26)
	_animate_button(button, _list.get_child_count(), primary)
	return button


func _animate_button(button: Button, index: int, primary: bool) -> void:
	button.pivot_offset = Vector2(0.0, 24.0)
	button.scale = Vector2(0.5, 1.0)
	button.modulate.a = 0.0
	var wait := 0.55 + index * 0.11
	var intro := button.create_tween().set_parallel(true)
	(
		intro
		. tween_property(button, "scale", Vector2.ONE, 0.55)
		. set_delay(wait)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	intro.tween_property(button, "modulate:a", 1.0, 0.3).set_delay(wait)
	_pop_on_hover(button)
	if primary:
		var glow := button.create_tween().set_loops()
		glow.tween_property(button, "self_modulate", Color(1.2, 1.12, 0.8), 0.8).set_trans(
			Tween.TRANS_SINE
		)
		glow.tween_property(button, "self_modulate", Color.WHITE, 0.8).set_trans(Tween.TRANS_SINE)


func _pop_on_hover(button: Control) -> void:
	var grow := Vector2(1.07, 1.07)
	button.mouse_entered.connect(func() -> void: _pop(button, grow, 0.18))
	button.mouse_exited.connect(func() -> void: _pop(button, Vector2.ONE, 0.18))
	button.focus_entered.connect(func() -> void: _pop(button, grow, 0.18))
	button.focus_exited.connect(func() -> void: _pop(button, Vector2.ONE, 0.18))
	var press := button as BaseButton
	if press != null:
		press.button_down.connect(func() -> void: _pop(button, Vector2(0.94, 0.94), 0.07))
		press.button_up.connect(func() -> void: _pop(button, grow, 0.12))


func _pop(button: Control, target: Vector2, time: float) -> void:
	if button.has_meta("pop"):
		var old: Tween = button.get_meta("pop")
		if old.is_valid():
			old.kill()
	var tween := button.create_tween()
	tween.tween_property(button, "scale", target, time).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)
	button.set_meta("pop", tween)


func _start_backdrop() -> void:
	var size := get_viewport().get_visible_rect().size
	_poster.pivot_offset = size * 0.5
	_poster.scale = Vector2.ONE
	var drift := create_tween().set_loops()
	drift.tween_property(_poster, "scale", Vector2(1.07, 1.07), 16.0).set_trans(Tween.TRANS_SINE)
	drift.tween_property(_poster, "scale", Vector2.ONE, 16.0).set_trans(Tween.TRANS_SINE)
	_lobby_tweens.append(drift)
	_sparks.position = Vector2(size.x * 0.5, size.y + 10.0)
	_sparks.emission_rect_extents = Vector2(size.x * 0.5, 8.0)
	_sparks.restart()
	_sparks.emitting = true


func _animate_lobby() -> void:
	_logo.pivot_offset = Vector2(0.0, 115.0)
	_logo.scale = Vector2(0.3, 0.3)
	_logo.rotation = -0.2
	_logo.modulate.a = 0.0
	var intro := create_tween().set_parallel(true)
	intro.tween_property(_logo, "scale", Vector2.ONE, 1.1).set_trans(Tween.TRANS_ELASTIC).set_ease(
		Tween.EASE_OUT
	)
	intro.tween_property(_logo, "rotation", -0.037, 0.9).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)
	intro.tween_property(_logo, "modulate:a", 1.0, 0.35)
	_lobby_tweens.append(intro)
	var sway := create_tween().set_loops()
	sway.tween_interval(1.2)
	sway.tween_property(_logo, "rotation", -0.055, 2.2).set_trans(Tween.TRANS_SINE)
	sway.tween_property(_logo, "rotation", -0.02, 2.2).set_trans(Tween.TRANS_SINE)
	_lobby_tweens.append(sway)
	_message.modulate.a = 0.0
	var reveal := create_tween()
	reveal.tween_property(_message, "modulate:a", 1.0, 0.6).set_delay(0.5)
	_lobby_tweens.append(reveal)
	var tagline := create_tween().set_loops()
	tagline.tween_property(_message, "self_modulate", Color(1, 1, 1, 0.6), 1.2).set_trans(
		Tween.TRANS_SINE
	)
	tagline.tween_property(_message, "self_modulate", Color.WHITE, 1.2).set_trans(Tween.TRANS_SINE)
	_lobby_tweens.append(tagline)


func bases(profile: LunarProfile, mode: String, notice: String = "") -> void:
	var single_player := mode == "solo"
	var title := "JUGAR SOLO" if single_player else "CREAR PARTIDA EN LÍNEA"
	_prepare_menu(title, LunarLanguage.t("%s monedas · Elige una base lunar.") % profile.balance_text())
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
		var difficulty: String = LunarLanguage.t(profile.rules.difficulties[entry.difficulty].label)
		_label(_list, entry.terrain, 20).modulate = SOFT
		var owned := profile.open_base(id)
		var has_save := profile.saved_bases(single_player).has(id)
		var suffix := LunarLanguage.t(" · partida guardada") if has_save else ""
		if not owned:
			suffix = LunarLanguage.t(" · %d monedas") % entry.cost
		var caption := "%s · %s%s" % [entry.name, difficulty, suffix]
		_button(_list, caption, mode if owned else "buy_base", id)
		if has_save:
			_button(_list, LunarLanguage.t("Reiniciar %s…") % entry.name, "reset_confirm", id)
		var note := LunarLanguage.t("%s · misión nueva") % difficulty
		var resume := ""
		if id == focus and owned and not has_save:
			note = LunarLanguage.t("%s · empieza aquí") % difficulty
		if not owned:
			note = "%s - %d" % [difficulty, entry.cost]
		elif has_save:
			var slot: Dictionary = profile.saved_bases(single_player)[id]
			var day := int(slot.get("active", {}).get("days", 0)) + 1
			note = LunarLanguage.t("%s · guardada") % difficulty
			resume = LunarLanguage.t("Continuar día %d") % day
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
		"ROLES", LunarLanguage.t("%s monedas · Un rol por partida. Elige antes de entrar.") % profile.balance_text()
	)
	menu.offset_left = -435.0
	menu.offset_right = 435.0
	menu.offset_top = -345.0
	menu.offset_bottom = 345.0
	var price := int(profile.rules.wallet.role_price)
	var coins := float(profile.data.balance) / float(LunarProfile.SCALE)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	_list.add_child(row)
	var index := 0
	for id in ["engineer", "botanist", "geologist"]:
		_role_card(row, profile, id, index, price, coins >= price)
		index += 1
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 18)
	_list.add_child(footer)
	var none_picked: bool = String(profile.data.active_role).is_empty()
	var none := _button(
		footer, "Sin rol · elegido" if none_picked else "Sin rol", "choose_role", ""
	)
	none.custom_minimum_size = Vector2(200, 50)
	var back := _button(footer, "Volver", "lobby")
	back.custom_minimum_size = Vector2(200, 50)


func _role_card(
	row: Control, profile: LunarProfile, id: String, index: int, price: int, can_afford: bool
) -> void:
	var owned: bool = id in profile.data.roles
	var picked: bool = id == profile.data.active_role
	var action := "choose_role" if owned else "buy_role"
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 6)
	card.pivot_offset = Vector2(120.0, 190.0)
	row.add_child(card)

	var art := Button.new()
	art.custom_minimum_size = Vector2(240.0, 340.0)
	art.focus_mode = Control.FOCUS_ALL
	art.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "pressed", "disabled"]:
		art.add_theme_stylebox_override(state, _card_frame(picked, false))
	for state in ["hover", "focus"]:
		art.add_theme_stylebox_override(state, _card_frame(picked, true))
	card.add_child(art)
	var picture := TextureRect.new()
	picture.texture = ROLE_CARDS[id]
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not owned:
		picture.modulate = Color(0.5, 0.48, 0.55)
	art.add_child(picture)
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture.offset_left = 4.0
	picture.offset_top = 4.0
	picture.offset_right = -4.0
	picture.offset_bottom = -4.0
	if not owned:
		var tag := HBoxContainer.new()
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.alignment = BoxContainer.ALIGNMENT_CENTER
		tag.add_theme_constant_override("separation", 6)
		art.add_child(tag)
		tag.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		tag.offset_left = -70.0
		tag.offset_right = 70.0
		tag.offset_top = -26.0
		tag.offset_bottom = 26.0
		var coin := TextureRect.new()
		coin.texture = COIN_ICON
		coin.custom_minimum_size = Vector2(44.0, 44.0)
		coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.add_child(coin)
		var cost := _label(tag, str(price), 40, TITLE)
		_float_text(cost)
	art.pressed.connect(func() -> void: selected.emit(action, id))

	var perk := _label(card, ROLE_PERKS[id], 17)
	perk.custom_minimum_size = Vector2(240.0, 48.0)
	perk.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	perk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	perk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	perk.modulate = SOFT
	var caption := "Elegido" if picked else ("Elegir" if owned else LunarLanguage.t("Comprar · %d") % price)
	var button := _button(card, caption, action, id)
	button.custom_minimum_size = Vector2(240.0, 50.0)
	button.focus_mode = Control.FOCUS_ALL
	if picked:
		LunarButtonKit.apply(button, &"construir")
	elif owned:
		LunarButtonKit.apply(button, &"accion")
	else:
		LunarButtonKit.apply(button, &"mejorar" if can_afford else &"bloqueado")
		button.icon = COIN_ICON
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 26)

	art.mouse_entered.connect(func() -> void: _pop(card, Vector2(1.04, 1.04), 0.18))
	art.mouse_exited.connect(func() -> void: _pop(card, Vector2.ONE, 0.18))
	card.scale = Vector2(0.6, 0.6)
	card.modulate.a = 0.0
	var wait := 0.08 + index * 0.12
	var intro := card.create_tween().set_parallel(true)
	(
		intro
		. tween_property(card, "scale", Vector2.ONE, 0.5)
		. set_delay(wait)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	intro.tween_property(card, "modulate:a", 1.0, 0.3).set_delay(wait)
	if picked:
		var glow := art.create_tween().set_loops()
		glow.tween_property(art, "self_modulate", Color(1.3, 1.2, 0.8), 0.8).set_trans(
			Tween.TRANS_SINE
		)
		glow.tween_property(art, "self_modulate", Color.WHITE, 0.8).set_trans(Tween.TRANS_SINE)


func _card_frame(picked: bool, hover: bool) -> StyleBoxFlat:
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color.TRANSPARENT
	frame.set_corner_radius_all(16)
	frame.set_border_width_all(6 if picked else (3 if hover else 0))
	frame.border_color = Color("#ffd05b") if picked else Color("#fff0cf")
	if picked:
		frame.shadow_color = Color("#ffd05b99")
		frame.shadow_size = 14
	return frame


func wait_for_guest(base_name: String, host_address: String, status: String) -> void:
	_prepare_menu(
		base_name, LunarLanguage.t("Comparte esta dirección con tu compañero.\n%s\n%s") % [host_address, status]
	)
	_button(_list, "Volver al inicio", "leave")


func session_menu(mode: StringName, status: String = "") -> void:
	var note := "Partida en pausa." if mode == &"solo" else "La base sigue en actividad."
	_prepare_menu("OPCIONES", status if not status.is_empty() else note)
	_button(_list, "Volver a la partida", "back_to_play")
	_button(_list, "Archivo científico", "science")
	_button(_list, "Salir de la partida" if mode == &"guest" else "Guardar y salir", "leave")


func show_science(record_title: String, description: String, index: int, count: int) -> void:
	_prepare_menu("", "")
	menu.hide()
	var archive := LunarArchive.new()
	menu.get_parent().add_child(archive)
	archive.build(record_title, description, index, count)
	archive.chosen.connect(func(action: String) -> void: selected.emit(action, ""))
	_paper = archive


func confirm_reset(base_name: String, id: String) -> void:
	_prepare_menu(
		"¿Reiniciar esta base?",
		LunarLanguage.t("%s perderá sus días y mejoras. Tus monedas globales se conservan.") % base_name
	)
	_button(_list, "Cancelar", "bases")
	_button(_list, "Reiniciar base", "reset", id)


func show_balance(balance: String) -> void:
	_wallet_balance.text = balance


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
	pickup: StringName = &""
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
	_show_dose(mission.dose_level(player))
	var flight: Dictionary = mission.rules.mission
	if mission.phase == &"tutorial":
		next_step.text = "" if mission.solo else PROMPTS[mission.tutorial_step][1]
	elif mission.returned:
		next_step.text = "Regreso a Tierra completado. Puedes seguir jugando en la base."
	else:
		next_step.text = (
			LunarLanguage.t("Propelente %d/%d   ·   Raciones %d/%d   ·   Radio %s   ·   A bordo %d/%d")
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
	_show_alert(mission, sheltered[player])
	feedback.text = message
	feedback.visible = not message.is_empty() and mission.phase != &"flight"
	_item_panel(mission, player, spot, pickup)


func _item_panel(mission: LunarMission, player: int, spot: StringName, pickup: StringName) -> void:
	var cargo := mission.cargo_kind(player)
	var seated: bool = mission.pilots[player].seated
	var named := mission.deposit_kind(spot) if String(spot).begins_with("dep:") else spot
	var caption := String(CrestWorld.NAMES.get(named, ""))
	var context := LunarItemContext.at(mission, player, spot, pickup)
	var tapped := Time.get_ticks_msec() < _tapped_until and not _tapped_name.is_empty()
	action_button.text = context[0]
	action_button.visible = not action_button.text.is_empty()
	action_button.disabled = context[2]
	release_button.visible = cargo != &"" and not seated
	if cargo != &"":
		var name: String = LunarItemContext.LOAD_NAMES[cargo]
		if LunarItemContext.delivers(mission, player, spot):
			release_button.text = LunarLanguage.t("Entregar %s") % name
		else:
			release_button.text = LunarLanguage.t("Soltar %s") % name if mission.solo else "Soltar / pasar"
	_zone_buttons.visible = action_button.visible or release_button.visible
	_zone_detail.text = context[1]
	_zone_detail.visible = not _zone_detail.text.is_empty()
	_zone_panel.visible = (
		mission.phase != &"flight" and (_zone_buttons.visible or _zone_detail.visible or tapped)
	)
	if pickup != &"":
		_zone_title.text = "CARGA EN EL SUELO"
	elif not caption.is_empty():
		_zone_title.text = caption
	elif cargo != &"":
		_zone_title.text = LunarLanguage.t("CARGA · %s") % String(LunarItemContext.LOAD_NAMES[cargo]).to_upper()
	elif seated:
		_zone_title.text = "A BORDO"
	else:
		_zone_title.text = _tapped_name


func show_objective(instruction: String, title: String = "", projected := Vector2.ZERO) -> void:
	_objective_hint.text = instruction
	_objective_hint.visible = not instruction.is_empty()
	_objective_marker.visible = not title.is_empty()
	if title.is_empty():
		return
	var bounds := play.size
	var marker_size := Vector2(196, 46)
	var ideal := projected - Vector2(marker_size.x * 0.5, 44)
	var safe := Rect2(Vector2(20, 112), bounds - Vector2(40, 300))
	var offset := ideal.clamp(safe.position, safe.end - marker_size)
	var difference := ideal - offset
	var arrow := "↓"
	if difference.length_squared() > 4:
		if absf(difference.x) > absf(difference.y):
			arrow = "→" if difference.x > 0 else "←"
		else:
			arrow = "↓" if difference.y > 0 else "↑"
	_objective_marker.text = "%s  %s" % [arrow, title]
	_objective_marker.position = offset
	_objective_marker.size = marker_size


## "Llamarada real del 10 sep 2017 · muy fuerte (X8.2)" a partir del catálogo DONKI.
static func flare_label(record: Dictionary) -> String:
	var date := String(record.begin)
	var month: String = MONTHS[int(date.substr(5, 2)) - 1]
	var kind := String(record.class_type)
	return (
		LunarLanguage.t("Llamarada real del %d %s %s · %s (%s)")
		% [int(date.substr(8, 2)), month, date.left(4), STRENGTH.get(kind.left(1), "pequeña"), kind]
	)


## Capas de la tormenta: bordes rojos mientras caen las partículas y un destello corto
## cuando el Sol lanza una llamarada. Quedan debajo del HUD y no reciben toques.
func _build_storm_layers() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.86, 0.13, 0.10, 0.0))
	gradient.set_color(1, Color(0.86, 0.13, 0.10, 0.62))
	gradient.add_point(0.6, Color(0.86, 0.13, 0.10, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	_storm_edges = TextureRect.new()
	_storm_edges.texture = texture
	_storm_edges.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_storm_edges.stretch_mode = TextureRect.STRETCH_SCALE
	_storm_edges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_storm_edges.modulate.a = 0.0
	play.add_child(_storm_edges)
	_storm_edges.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash = ColorRect.new()
	_flash.color = Color(1.0, 0.95, 0.82)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.modulate.a = 0.0
	play.add_child(_flash)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Un solo destello suave, sin parpadeos, cuando aparece una llamarada nueva.
func flash() -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	_flash.modulate.a = 0.45
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "modulate:a", 0.0, 0.6).set_trans(Tween.TRANS_SINE)


## Intensidad de los bordes rojos: 0 sin tormenta, 1 con partículas cayendo.
func storm_edges(level: float) -> void:
	_storm_edges.modulate.a = clampf(level, 0.0, 1.0)


## Dosímetro en el HUD: verde, amarillo desde la mitad y rojo al llenarse.
func _show_dose(level: float) -> void:
	var reading := _readouts[5]
	reading.text = "%d%%" % roundi(level * 100.0)
	var color := Color("#a6e389")
	if level >= 1.0:
		color = Color("#ff6f5c")
	elif level >= 0.5:
		color = Color("#ffd36b")
	reading.add_theme_color_override("font_color", color)


func _show_alert(mission: LunarMission, safe: bool) -> void:
	alert.show()
	alert.add_theme_color_override("font_color", Color("#ff9a72"))
	var flare := mission.storm_flare()
	var quiet := mission.flare_notice()
	var real := "" if flare.is_empty() else "\n" + flare_label(flare)
	if mission.storm_active():
		alert.text = (
			LunarLanguage.t("⚠ Lluvia de partículas del Sol · ")
			+ ("Estás a salvo aquí" if safe else "¡Entra al refugio!")
			+ real
		)
	elif mission.storm_warning() > 0:
		var seconds := ceili(mission.storm_warning())
		alert.text = LunarLanguage.t("☀ ¡Explosión en el Sol! Corre al refugio: %d s%s") % [seconds, real]
	elif not quiet.is_empty():
		alert.add_theme_color_override("font_color", Color("#ffd36b"))
		alert.text = (
			LunarLanguage.t("☀ Explosión en el Sol, pero sin partículas · ¡Sigue trabajando!\n") + flare_label(quiet)
		)
	elif mission.energy_cut():
		alert.text = "⚡ Apagón nocturno   ·   Taller y cultivo en pausa"
	elif mission.outage_warning() > 0:
		alert.text = LunarLanguage.t("⚡ Apagón en %d s") % ceili(mission.outage_warning())
	elif mission.phase == &"countdown":
		alert.text = LunarLanguage.t("Despegue en %d s") % ceili(mission.countdown)
	elif mission.radio_cut():
		alert.text = "Radio sin señal"
	elif mission.radio_warning():
		alert.text = "Se aproxima un corte de radio"
	else:
		alert.hide()


func _prepare_menu(title: String, status: String) -> void:
	_close_dossier()
	for tween in _lobby_tweens:
		tween.kill()
	_lobby_tweens.clear()
	_logo.hide()
	_logo.scale = Vector2.ONE
	_logo.rotation = 0.0
	_logo.modulate.a = 1.0
	_heading.show()
	_message.modulate.a = 1.0
	_message.self_modulate = Color.WHITE
	_sparks.emitting = false
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
	LunarButtonKit.apply(button, LunarButtonKit.kind_for(caption))
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


func _process(_delta: float) -> void:
	# La etiqueta de seguimiento solo se dibuja cuando tiene texto.
	if next_step != null:
		next_step.visible = not next_step.text.is_empty()


func _tag_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#14262cdd")
	style.border_color = accent
	style.set_border_width_all(2)
	style.border_width_left = 7
	style.set_corner_radius_all(9)
	style.corner_detail = 1
	style.shadow_color = Color("#00000077")
	style.shadow_size = 6
	style.shadow_offset = Vector2(0.0, 3.0)
	style.content_margin_left = 20.0
	style.content_margin_right = 16.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 7.0
	return style


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
