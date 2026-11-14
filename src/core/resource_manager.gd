extends Node

const KEYS := [&"o2", &"co2", &"water", &"energy"]

var _amounts: Dictionary = {}
var _capacities: Dictionary = {}


func reset(initial: Dictionary, capacity: Dictionary) -> void:
	_amounts = initial.duplicate()
	_capacities = capacity.duplicate()


func amount(key: StringName) -> float:
	return float(_amounts[key])


func capacity(key: StringName) -> float:
	return float(_capacities[key])


func increase_capacity(key: StringName, quantity: float) -> void:
	_capacities[key] = capacity(key) + quantity


func adjust(key: StringName, delta: float) -> void:
	if not is_finite(delta):
		return
	_amounts[key] = clampf(amount(key) + delta, 0.0, capacity(key))


func consume(costs: Dictionary) -> bool:
	for key: StringName in costs:
		var cost: Variant = costs[key]
		if not _amounts.has(key) or (not cost is float and not cost is int):
			return false
		if not is_finite(float(cost)) or cost < 0.0 or amount(key) < cost:
			return false
	for key: StringName in costs:
		adjust(key, -float(costs[key]))
	return true


func amounts() -> Dictionary:
	return _amounts.duplicate()


func capacities() -> Dictionary:
	return _capacities.duplicate()
