class_name LunarDossier
extends Control

# Expediente cientifico: hoja de papel vacia para escribir, dividida en secciones
# (datos de cabecera, notas, observaciones, tabla de datos y firma). Se guarda en el perfil.

signal closed

const TITLE := preload("res://assets/ui/fonts/BarlowCondensed-Bold.ttf")
const BODY := preload("res://assets/ui/fonts/Barlow-SemiBold.ttf")
const PAPER := Color("#f2e2c4")
const PAPER_EDGE := Color("#bf9a6f")
const SLATE := Color("#4a5f6e")
const INK := Color("#2c3a44")
const FADED := Color("#8b9aa3")
const TEAL := Color("#1f4a52")
const ORANGE := Color("#e8821c")
const CREAM := Color("#fff2d6")
const LINE := Color("#6f8089")
const COLUMNS := 4
const ROWS := 4
const NOTES_LIMIT := 4000
const HEADER_FIELDS := [
	["N.º EXP.", "exp", "001"],
	["ÁREA", "area", "Botánica, geología…"],
	["FECHA", "date", "AAAA-MM-DD"]
]
const COLUMN_HINTS := ["Dato", "Valor", "Unidad", "Hora"]

var _profile: LunarProfile
var _fields := {}
var _cells: Array[LineEdit] = []
var _status: Label


class RuledText:
	extends TextEdit

	func _draw() -> void:
		var pitch := float(get_line_height())
		if pitch < 8.0:
			return
		var shift := -fposmod(get_v_scroll(), 1.0) * pitch
		var y := 8.0 + pitch + shift - 4.0
		while y < size.y - 4.0:
			var from := Vector2(8.0, y)
			var to := Vector2(size.x - 8.0, y)
			draw_dashed_line(from, to, Color(0.43, 0.5, 0.54, 0.55), 1.0, 3.0)
			y += pitch


func build(profile: LunarProfile) -> void:
	_profile = profile
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color("#0c0f16ea")
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var sheet := PanelContainer.new()
	sheet.add_theme_stylebox_override("panel", _paper_style())
	add_child(sheet)
	sheet.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	sheet.offset_left = -400.0
	sheet.offset_right = 400.0
	sheet.offset_top = -345.0
	sheet.offset_bottom = 285.0
	for edge in [-353.0, 277.0]:
		var tab := Panel.new()
		tab.add_theme_stylebox_override("panel", _plate(ORANGE, Color("#8a4a0c"), 6))
		add_child(tab)
		tab.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		tab.offset_left = -80.0
		tab.offset_right = 80.0
		tab.offset_top = edge
		tab.offset_bottom = edge + 16.0

	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 16)
	sheet.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 14)
	scroll.add_child(page)

	_masthead(page)
	_header_row(page)
	_notes(page)
	_observations(page)
	_data_table(page)
	_signature(page)
	_buttons()
	_load()


func _masthead(page: VBoxContainer) -> void:
	var top := _label(page, "ARTEMIS · ÚLTIMA VENTANA", 18, BODY, SLATE)
	top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var banner := PanelContainer.new()
	banner.add_theme_stylebox_override("panel", _plate(TEAL, Color("#102a30"), 12))
	page.add_child(banner)
	var title := _label(banner, "EXPEDIENTE CIENTÍFICO", 40, TITLE, CREAM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _header_row(page: VBoxContainer) -> void:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _outline(12, Color.TRANSPARENT, 8))
	page.add_child(frame)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	frame.add_child(row)
	for entry: Array in HEADER_FIELDS:
		if row.get_child_count() > 0:
			row.add_child(VSeparator.new())
		_label(row, entry[0], 19, BODY, SLATE)
		var field := _line(entry[2] as String)
		field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(field)
		_fields[entry[1]] = field


func _notes(page: VBoxContainer) -> void:
	var body := _section(page, "NOTAS")
	var notes := RuledText.new()
	_style_text(notes)
	notes.custom_minimum_size = Vector2(0.0, 220.0)
	notes.placeholder_text = "Escribe aquí tus notas de campo…"
	body.add_child(notes)
	_fields["notes"] = notes


func _observations(page: VBoxContainer) -> void:
	var body := _section(page, "OBSERVACIONES")
	var seen := TextEdit.new()
	_style_text(seen)
	seen.custom_minimum_size = Vector2(0.0, 96.0)
	seen.placeholder_text = "¿Qué viste que no esperabas?"
	body.add_child(seen)
	_fields["observations"] = seen


func _data_table(page: VBoxContainer) -> void:
	var body := _section(page, "DATOS")
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)
	body.add_child(grid)
	for row in ROWS:
		for column in COLUMNS:
			var cell := _line("")
			cell.add_theme_stylebox_override("normal", _cell_style(row == 0))
			cell.add_theme_stylebox_override("focus", _cell_style(row == 0, true))
			cell.custom_minimum_size = Vector2(0.0, 40.0)
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if row == 0:
				cell.placeholder_text = COLUMN_HINTS[column]
			grid.add_child(cell)
			_cells.append(cell)


func _signature(page: VBoxContainer) -> void:
	var body := _section(page, "FIRMA")
	var sign := _line("")
	sign.placeholder_text = "Nombre del cadete"
	body.add_child(sign)
	_fields["sign"] = sign


func _buttons() -> void:
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 16)
	add_child(bar)
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	bar.offset_left = -400.0
	bar.offset_right = 400.0
	bar.offset_top = 298.0
	bar.offset_bottom = 352.0
	var back := Button.new()
	back.text = "Guardar y volver"
	back.custom_minimum_size = Vector2(220.0, 50.0)
	LunarButtonKit.apply(back, &"soltar")
	back.pressed.connect(
		func() -> void:
			_save()
			closed.emit()
	)
	bar.add_child(back)
	var save := Button.new()
	save.text = "Guardar"
	save.custom_minimum_size = Vector2(180.0, 50.0)
	LunarButtonKit.apply(save, &"construir")
	save.pressed.connect(_save)
	bar.add_child(save)
	_status = _label(bar, "", 18, BODY, CREAM)
	_status.custom_minimum_size.x = 200.0


func _section(page: VBoxContainer, caption: String) -> PanelContainer:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 0)
	page.add_child(block)
	var tab := PanelContainer.new()
	tab.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var tab_style := _plate(SLATE, Color("#2f3f4a"), 10)
	tab_style.set_corner_radius_all(2)
	tab_style.corner_radius_top_right = 14
	tab_style.corner_radius_top_left = 8
	tab_style.corner_detail = 1
	tab.add_theme_stylebox_override("panel", tab_style)
	block.add_child(tab)
	_label(tab, caption, 18, BODY, CREAM)
	var body := PanelContainer.new()
	body.add_theme_stylebox_override("panel", _outline(14, Color.TRANSPARENT, 10))
	block.add_child(body)
	return body


func _line(hint: String) -> LineEdit:
	var field := LineEdit.new()
	field.max_length = 80
	field.add_theme_font_override("font", BODY)
	field.add_theme_font_size_override("font_size", 20)
	field.add_theme_color_override("font_color", INK)
	field.add_theme_color_override("caret_color", INK)
	field.add_theme_color_override("font_placeholder_color", FADED)
	field.add_theme_color_override("selection_color", Color("#e8821c66"))
	var underline := StyleBoxFlat.new()
	underline.bg_color = Color.TRANSPARENT
	underline.border_color = LINE
	underline.border_width_bottom = 2
	underline.content_margin_left = 6.0
	underline.content_margin_right = 6.0
	underline.content_margin_top = 4.0
	underline.content_margin_bottom = 4.0
	field.add_theme_stylebox_override("normal", underline)
	var active := underline.duplicate() as StyleBoxFlat
	active.border_color = ORANGE
	field.add_theme_stylebox_override("focus", active)
	field.placeholder_text = hint
	return field


func _style_text(box: TextEdit) -> void:
	box.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	box.add_theme_font_override("font", BODY)
	box.add_theme_font_size_override("font_size", 20)
	box.add_theme_constant_override("line_spacing", 8)
	box.add_theme_color_override("font_color", INK)
	box.add_theme_color_override("caret_color", INK)
	box.add_theme_color_override("font_placeholder_color", FADED)
	box.add_theme_color_override("selection_color", Color("#e8821c66"))
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color.TRANSPARENT
	flat.content_margin_left = 8.0
	flat.content_margin_right = 8.0
	flat.content_margin_top = 6.0
	flat.content_margin_bottom = 6.0
	for state in ["normal", "focus", "read_only"]:
		box.add_theme_stylebox_override(state, flat)
	box.text_changed.connect(
		func() -> void:
			if box.text.length() > NOTES_LIMIT:
				box.text = box.text.substr(0, NOTES_LIMIT)
				box.set_caret_column(box.text.length())
	)


func _label(parent: Control, caption: String, size: int, font: Font, color: Color) -> Label:
	var label := Label.new()
	label.text = caption
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _paper_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = PAPER_EDGE
	style.set_border_width_all(3)
	style.set_corner_radius_all(18)
	style.corner_detail = 1
	style.shadow_color = Color("#00000099")
	style.shadow_size = 18
	return style


func _plate(fill: Color, edge: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.corner_detail = 1
	style.content_margin_left = 22.0
	style.content_margin_right = 22.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style


func _outline(radius: int, fill: Color, pad: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = LINE
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.corner_detail = 1
	for side in ["left", "right", "top", "bottom"]:
		style.set("content_margin_" + side, float(pad))
	return style


func _cell_style(header: bool, active := false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#c4bcad") if header else Color.TRANSPARENT
	style.border_color = ORANGE if active else LINE
	style.set_border_width_all(1)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style


func _load() -> void:
	var saved: Dictionary = _profile.data.get("dossier", {})
	for key: String in _fields:
		var control: Control = _fields[key]
		var text := String(saved.get(key, ""))
		if key == "date" and text.is_empty():
			text = Time.get_date_string_from_system()
		elif key == "exp" and text.is_empty():
			text = "001"
		if control is LineEdit:
			(control as LineEdit).text = text
		elif control is TextEdit:
			(control as TextEdit).text = text
	var cells: Array = saved.get("cells", [])
	for index in mini(cells.size(), _cells.size()):
		_cells[index].text = String(cells[index])


func _save() -> void:
	var out := {}
	for key: String in _fields:
		var control: Control = _fields[key]
		out[key] = (control as LineEdit).text if control is LineEdit else (control as TextEdit).text
	var cells: Array = []
	for cell in _cells:
		cells.append(cell.text)
	out["cells"] = cells
	_profile.data["dossier"] = out
	_status.text = "Expediente guardado" if _profile.save() else "No se pudo guardar"
