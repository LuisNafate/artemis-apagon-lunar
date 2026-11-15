class_name LunarLoadingBar
extends Control
## Barra de carga de bloques, en el estilo pixel art de los botones del juego.

const BLOCK := 20.0
const GAP := 4.0

var value := 0.0:
	set(amount):
		value = clampf(amount, 0.0, 1.0)
		queue_redraw()

var _phase := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(0.0, 46.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_phase += delta
	queue_redraw()


func _draw() -> void:
	var frame := Rect2(Vector2.ZERO, size)
	draw_rect(frame, Color("#14100d"))
	draw_rect(frame.grow(-4.0), Color("#2d241e"))
	var inner := frame.grow(-9.0)
	var count := maxi(1, int(inner.size.x / (BLOCK + GAP)))
	var lit := value * count
	var sweep := int(_phase * 9.0) % count
	for index in count:
		var block := Rect2(
			inner.position + Vector2(index * (BLOCK + GAP), 0.0), Vector2(BLOCK, inner.size.y)
		)
		if float(index) + 1.0 <= lit + 0.001:
			draw_rect(block, Color("#dc7d19"))
			draw_rect(Rect2(block.position, Vector2(BLOCK, 4.0)), Color("#ffb347"))
			draw_rect(Rect2(block.position + Vector2(0.0, block.size.y - 5.0), Vector2(BLOCK, 5.0)), Color("#a85b0e"))
			if index == sweep:
				draw_rect(block, Color(1.0, 0.95, 0.8, 0.35))
		elif float(index) < lit:
			var part := Rect2(block.position, Vector2(BLOCK * (lit - float(index)), block.size.y))
			draw_rect(Rect2(block.position, block.size), Color("#3a2f27"))
			draw_rect(part, Color("#dc7d19"))
		else:
			draw_rect(block, Color("#3a2f27"))
			draw_rect(Rect2(block.position, Vector2(BLOCK, 3.0)), Color("#4a3d33"))
