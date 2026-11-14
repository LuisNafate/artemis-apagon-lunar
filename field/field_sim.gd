class_name FieldSim
extends RefCounted

const BATTERY := &"battery"
const SEEDS := [&"seed_a", &"seed_b"]

var config: Dictionary
var elapsed := 0.0
var air := 100.0
var charge := 0.0
var dose := 0.0
var growing := 0.0
var harvested := 0
var planted := 0
var online := false
var cargo: StringName = &""
var delivered := {}
var won := false
var failure := ""
var next_recharge := 0.0


func _init() -> void:
	var registry: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://context_core/state_registry.json")
	)
	config = registry.field
	air = float(config.air)


func pickup(item: StringName) -> bool:
	if finished() or item == &"" or not cargo.is_empty() or delivered.has(item):
		return false
	if item == BATTERY or (online and item in SEEDS):
		cargo = item
		return true
	return false


func use_station(station: StringName) -> String:
	if finished():
		return ""
	match station:
		&"generator":
			if cargo == BATTERY and not online:
				online = true
				charge = float(config.charge)
				_unload()
				next_recharge = 12.0
				return "¡Red restaurada! Busca las cápsulas verdes."
			if online and elapsed >= next_recharge and charge < 90.0:
				charge = minf(float(config.charge), charge + 35.0)
				next_recharge = elapsed + 12.0
				return "Recarga solar +35"
		&"farm":
			if cargo in SEEDS:
				planted += 1
				_unload()
				return "Cápsula conectada. El cultivo necesita energía."
		&"shelter":
			if harvested == SEEDS.size():
				won = true
				return "La base está a salvo."
	return ""


func advance(delta: float, sheltered: bool) -> void:
	if finished() or not online:
		return
	elapsed += delta
	var growing_now := harvested < planted and charge > 0.0
	var power_cost := 1.25 + (0.75 if growing_now else 0.0)
	charge = maxf(0.0, charge - delta * power_cost)
	if growing_now:
		growing += delta
		var goal := float(config.growth_seconds)
		if growing >= goal:
			growing -= goal
			harvested += 1
	var air_rate := 11.0 if sheltered and charge > 0.0 else (-0.65 if charge > 0.0 else -2.8)
	air = clampf(air + delta * air_rate, 0.0, float(config.air))
	if storm_active() and not sheltered:
		dose = minf(float(config.dose_limit), dose + delta * 7.0)
	_check_failure()


func storm_active() -> bool:
	for window: Array in config.storm_windows:
		if elapsed >= float(window[0]) and elapsed < float(window[1]):
			return true
	return false


func storm_wait() -> float:
	for window: Array in config.storm_windows:
		if elapsed < float(window[0]):
			return float(window[0]) - elapsed
	return INF


func fall() -> StringName:
	if finished():
		return &""
	var dropped := cargo
	cargo = &""
	if online:
		air = maxf(0.0, air - 14.0)
		_check_failure()
	return dropped


func finished() -> bool:
	return won or not failure.is_empty()


func _unload() -> void:
	delivered[cargo] = true
	cargo = &""


func _check_failure() -> void:
	if dose >= float(config.dose_limit):
		failure = "La radiación superó el límite. Busca refugio al oír la alarma."
	elif air <= 0.0:
		failure = "Se agotó el aire. Recárgalo dentro del refugio con la red activa."
	elif elapsed >= float(config.duration):
		failure = "Se acabó el turno. Usa el salto con turbo para ahorrar camino."
