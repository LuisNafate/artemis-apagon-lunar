class_name LunarItemContext
extends RefCounted

const LOAD_NAMES := {
	&"sample": "muestra",
	&"ice": "hielo",
	&"ore": "mineral",
	&"fuel": "propelente",
	&"food": "ración"
}


static func delivers(mission: LunarMission, player: int, spot: StringName) -> bool:
	var cargo := mission.cargo_kind(player)
	match spot:
		&"training":
			return cargo == &"sample" and (mission.solo or player == 1)
		&"refinery":
			return cargo in [&"ice", &"ore"]
		&"pad":
			return cargo in [&"fuel", &"food"]
	return false


static func at(mission: LunarMission, player: int, spot: StringName, pickup: StringName) -> Array:
	if mission.pilots[player].seated:
		return ["Bajar de la nave", "", false]
	if pickup != &"":
		return [_t("Recoger %s") % _t(LOAD_NAMES[pickup]), "Añade la carga a tu traje.", false]
	if String(spot).begins_with("dep:"):
		return _deposit(mission, player, spot)
	match spot:
		&"training":
			return _training(mission, player)
		&"refinery":
			return _refinery(mission, player)
		&"crop", &"fuel":
			return _production(mission, player, spot)
		&"drill", &"battery", &"irrigation":
			return _upgrade(mission, spot)
		&"power":
			var other := "propelente" if mission.priority == &"crop" else "cultivo"
			var current := "cultivo" if mission.priority == &"crop" else "propelente"
			return [
				_t("Priorizar %s") % _t(other),
				_t("Prioridad actual tras el aire: %s.") % _t(current),
				false
			]
		&"life":
			return _shelter(mission, player)
		&"radio":
			return _radio(mission)
		&"pad":
			return _lander(mission, player)
	return ["", "", true]


static func _training(mission: LunarMission, player: int) -> Array:
	if delivers(mission, player, &"training"):
		return ["Entregar muestra", "Termina la práctica e inicia el día.", false]
	if mission.solo and mission.tutorial_step != 0:
		return ["", "Recoge la muestra del suelo y regresa a la mesa.", true]
	return ["Tomar muestra" if mission.solo else "Acción", "Practica con una muestra.", false]


static func _deposit(mission: LunarMission, player: int, spot: StringName) -> Array:
	var kind := mission.deposit_kind(spot)
	var item := _t(LOAD_NAMES.get(kind, "recurso"))
	var pilot := mission.pilots[player]
	if pilot.mine == spot:
		return ["Extrayendo…", _t("%s · quédate cerca.") % _seconds(pilot.mine_left), true]
	if pilot.cargo != 0:
		return [_t("Extraer %s") % item, "Entrega o suelta la carga que llevas.", true]
	if pilot.get("pending_extra", &"") == kind and kind != &"" and not mission.cargo_full():
		return ["Recoger extra", _t("Caja adicional de %s por tu rol.") % item, false]
	if mission.deposit_left(spot) <= 0:
		var days := mission.deposit_refill_left(spot)
		var cycle := "amanecer" if days == 1 else "amaneceres"
		return ["Depósito vacío", _t("Se repone en %d %s.") % [days, _t(cycle)], true]
	return [
		_t("Extraer %s") % item,
		(
			"Capacidad de carga alcanzada."
			if mission.cargo_full()
			else (
				_t("Quedan %d · extracción %s.")
				% [mission.deposit_left(spot), _seconds(mission.drill_seconds())]
			)
		),
		mission.cargo_full()
	]


static func _refinery(mission: LunarMission, player: int) -> Array:
	var cargo := mission.cargo_kind(player)
	if cargo == &"ore":
		return ["Guardar mineral", "Añade 1 mineral para mejoras.", false]
	if not mission.refining.is_empty():
		return _timer("Refinando hielo", mission.refining[0], mission.workshop_paused())
	if mission.workshop_paused():
		return ["Refinar hielo", "Taller sin energía.", true]
	return [
		"Refinar hielo",
		(
			(
				_t("Produce %.0f de agua en %s.")
				% [mission.resources.ice_water, _seconds(mission.resources.refine_seconds)]
			)
			if cargo == &"ice"
			else "Trae una caja de hielo o mineral."
		),
		cargo != &"ice"
	]


static func _production(mission: LunarMission, player: int, spot: StringName) -> Array:
	var crop := spot == &"crop"
	var stock := mission.food if crop else mission.fuel_ready
	if stock > 0:
		var title := "Recoger ración" if crop else "Recoger propelente"
		var full := mission.cargo_kind(player) != &"" or mission.cargo_full()
		return [
			title,
			"Libera espacio para recoger." if full else _t("Unidades listas: %d.") % stock,
			full
		]
	if mission.jobs[spot] > 0.0:
		var lacks_power: bool = (
			not mission.paid_jobs[spot] and mission.charge < mission.job_energy_cost(spot)
		)
		return _timer(
			"Cultivo en curso" if crop else "Preparando lote",
			mission.jobs[spot],
			mission.workshop_paused() or lacks_power
		)
	if not crop and mission.fuel_quota_met():
		return ["Lotes preparados", "Entrega en la nave los lotes que queden por cargar.", true]
	var cost := mission.job_water_cost(spot)
	var carrying := mission.cargo_kind(player) != &""
	var message := (
		"Suelta o entrega tu carga primero."
		if carrying
		else _t("Agua: %.2f/%.2f.") % [mission.water, cost]
	)
	return [
		"Sembrar cultivo" if crop else "Preparar propelente",
		message,
		carrying or mission.water < cost
	]


static func _upgrade(mission: LunarMission, spot: StringName) -> Array:
	if mission.upgrade_installed(spot):
		return [
			"Mejora instalada",
			{
				&"drill": "La extracción tarda menos.",
				&"battery": "Más capacidad de batería.",
				&"irrigation": "Cada cosecha produce más raciones."
			}[spot],
			true
		]
	if mission.installing.has(spot):
		return _timer("Instalando mejora", mission.installing[spot], mission.workshop_paused())
	var cost := int(mission.rules.upgrade_costs[String(spot)])
	return ["Instalar mejora", _t("Mineral: %d/%d.") % [mission.ore, cost], mission.ore < cost]


static func _shelter(mission: LunarMission, player: int) -> Array:
	if mission.pilots[player].hunger >= mission.resources.hunger:
		return [
			"Comer ración",
			"Ya comiste suficiente. Aquí puedes recuperar aire si hay agua y energía.",
			true
		]
	var hungry := mission.food <= 0 and mission.cargo_kind(player) != &"food"
	return [
		"Comer ración",
		"Recoge una ración en Cultivos." if hungry else "Reduce el hambre con una ración.",
		hungry
	]


static func _radio(mission: LunarMission) -> Array:
	if mission.returned or mission.earth_ok:
		return ["Lista confirmada", "Tierra recibió la lista de vuelo.", true]
	if mission.radio_left > 0.0:
		return [
			"Señal en tránsito",
			_t("Respuesta de Tierra en %s.") % _seconds(mission.radio_left),
			true
		]
	if mission.radio_cut():
		var end := (
			float(mission.rules.prototype_parameters.radio_cut_at)
			+ float(mission.rules.events.radio_cut_seconds)
		)
		return [
			"Radio sin señal", _t("Se restablece en %s.") % _seconds(end - mission.elapsed), true
		]
	return ["Enviar lista de vuelo", "Espera la respuesta de Tierra.", false]


static func _lander(mission: LunarMission, player: int) -> Array:
	if mission.returned:
		return ["Misión completada", "Puedes seguir explorando la base.", true]
	var requirements: Dictionary = mission.rules.mission
	var cargo := mission.cargo_kind(player)
	if cargo == &"fuel" and mission.fuel_loaded < int(requirements.propellant):
		return ["Cargar propelente", "Añade un lote a la nave.", false]
	if cargo == &"food" and mission.food_loaded < int(requirements.food):
		return ["Cargar ración", "Añade una ración a la nave.", false]
	var reason := ""
	if cargo != &"":
		reason = "La nave no necesita esta carga."
	elif (
		mission.fuel_loaded < int(requirements.propellant)
		or mission.food_loaded < int(requirements.food)
	):
		reason = "Completa el propelente y las raciones."
	elif not mission.earth_ok:
		reason = "Pide confirmación por radio."
	elif mission.storm_active():
		reason = "Espera en el refugio hasta que pase la alerta."
	elif not mission.solo and not mission.connected[1]:
		reason = "Falta el otro astronauta."
	return ["Subir a la nave", reason, not reason.is_empty()]


static func _timer(title: String, remaining: float, paused: bool) -> Array:
	var status := _t("En pausa por energía · " if paused else "Tiempo restante: ")
	return [title, status + _seconds(remaining), true]


static func _seconds(value: float) -> String:
	var seconds := maxi(0, ceili(value))
	return "%d:%02d" % [floori(seconds / 60.0), seconds % 60]


## Traduce las partes que se arman con números o nombres; los textos fijos los traduce
## cada botón o etiqueta por su cuenta.
static func _t(text: String) -> String:
	return LunarLanguage.t(text)
