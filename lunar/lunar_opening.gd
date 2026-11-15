class_name LunarOpening
extends Control

signal enter_requested

const CONFIG := "res://context_core/state_registry.json"
const BODY := preload("res://assets/ui/fonts/Barlow-SemiBold.ttf")
const MONO := preload("res://assets/ui/fonts/IBMPlexMono-Medium.ttf")
const CREAM := Color("#f5ecce")

var opening: Dictionary
var landing := false
var _film: VideoStreamPlayer
var _caption: Label
var _chapter: Label
var _skip: Button
var _transitioning := false


func _ready() -> void:
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	opening = parsed.campaign_2026.opening
	_build()
	_show_film(false)


func _process(_delta: float) -> void:
	if _film.is_playing():
		_update_caption()


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return
	var key_event := event as InputEventKey
	var key := key_event.physical_keycode if key_event.physical_keycode else key_event.keycode
	if key in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		_enter_menu()


func _show_film(is_landing: bool) -> void:
	if _transitioning:
		return
	landing = is_landing
	_film.stop()
	var path: String = opening.landing if landing else opening.flight
	_film.stream = load(path) if ResourceLoader.exists(path) else null
	if _film.stream:
		_film.play()
		_update_caption()
	else:
		_advance.call_deferred()


func _advance() -> void:
	if landing:
		_enter_menu()
	else:
		_show_film(true)


func _update_caption() -> void:
	var active: Array = opening.captions[0]
	var seconds := _film.stream_position
	if landing:
		seconds += float(opening.landing_starts_at)
	for cue: Array in opening.captions:
		if seconds >= float(cue[0]):
			active = cue
	_chapter.text = active[1]
	_caption.text = active[2]


func _enter_menu() -> void:
	if _transitioning:
		return
	_transitioning = true
	_film.stop()
	enter_requested.emit()


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("#121620")
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_film = VideoStreamPlayer.new()
	_film.expand = true
	_film.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_film.finished.connect(_advance)
	add_child(_film)
	_film.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	_skip = corner_button("Saltar")
	add_child(_skip)
	_skip.position = Vector2(24, 20)
	_skip.size = Vector2(100, 48)
	_skip.tooltip_text = "Saltar al menú (Esc)"
	_skip.pressed.connect(_enter_menu)

	var subtitles := PanelContainer.new()
	subtitles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shade := StyleBoxFlat.new()
	shade.bg_color = Color("#101017c9")
	shade.set_corner_radius_all(8)
	shade.content_margin_left = 20
	shade.content_margin_right = 20
	shade.content_margin_top = 10
	shade.content_margin_bottom = 10
	subtitles.add_theme_stylebox_override("panel", shade)
	add_child(subtitles)
	subtitles.set_anchors_and_offsets_preset(PRESET_CENTER_BOTTOM)
	subtitles.offset_left = -360
	subtitles.offset_right = 360
	subtitles.offset_top = -107
	subtitles.offset_bottom = -24
	var lines := VBoxContainer.new()
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subtitles.add_child(lines)
	_chapter = _subtitle(lines, MONO, 13, Color("#e9c478"))
	_caption = _subtitle(lines, BODY, 20, CREAM)
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _subtitle(parent: Control, font: Font, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


static func corner_button(caption: String) -> Button:
	var button := Button.new()
	button.text = caption
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", BODY)
	button.add_theme_font_size_override("font_size", 17)
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		button.add_theme_color_override(state, CREAM)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#14151a78") if state == "normal" else Color("#14151ad1")
		style.set_corner_radius_all(7)
		if state == "focus":
			style.bg_color = Color.TRANSPARENT
			style.border_color = CREAM
			style.set_border_width_all(2)
		button.add_theme_stylebox_override(state, style)
	return button
