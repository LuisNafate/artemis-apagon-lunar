class_name LunarTouch
extends Control

var axis := Vector2.ZERO
var _finger := -2


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(110, 110)
	visibility_changed.connect(clear)


func clear() -> void:
	_finger = -2
	axis = Vector2.ZERO
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		_pointer(event.index, event.position, event.pressed)
	elif event is InputEventScreenDrag and event.index == _finger:
		_drag(event.position)
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_pointer(-1, event.position, event.pressed)
	elif event is InputEventMouseMotion and _finger == -1:
		_drag(event.position)


func _pointer(index: int, point: Vector2, pressed: bool) -> void:
	if not pressed and _finger == index:
		clear()
		get_viewport().set_input_as_handled()
	elif pressed and _finger == -2 and get_global_rect().has_point(point):
		_finger = index
		_drag(point)


func _drag(point: Vector2) -> void:
	var center := get_global_rect().get_center()
	axis = ((point - center) / (size.x * 0.38)).limit_length()
	queue_redraw()
	get_viewport().set_input_as_handled()


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.48
	draw_circle(center, radius, Color("#172a41db"))
	draw_arc(center, radius, 0.0, TAU, 50, CrestWorld.BLUE, 2.0, true)
	draw_circle(center + axis * radius * 0.55, radius * 0.35, CrestWorld.BLUE)
