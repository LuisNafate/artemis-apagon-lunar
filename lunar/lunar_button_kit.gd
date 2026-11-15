class_name LunarButtonKit
extends RefCounted

# Estilo de botones del juego: pixel art. Placas con esquinas escalonadas,
# contorno casi negro, filo claro arriba y a los lados, banda oscura abajo y
# letras pixeladas con sombra. Se dibujan una vez por tipo y estado.

const FONT := preload("res://assets/ui/fonts/Silkscreen-Bold.ttf")
const CREAM := Color("#fffbea")
const GRID := 16
const PX := 4
const SIZE := GRID * PX
const MARGIN := 5 * PX
# base, borde oscuro, brillo
const PALETTE := {
	&"accion": [Color("#1d8486"), Color("#0b3a3c"), Color("#47c9c4")],
	&"soltar": [Color("#6a4027"), Color("#331c0f"), Color("#98623c")],
	&"construir": [Color("#4e9a37"), Color("#1f4a17"), Color("#86cf63")],
	&"mejorar": [Color("#dc7d19"), Color("#6f3607"), Color("#ffb347")],
	&"cancelar": [Color("#b6414a"), Color("#541820"), Color("#e2737a")],
	&"seguimiento": [Color("#265a6b"), Color("#0f2a34"), Color("#5fb0c4")],
	&"bloqueado": [Color("#6c6381"), Color("#383246"), Color("#8d84a3")]
}

static var _cache := {}


static func kind_for(caption: String) -> StringName:
	var text := caption.to_lower()
	for start in ["cancelar", "reiniciar", "salir", "volver al inicio"]:
		if text.begins_with(start):
			return &"cancelar"
	for start in ["volver", "sin rol", "archivo", "ficha", "soltar"]:
		if text.begins_with(start):
			return &"soltar"
	if text.begins_with("comprar"):
		return &"mejorar"
	return &"accion"


static func apply(button: Button, kind: StringName = &"accion", font_size := 22) -> void:
	var colors: Array = PALETTE[kind]
	var edge: Color = colors[1]
	button.flat = false
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", maxi(16, roundi(font_size / 8.0) * 8))
	button.add_theme_color_override("font_shadow_color", edge.darkened(0.1))
	button.add_theme_constant_override("shadow_offset_x", 0)
	button.add_theme_constant_override("shadow_offset_y", 3)
	button.add_theme_constant_override("outline_size", 0)
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for state in ["font_color", "font_hover_color", "font_focus_color"]:
		button.add_theme_color_override(state, CREAM)
	button.add_theme_color_override("font_pressed_color", CREAM.darkened(0.14))
	button.add_theme_color_override("font_disabled_color", Color("#b9afcb"))
	button.add_theme_stylebox_override("normal", _box(kind, &"normal"))
	button.add_theme_stylebox_override("hover", _box(kind, &"hover"))
	button.add_theme_stylebox_override("focus", _box(kind, &"hover"))
	button.add_theme_stylebox_override("pressed", _box(kind, &"pressed"))
	button.add_theme_stylebox_override("disabled", _box(&"bloqueado", &"normal"))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


static func _box(kind: StringName, state: StringName) -> StyleBoxTexture:
	var key := "%s/%s" % [kind, state]
	if _cache.has(key):
		return _cache[key]
	var colors: Array = PALETTE[kind]
	var box := StyleBoxTexture.new()
	box.texture = _paint(colors[0], colors[1], colors[2], state)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		box.set_texture_margin(side, MARGIN)
	box.set_content_margin(SIDE_LEFT, 18.0)
	box.set_content_margin(SIDE_RIGHT, 18.0)
	box.set_content_margin(SIDE_TOP, 10.0 if state == &"pressed" else 6.0)
	box.set_content_margin(SIDE_BOTTOM, 6.0 if state == &"pressed" else 10.0)
	_cache[key] = box
	return box


static func _paint(base: Color, edge: Color, glow: Color, state: StringName) -> ImageTexture:
	var pressed := state == &"pressed"
	var body := base
	if state == &"hover":
		body = base.lerp(glow, 0.3)
	elif pressed:
		body = base.darkened(0.14)
	var outline := edge.darkened(0.55)
	var band := body.darkened(0.3)
	var shine := body.lerp(glow, 0.7)
	var side := body.lerp(glow, 0.35)
	var last := GRID - 1
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for ly in GRID:
		for lx in GRID:
			var sums := [lx + ly, last - lx + ly, lx + last - ly, 2 * last - lx - ly]
			var cut := false
			var rim := minf(minf(lx, ly), minf(last - lx, last - ly)) == 0.0
			for corner: int in sums:
				if corner < 2:
					cut = true
				elif corner == 2:
					rim = true
			if cut:
				continue
			var color := body
			if rim:
				color = outline
			elif ly >= last - (1 if pressed else 2):
				color = band
			elif ly == 1 and not pressed:
				color = shine
			elif lx == 1 and not pressed:
				color = side
			elif lx == last - 1:
				color = band.lerp(body, 0.45)
			for dy in PX:
				for dx in PX:
					image.set_pixel(lx * PX + dx, ly * PX + dy, color)
	return ImageTexture.create_from_image(image)
