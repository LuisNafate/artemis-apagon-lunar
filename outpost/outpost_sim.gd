class_name OutpostSim
extends RefCounted

const KEYS := [&"air", &"water", &"food", &"charge", &"dose"]
const MODULES := [&"life", &"shelter", &"farm"]

var config: Dictionary
var scenario := 0
var turn := 0
var state: Dictionary
var result := ""
var won := false


func _init() -> void:
	var registry: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://context_core/state_registry.json")
	)
	config = registry.outpost
	reset(0)


func reset(scenario_index: int) -> void:
	scenario = scenario_index
	turn = 0
	state = config.initial.duplicate()
	state.merge({"north": true, "south": true, "bridge": false})
	result = ""
	won = false


func events() -> Array:
	return config.scenarios[scenario].forecast


func preview(orders: Dictionary) -> Dictionary:
	if not result.is_empty():
		return {"state": state.duplicate(), "powered": {}, "result": result, "won": won}
	var next := state.duplicate()
	var event: Array = events()[turn]
	var cut: String = event[3]
	if not cut.is_empty():
		next[cut] = false
	var repair: String = orders.repair
	if repair in ["north", "south"] and not next[repair] and int(next.kits) > 0:
		next[repair] = true
		next.kits -= 1
	if orders.bridge and not next.bridge and int(next.kits) > 0:
		next.bridge = true
		next.kits -= 1
	var connected := {
		"life": next.north or (next.bridge and next.south),
		"farm": next.south or (next.bridge and next.north),
		"shelter": next.south or (next.bridge and next.north),
	}
	var energy := int(next.charge) + int(event[1])
	var load_used := 0
	var powered := {}
	for module: StringName in MODULES:
		var cost := int(config.draw[module])
		var available: bool = (
			connected[module] and energy >= cost and (not (module == &"farm" and orders.inside))
		)
		powered[module] = available and orders[module]
		if powered[module]:
			energy -= cost
			load_used += cost
	next.charge = energy

	next.air += 1 if powered.life else -2
	next.water += 1 if powered.life else -1
	next.food -= 1
	if powered.farm:
		next.growth = mini(2, int(next.growth) + 1)
		if int(next.growth) == 2 and int(next.water) >= 2:
			next.water -= 2
			next.food += 4
			next.growth = 0
			next.harvests += 1
	var shield := 0
	if orders.inside:
		shield = 4 if powered.shelter else 2
	next.dose += maxi(0, int(event[2]) - shield)
	for key: StringName in KEYS:
		next[key] = clampi(int(next[key]), 0, int(config.limits[key]))
	var failure := _check_loss(next)
	var final_turn := turn + 1 == events().size()
	var victory := failure.is_empty() and final_turn
	if victory and int(next.harvests) < int(config.minimum_harvests):
		victory = false
		failure = "Faltaron cosechas para sostener el puesto."
	return {
		"state": next,
		"connected": connected,
		"powered": powered,
		"result": "Puesto a salvo." if victory else failure,
		"won": victory,
		"load": load_used,
		"solar": event[1],
		"radiation": event[2],
		"cut": cut,
	}


func resolve(orders: Dictionary) -> Dictionary:
	var forecast := preview(orders)
	if result.is_empty():
		state = forecast.state
		result = forecast.result
		won = forecast.won
		turn += 1
	return forecast


func _check_loss(next: Dictionary) -> String:
	if int(next.air) <= 0:
		return "Se agotó el aire. Prioriza soporte vital o repara su ramal."
	if int(next.water) <= 0:
		return "Se agotó el agua. Reserva ciclos para soporte vital."
	if int(next.food) <= 0:
		return "Se agotó la comida. Adelanta el próximo ciclo de cultivo."
	if int(next.dose) >= int(config.limits.dose):
		return "La exposición llegó al límite. Entra al refugio antes de la alerta."
	return ""
