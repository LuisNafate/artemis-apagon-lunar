class_name LunarArchive
extends Control

# Archivo cientifico con el mismo papel del expediente: una ficha por pagina con
# su descripcion y botones para recorrer las fichas o abrir el expediente propio.

signal chosen(action: String)

const BODY := preload("res://assets/ui/fonts/Barlow-SemiBold.ttf")
const TITLE := preload("res://assets/ui/fonts/BarlowCondensed-Bold.ttf")
const INK := Color("#2c3a44")
const SLATE := Color("#4a5f6e")
const TEAL := Color("#1f4a52")
const ORANGE := Color("#e8821c")
const CREAM := Color("#fff2d6")


func build(record_title: String, description: String, index: int, count: int) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color("#0c0f16ea")
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var sheet := PanelContainer.new()
	sheet.add_theme_stylebox_override("panel", LunarDossier.paper_style())
	add_child(sheet)
	sheet.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	sheet.offset_left = -400.0
	sheet.offset_right = 400.0
	sheet.offset_top = -345.0
	sheet.offset_bottom = 285.0
	for edge in [-353.0, 277.0]:
		var tab := Panel.new()
		tab.add_theme_stylebox_override("panel", LunarDossier.plate(ORANGE, Color("#8a4a0c"), 6))
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

	var top := LunarDossier.label(page, "ARTEMIS · ÚLTIMA VENTANA", 18, BODY, SLATE)
	top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var banner := PanelContainer.new()
	banner.add_theme_stylebox_override("panel", LunarDossier.plate(TEAL, Color("#102a30"), 12))
	page.add_child(banner)
	var heading := LunarDossier.label(banner, "ARCHIVO CIENTÍFICO", 40, TITLE, CREAM)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", LunarDossier.outline(12, Color.TRANSPARENT, 8))
	page.add_child(frame)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	frame.add_child(row)
	LunarDossier.label(row, "FICHA", 19, BODY, SLATE)
	LunarDossier.label(row, "%02d / %02d" % [index + 1, count], 22, TITLE, ORANGE)
	row.add_child(VSeparator.new())
	var name_label := LunarDossier.label(row, record_title, 22, BODY, INK)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var body := LunarDossier.section(page, "DESCRIPCIÓN")
	var text := LunarDossier.label(body, description, 22, BODY, INK)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(0.0, 260.0)

	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 14)
	add_child(bar)
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	bar.offset_left = -400.0
	bar.offset_right = 400.0
	bar.offset_top = 298.0
	bar.offset_bottom = 352.0
	_button(bar, "Anterior", "previous_science", &"soltar")
	_button(bar, "Siguiente", "next_science", &"accion")
	_button(bar, "Mi expediente", "dossier", &"construir")
	_button(bar, "Volver", "close_science", &"cancelar")


func _button(bar: HBoxContainer, caption: String, action: String, kind: StringName) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(180.0, 50.0)
	LunarButtonKit.apply(button, kind)
	button.pressed.connect(func() -> void: chosen.emit(action))
	bar.add_child(button)
