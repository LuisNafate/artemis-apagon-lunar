class_name LunarOpening
extends Control

signal enter_requested
const CONFIG := "res://context_core/state_registry.json"
const DISPLAY := preload("res://assets/ui/fonts/BarlowCondensed-Bold.ttf")
const BODY := preload("res://assets/ui/fonts/Barlow-SemiBold.ttf")
const MONO := preload("res://assets/ui/fonts/IBMPlexMono-Medium.ttf")
const INK := Color("#121620")
const CREAM := Color("#f0e8d9")
const AMBER := Color("#ffbb79")
const CYAN := Color("#83d9ed")

var opening: Dictionary
var looping := false
var _poster: TextureRect
var _film: VideoStreamPlayer
var _caption: Label
var _chapter: Label
var _story: Button
var _play: Button
var _transitioning := false


func _ready() -> void:
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	opening = parsed.campaign_2026.opening
	_build()
	_show_film(false)
	_play.grab_focus()


func _process(_delta: float) -> void:
	if not looping and _film.is_playing():
		_update_caption()


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return
	var key_event := event as InputEventKey
	var key := key_event.physical_keycode if key_event.physical_keycode else key_event.keycode
	match key:
		KEY_ENTER, KEY_KP_ENTER:
			_play_game()
		KEY_ESCAPE:
			if not looping:
				_show_film(true)
		KEY_H:
			_show_film(false)
		_:
			return
	get_viewport().set_input_as_handled()


func _show_film(idle: bool) -> void:
	if _transitioning:
		return
	looping = idle
	_poster.visible = idle
	_film.stop()
	var path: String = opening.loop if idle else opening.flight
	_film.stream = load(path) if ResourceLoader.exists(path) else null
	_film.loop = idle
	if _film.stream:
		_film.play()
	elif not idle:
		_show_film(true)
		return
	_story.text = "Repetir historia  [H]" if idle else "Saltar al alunizaje  [Esc]"
	_update_caption()


func _update_caption() -> void:
	var active: Array = opening.captions[0]
	var seconds := float(opening.loop_starts_at) if looping else _film.stream_position
	for cue: Array in opening.captions:
		if seconds >= float(cue[0]):
			active = cue
	_chapter.text = active[1]
	_caption.text = active[2]


func _play_game() -> void:
	if _transitioning:
		return
	_transitioning = true
	_film.stop()
	enter_requested.emit()


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = INK
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_poster = TextureRect.new()
	_poster.texture = load(opening.poster) if ResourceLoader.exists(opening.poster) else null
	_poster.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_poster.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_poster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_poster)
	_poster.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_film = VideoStreamPlayer.new()
	_film.expand = true
	_film.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_film.finished.connect(func() -> void: _show_film(true))
	add_child(_film)
	_film.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	var header := _panel(Rect2(30, 26, 305, 104), Color("#121620eb"))
	_label(header, "ARTEMIS", Rect2(15, 7, 256, 24), MONO, 14, AMBER)
	_label(header, "Última ventana", Rect2(13, 24, 277, 64), DISPLAY, 46, CREAM)

	var footer := _panel(Rect2(30, 589, 1220, 104), Color("#121620f4"))
	_chapter = _label(footer, "", Rect2(19, 10, 675, 24), MONO, 14, CYAN)
	_caption = _label(footer, "", Rect2(19, 35, 657, 53), BODY, 22, CREAM)
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_story = _button(footer, Rect2(700, 26, 239, 50), false)
	_story.pressed.connect(func() -> void: _show_film(not looping))
	_play = _button(footer, Rect2(955, 26, 246, 50), true)
	_play.text = "Entrar al puesto  [Intro]"
	_play.pressed.connect(_play_game)


func _panel(bounds: Rect2, fill: Color) -> Panel:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.position = bounds.position
	panel.size = bounds.size
	panel.add_theme_stylebox_override("panel", _style(fill, Color("#41516a")))
	add_child(panel)
	return panel


func _style(color: Color, edge: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = edge
	style.set_border_width_all(1)
	return style


func _label(
	parent: Control, title: String, bounds: Rect2, font: Font, font_size: int, color: Color
) -> Label:
	var label := Label.new()
	label.text = title
	label.position = bounds.position
	label.size = bounds.size
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _button(parent: Control, bounds: Rect2, primary: bool) -> Button:
	var button := Button.new()
	button.position = bounds.position
	button.size = bounds.size
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", BODY)
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_color_override("font_color", INK if primary else CREAM)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_focus_color", INK if primary else CREAM)
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_stylebox_override("normal", _style(AMBER if primary else INK, AMBER))
	button.add_theme_stylebox_override("hover", _style(CREAM, CREAM))
	button.add_theme_stylebox_override("pressed", _style(CYAN, CYAN))
	var focus := _style(Color.TRANSPARENT, CYAN)
	focus.set_border_width_all(3)
	button.add_theme_stylebox_override("focus", focus)
	parent.add_child(button)
	return button
