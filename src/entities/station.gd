class_name Station
extends Node2D

var key: StringName
var title: String
var footprint: Rect2i
var status := ""
var accent := Color("#e6a86c")
var selected := false
var highlighted := false
var label_offset := -53.0

var _sprite: Sprite2D
var _pixels: Image


func setup(art: Texture2D) -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = art
	_pixels = art.get_image()
	_sprite.position = Vector2(0, -7)
	add_child(_sprite)


func contains_art(point: Vector2) -> bool:
	var local := to_local(point) - _sprite.position
	var texel := Vector2i((local + Vector2(70, 48)).floor())
	if not Rect2i(0, 0, 140, 96).has_point(texel):
		return false
	return _pixels.get_pixelv(texel).a >= 0.5


func set_state(text: String, color: Color, focused: bool, target: bool) -> void:
	status = text
	accent = color
	selected = focused
	highlighted = target
	queue_redraw()


func _draw() -> void:
	if selected:
		var extent := 35.0 if key != &"beacon" else 16.0
		draw_polyline(
			PackedVector2Array(
				[
					Vector2(-extent, 0),
					Vector2(0, -extent / 2),
					Vector2(extent, 0),
					Vector2(0, extent / 2),
					Vector2(-extent, 0)
				]
			),
			accent,
			1.0
		)
	draw_rect(Rect2(-2, label_offset + 5, 4, 4), accent if highlighted else Color("#a3a8b2"))
