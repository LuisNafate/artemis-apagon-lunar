# gdlint: disable=max-returns
class_name LunarObjective
extends RefCounted


## Each instruction carries the interaction key that identifies its target.
static func next(mission: LunarMission, player: int, safe: bool) -> Array:
	if not mission.solo or mission.phase == &"flight":
		return [&"", ""]
	if mission.storm_active() or mission.storm_warning() > 0.0:
		if mission.phase != &"tutorial":
			return [
				&"life", "Espera en el refugio a que pase la alerta." if safe else "Ve al refugio."
			]
	if mission.returned or mission.phase == &"countdown":
		return [&"", ""]
	var cargo := mission.cargo_kind(player)
	if mission.phase == &"tutorial":
		if cargo == &"sample":
			return [&"training", "En la mesa de práctica, toca Entregar muestra."]
		if mission.tutorial_step > 0:
			return [&"loose_sample", "Recoge la muestra que dejaste en el suelo."]
		return [&"training", "Ve a la mesa de práctica y toca Tomar muestra."]
	match cargo:
		&"ice":
			return [&"refinery", "En Refinado, toca Entregar hielo para obtener agua."]
		&"ore":
			return [&"refinery", "En Refinado, toca Guardar mineral para usarlo en mejoras."]
		&"fuel":
			return [&"pad", "En la nave, toca Cargar propelente."]
		&"food":
			return [&"pad", "En la nave, toca Cargar ración."]
	return _prepare(mission)


static func _prepare(mission: LunarMission) -> Array:
	var requirements: Dictionary = mission.rules.mission
	if mission.fuel_loaded < int(requirements.propellant):
		return _production(mission, &"fuel", &"fuel")
	if mission.food_loaded < int(requirements.food):
		return _production(mission, &"crop", &"food")
	if not mission.earth_ok:
		if mission.radio_left > 0:
			return [&"radio", "Espera la respuesta de Tierra. La radio muestra el tiempo."]
		return [&"radio", "En Radio, toca Enviar lista de vuelo."]
	return [&"pad", "En la nave, toca Subir a la nave para iniciar la cuenta regresiva."]


static func _production(mission: LunarMission, station: StringName, cargo: StringName) -> Array:
	var fuel := cargo == &"fuel"
	var ready := mission.fuel_ready if fuel else mission.food
	if ready > 0:
		return [
			station,
			(
				"En Propelente, toca Recoger propelente."
				if fuel
				else "En Cultivos, toca Recoger ración."
			)
		]
	for crate: Dictionary in mission.crates.values():
		if crate.owner == -1 and crate.kind == cargo:
			return [
				&"loose_fuel" if fuel else &"loose_food",
				(
					"Recoge el propelente que dejaste en el suelo."
					if fuel
					else "Recoge la ración que dejaste en el suelo."
				)
			]
	if mission.jobs[station] > 0:
		return [
			station,
			(
				"Espera el lote de combustible en Propelente."
				if fuel
				else "Espera la cosecha en Cultivos."
			)
		]
	if mission.water < mission.job_water_cost(station):
		if not mission.refining.is_empty():
			return [&"refinery", "Espera a que Refinado termine de producir agua."]
		for crate: Dictionary in mission.crates.values():
			if crate.owner == -1 and crate.kind == &"ice":
				return [&"loose_ice", "Recoge el hielo que dejaste en el suelo."]
		return [&"ice", "Busca un depósito de hielo para obtener agua."]
	return [
		station,
		(
			"En Propelente, toca Preparar propelente para fabricar combustible."
			if fuel
			else "En Cultivos, toca Sembrar cultivo."
		)
	]
