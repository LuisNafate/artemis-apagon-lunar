class_name CrestCampaign
extends RefCounted

var data: Dictionary
var base: Dictionary = {}
var id := &"cresta"
var supply_pending := false
var _received := {}
var _last_time := 0.0


func _init(config: Dictionary) -> void:
	data = config.campaign


func select(base_id: StringName) -> void:
	id = base_id
	base = data.bases[String(id)]
	supply_pending = false
	_received.clear()
	_last_time = 0.0


func day(elapsed: float) -> int:
	var number := 1
	for interval: Array in base.nights:
		if elapsed >= float(interval[1]):
			number += 1
	return number


func night(elapsed: float) -> bool:
	for interval: Array in base.nights:
		if elapsed >= float(interval[0]) and elapsed < float(interval[1]):
			return true
	return false


func next_night(elapsed: float) -> float:
	for interval: Array in base.nights:
		if elapsed < float(interval[0]):
			return float(interval[0]) - elapsed
	return -1.0


func event_active(kind: String, elapsed: float) -> bool:
	for event: Array in base.events:
		var start := float(event[1])
		if event[0] == kind and elapsed >= start and elapsed < start + float(event[2]):
			return true
	return false


func next_event(kind: String, elapsed: float) -> float:
	for event: Array in base.events:
		if event[0] == kind and float(event[1]) > elapsed:
			return float(event[1]) - elapsed
	return -1.0


func tick(elapsed: float) -> void:
	for event: Array in base.events:
		var at := float(event[1])
		if event[0] == "supply" and _last_time < at and elapsed >= at and not _received.has(at):
			_received[at] = true
			supply_pending = true
	_last_time = elapsed
