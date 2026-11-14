class_name AstronautController
extends Node2D

const ATLAS := preload("res://assets/sprites_25d/astronaut.png")
const SPEED := 168.0

var cell := Vector2i.ZERO
var path: Array[Vector2i] = []
var atlas: Texture2D = ATLAS
var speed := SPEED
var costume := 0
var visual_offset := Vector2(0, -13)
var _sprite: Sprite2D
var _facing := 0
var _walk_time := 0.0
var _arrival_offset := Vector2.ZERO
var _arrival_depth := 0


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = atlas
	_sprite.hframes = 3
	_sprite.vframes = int(atlas.get_height() / 32.0)
	_sprite.position = visual_offset
	add_child(_sprite)


func place(at: Vector2i) -> void:
	cell = at
	position = LunarMap.project(cell)
	path.clear()
	_show_frame(false, 0.0)


func advance(delta: float) -> void:
	if path.is_empty():
		_show_frame(false, delta)
		return

	var next := path[0]
	var heading := next - cell
	if heading.x > 0:
		_facing = 0
	elif heading.y > 0:
		_facing = 1
	elif heading.y < 0:
		_facing = 2
	else:
		_facing = 3

	var target := LunarMap.project(next)
	position = position.move_toward(target, speed * delta)
	_show_frame(true, delta)
	if position == target:
		cell = next
		path.pop_front()


func _show_frame(walking: bool, delta: float) -> void:
	_walk_time = _walk_time + delta if walking else 0.0
	var step := 1 + int(_walk_time * 9.0) % 2 if walking else 0
	_sprite.frame_coords = Vector2i(step, _facing + costume * 4)
	_sprite.position = visual_offset if walking else visual_offset + _arrival_offset
	z_index = 0 if walking else _arrival_depth


func set_arrival_offset(offset: Vector2, depth: int = 0) -> void:
	_arrival_offset = offset
	_arrival_depth = depth
