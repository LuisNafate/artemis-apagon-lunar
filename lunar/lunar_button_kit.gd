class_name LunarButtonKit
extends RefCounted

# Estilo de botones del juego (guia de botones): placas con esquinas cortadas,
# borde oscuro, brillo diagonal y labio inferior. Se dibujan una vez por tipo y
# estado y se reutilizan en todos los menus.

const FONT := preload("res://assets/ui/fonts/Barlow-SemiBold.ttf")
const CREAM := Color("#fff2d6")
const SIZE := 64
const CHAMFER := 12.0
const OUTLINE := 3.0
const MARGIN := 20
# base, borde oscuro, brillo
const PALETTE := {
	&"accion": [Color("#1d8486"), Color("#0b3a3c"), Color("#47c9c4")],
	&"soltar": [Color("#6a4027"), Color("#331c0f"), Color("#98623c")],
	&"construir": [Color("#4e9a37"), Color("#1f4a17"), Color("#86cf63")],
	&"mejorar": [Color("#dc7d19"), Color("#6f3607"), Color("#ffb347")],
	&"cancelar": [Color("#b6414a"), Color("#541820"), Color("#e2737a")],
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
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_outline_color", edge.darkened(0.35))
	button.add_theme_constant_override("outline_size", 4)
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
	box.set_content_margin(SIDE_LEFT, 16.0)
	box.set_content_margin(SIDE_RIGHT, 16.0)
	box.set_content_margin(SIDE_TOP, 10.0 if state == &"pressed" else 6.0)
	box.set_content_margin(SIDE_BOTTOM, 6.0 if state == &"pressed" else 10.0)
	_cache[key] = box
	return box


static func _paint(base: Color, edge: Color, glow: Color, state: StringName) -> ImageTexture:
	var pressed := state == &"pressed"
	var hover := state == &"hover"
	var body := base
	var rim := edge
	if hover:
		body = base.lerp(glow, 0.38)
		rim = edge.lerp(glow, 0.55)
	elif pressed:
		body = base.darkened(0.16)
	var lip := 0.0 if pressed else 5.0
	var size := float(SIZE)
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			var px := x + 0.5
			var py := y + 0.5
			var depth := minf(minf(px, py), minf(size - px, size - py))
			depth = minf(depth, (px + py - CHAMFER) * 0.7071)
			depth = minf(depth, ((size - px) + py - CHAMFER) * 0.7071)
			depth = minf(depth, (px + (size - py) - CHAMFER) * 0.7071)
			depth = minf(depth, ((size - px) + (size - py) - CHAMFER) * 0.7071)
			var alpha := clampf(depth + 0.5, 0.0, 1.0)
			if alpha <= 0.0:
				continue
			var color := body
			if not pressed:
				color = body.lerp(glow, clampf(1.0 - py / size * 2.4, 0.0, 1.0) * 0.5)
			if py > size - 3.0 - lip:
				color = body.lerp(rim, 0.38)
			var corner := px + py
			if not pressed and corner > CHAMFER + 3.0 and corner < CHAMFER + 13.0:
				color = color.lerp(glow, 0.45)
			var back := (size - px) + (size - py)
			if back > CHAMFER + 3.0 and back < CHAMFER + 12.0:
				color = color.darkened(0.18)
			var inside := clampf(depth - OUTLINE + 0.5, 0.0, 1.0)
			color = rim.lerp(color, inside)
			color.a = alpha
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)
