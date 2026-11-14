class_name CrewVisuals
extends Node

const ATLAS := preload("res://assets/sprites_25d/visitors.png")
const ARRIVAL_CELLS := [Vector2i(10, 1), Vector2i(11, 2)]

var _map: LunarMap
var _depth: Node2D
var _actors: Dictionary = {}
var _statuses: Dictionary = {}
var _training_complete := false


func seated_count() -> int:
	var seated := 0
	for index: int in _actors:
		if _statuses[index] == CrewReception.Status.STAYING:
			for astronaut: AstronautController in _actors[index]:
				if astronaut.path.is_empty() and astronaut.z_index == 1:
					seated += 1
	return seated


func setup(map: LunarMap, depth: Node2D) -> void:
	_map = map
	_depth = depth


func synchronize(waves: Array[Dictionary], training_complete: bool) -> void:
	_training_complete = training_complete
	if waves.is_empty() or waves[0].status == CrewReception.Status.SCHEDULED:
		clear()
	for index in range(waves.size()):
		var wave := waves[index]
		var status := int(wave.status)
		if status == int(_statuses.get(index, CrewReception.Status.SCHEDULED)):
			continue
		_statuses[index] = status
		if status == CrewReception.Status.WAITING:
			_spawn(index, int(wave.size))
		elif status == CrewReception.Status.STAYING:
			_send_to_berths(index, wave.assigned)
		elif status in [CrewReception.Status.SERVED, CrewReception.Status.MISSED]:
			_send_to_dock(index)


func clear() -> void:
	for key: int in _actors.keys():
		for astronaut: AstronautController in _actors[key]:
			astronaut.queue_free()
	_actors.clear()
	_statuses.clear()


func _process(delta: float) -> void:
	var active := AdversarialDirector.phase == AdversarialDirector.Phase.ACTIVE
	if not active and not _training_complete:
		return
	for key: int in _actors.keys():
		var actors: Array = _actors[key]
		var moving := false
		for astronaut: AstronautController in actors:
			astronaut.advance(delta)
			moving = moving or not astronaut.path.is_empty()
		if not moving and int(_statuses[key]) >= CrewReception.Status.SERVED:
			for astronaut: AstronautController in actors:
				astronaut.queue_free()
			_actors.erase(key)


func _spawn(index: int, count: int) -> void:
	var actors: Array[AstronautController] = []
	for id in range(count):
		var astronaut := AstronautController.new()
		astronaut.atlas = ATLAS
		astronaut.costume = index % 2
		astronaut.speed = 105.0 + id * 12.0
		astronaut.visual_offset = Vector2(0, -13) + Vector2((index % 2) * 5 - 2, id * 2)
		_depth.add_child(astronaut)
		astronaut.place(ARRIVAL_CELLS[id % ARRIVAL_CELLS.size()])
		actors.append(astronaut)
	_actors[index] = actors


func _send_to_berths(index: int, assigned: Array) -> void:
	var actors: Array = _actors[index]
	for id in range(actors.size()):
		var astronaut: AstronautController = actors[id]
		var berth: Vector2i = assigned[id]
		var entry := _map.berth_entrance(berth)
		var path := _map.route(astronaut.cell, entry, null, true)
		if astronaut.cell != entry and not path.is_empty():
			astronaut.path = path
		var room := LunarMap.project(Vector2(berth) + Vector2(0.5, 0.5))
		var seat := Vector2(-8 + id * 14, 5 - id * 2)
		astronaut.set_arrival_offset(room - LunarMap.project(entry) + seat, 1)


func _send_to_dock(index: int) -> void:
	if not _actors.has(index):
		return
	for id in range(_actors[index].size()):
		var astronaut: AstronautController = _actors[index][id]
		var arrival: Vector2i = ARRIVAL_CELLS[id % ARRIVAL_CELLS.size()]
		var moving := not astronaut.path.is_empty()
		var origin := astronaut.path[0] if moving else astronaut.cell
		astronaut.path = _map.route(origin, arrival, null, true)
		if moving:
			astronaut.path.push_front(origin)
		astronaut.set_arrival_offset(Vector2.ZERO)
