# gdlint: disable=max-returns
class_name CrestSim
extends RefCounted

const CONFIG_PATH := "res://context_core/state_registry.json"
const CARGO_NAMES := {
	&"sample": "Muestra",
	&"ice": "Hielo",
	&"ore": "Mineral",
	&"fuel": "Propelente",
	&"food": "Ración"
}
const SCIENCE_TITLES := {
	"donki_sep_20240510": "Alerta de partículas solares",
	"radlab_artemis_i_hera": "Artemis I · Detector HERA",
	"neows_2016_ft14": "NeoWs · Asteroide 2016 FT14",
	"tle_iss_25544": "ISS · Órbita terrestre",
	"ntrs_life_support_mass": "ECLSS · Aire, agua y comida",
	"ntrs_lunar_radio": "Radio · Hablar con la Tierra",
	"nasa_lro_3d": "LRO · Cartografiar la Luna"
}

var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH)).coop_tycoon
var runtime: Dictionary = config.runtime
var campaign := CrestCampaign.new(config)
var targets: Dictionary = config.targets_provisional
var records: Array[Dictionary] = []
var phase := &"briefing"
var practice := false
var solo := false
var tutorial_step := 0
var elapsed := 0.0
var countdown := 0.0
var result := ""
var charge: float = runtime.starting_charge
var water: float = runtime.starting_water
var ore: int = runtime.starting_ore
var food: int = runtime.starting_rations
var fuel_ready := 0
var food_loaded := 0
var fuel_loaded := 0
var meals_clock: float = runtime.starting_ration_seconds
var filter_clock := 0.0
var hungry := false
var life_powered := true
var drill := false
var auxiliary := false
var priority := &"crop"
var radio_left := 0.0
var earth_ok := false
var jobs := {&"crop": 0.0, &"fuel": 0.0}
var powered := {&"crop": false, &"fuel": false}
var fuel_prepared := 0
var crops_harvested := 0
var deliveries := 0
var pilots: Array[Dictionary] = []
var crates: Dictionary = {}
var _next_crate := 1


func _init() -> void:
	for player in range(2):
		pilots.append(
			{
				"cargo": 0,
				"air": float(runtime.air_capacity),
				"exposure": 0.0,
				"seated": false,
				"mine": &"",
				"mine_left": 0.0
			}
		)
	_read_records()


func begin(is_practice: bool, skip: bool = false) -> void:
	practice = is_practice
	phase = &"active" if skip else &"tutorial"


func terminal() -> bool:
	return phase in [&"success", &"failed"]


func duration() -> float:
	if practice:
		return float(runtime.practice_duration)
	return float(runtime.solo_duration if solo else runtime.duration)


func storm_active() -> bool:
	if not campaign.base.is_empty():
		return campaign.event_active("sep", elapsed)
	var remaining := storm_left()
	return remaining > 0.0 and remaining <= float(runtime.storm_duration)


func storm_left() -> float:
	for start: float in [float(runtime.storm_start), float(runtime.storm_repeat)]:
		var remaining := start + float(runtime.storm_duration) - elapsed
		if remaining > 0.0:
			return remaining
	return 0.0


func storm_warning() -> float:
	if not campaign.base.is_empty():
		return campaign.next_event("sep", elapsed)
	var remaining := storm_left() - float(runtime.storm_duration)
	return remaining if remaining > 0.0 else -1.0


func shadow_active() -> bool:
	if not campaign.base.is_empty():
		return campaign.night(elapsed)
	return _in_range(float(runtime.shadow_start), float(runtime.shadow_duration))


func energy_cut() -> bool:
	return not campaign.base.is_empty() and campaign.event_active("outage", elapsed)


func radio_cut() -> bool:
	return (
		shadow_active()
		or (not campaign.base.is_empty() and campaign.event_active("relay", elapsed))
	)


func window_open() -> bool:
	if not campaign.base.is_empty():
		if campaign.day(elapsed) < int(campaign.base.last_day) or shadow_active():
			return false
	return (
		not terminal()
		and elapsed >= float(runtime.launch_opens)
		and elapsed < duration()
		and not storm_active()
	)


func battery_capacity() -> float:
	return (
		float(runtime.battery_capacity)
		+ (float(targets.aux_battery_capacity_units) if auxiliary else 0.0)
	)


func crew_seated() -> int:
	return int(pilots[0].seated) + int(pilots[1].seated)


func cargo_kind(player: int) -> StringName:
	var id: int = pilots[player].cargo
	return &"" if id == 0 else crates[id].kind


func drill_seconds() -> float:
	return float(
		targets.upgraded_drill_cycle_seconds if drill else targets.initial_drill_cycle_seconds
	)


func use_station(player: int, station: StringName) -> String:
	if phase == &"tutorial":
		return _tutorial_use(player, station)
	if phase not in [&"active", &"countdown"]:
		return ""
	if pilots[player].seated:
		return _embark(player)
	match station:
		&"ice", &"ore":
			return _start_mining(player, station)
		&"refinery":
			return _refine(player)
		&"crop", &"fuel":
			return _operate_job(player, station)
		&"drill", &"battery":
			return _upgrade(station)
		&"power":
			priority = &"fuel" if priority == &"crop" else &"crop"
			return "Prioridad · %s" % ("cultivo" if priority == &"crop" else "propelente")
		&"life":
			return _eat(player)
		&"radio":
			return _radio()
		&"supply":
			return _consume_supply()
		&"pad":
			return _pad(player)
	return ""


func pickup(player: int, id: int) -> bool:
	if phase not in [&"tutorial", &"active", &"countdown"] or pilots[player].seated:
		return false
	if pilots[player].cargo != 0 or not crates.has(id) or crates[id].owner != -1:
		return false
	crates[id].owner = player
	if phase == &"tutorial":
		tutorial_step = 1 if player == 0 else 2
	pilots[player].cargo = id
	pilots[player].mine = &""
	return true


func release(player: int, point: Vector3, partner_near: bool) -> String:
	var id: int = pilots[player].cargo
	if id == 0 or phase not in [&"tutorial", &"active", &"countdown"]:
		return ""
	var other := 1 - player
	pilots[player].cargo = 0
	if partner_near and pilots[other].cargo == 0 and not pilots[other].seated:
		pilots[other].cargo = id
		pilots[other].mine = &""
		crates[id].owner = other
		if phase == &"tutorial":
			tutorial_step = 2 if player == 0 else 1
		return "¡Entrega al astronauta %d!" % (other + 1)
	crates[id].owner = -1
	crates[id].point = point
	return "Caja en el suelo"


func tick(delta: float, sheltered: Array[bool], nearby: Array[StringName]) -> void:
	if phase not in [&"active", &"countdown"]:
		return
	elapsed += delta
	if not campaign.base.is_empty():
		campaign.tick(elapsed)
	_tick_mining(delta, nearby)
	_tick_power(delta)
	_tick_crew(delta, sheltered)
	if terminal():
		return
	if elapsed >= duration():
		_fail("Se cerró la ventana de lanzamiento.")
		return
	if radio_left > 0.0 and not radio_cut():
		radio_left = maxf(0.0, radio_left - delta)
		if radio_left == 0.0:
			earth_ok = true
	if phase == &"countdown":
		if not window_open() or crew_seated() != 2:
			phase = &"active"
			countdown = 0.0
			return
		countdown = maxf(0.0, countdown - delta)
		if countdown == 0.0:
			phase = &"success"
			result = "Los dos astronautas alcanzaron la órbita lunar."


func science_text(record: Dictionary) -> String:
	var values: Dictionary = record.get("observation", record.get("reference", {}))
	match String(record.id):
		"nasa_lro_3d":
			return String(values.description)
		"donki_sep_20240510":
			return (
				"NASA CCMC registró un aviso: %s. El refugio reduce la exposición en la demo."
				% values.messageIssueTime
			)
		"radlab_artemis_i_hera":
			var sample: Dictionary = values.samples[0]
			return (
				(
					"El detector %s midió %.3f µGy/h en Orion, Artemis I. "
					+ "La exposición en la base usa puntos de juego."
				)
				% [values.instrument_id, sample.absorbed_dose_rate]
			)
		"neows_2016_ft14":
			return (
				"%s pasó a %.2f millones de km de la Tierra el %s. Esta observación corresponde a la Tierra."
				% [
					values.name,
					float(values.miss_distance_km) / 1000000.0,
					values.datetime_as_reported
				]
			)
		"tle_iss_25544":
			return (
				"%s completa una vuelta a la Tierra en unos %.1f min según el TLE de %s."
				% [
					values.name,
					record.derived.estimated_period_minutes,
					String(values.date).left(10)
				]
			)
		"ntrs_life_support_mass":
			return (
				(
					"Por persona al día: %.2f kg de O₂, %.2f kg de agua para consumo "
					+ "y %.2f kg de sólidos alimentarios."
				)
				% [values.oxygen, values.drinking_and_food_water, values.food_solids]
			)
		"ntrs_lunar_radio":
			return (
				"A %.0f km, la señal tarda unos %.2f s de ida y %.2f s ida y vuelta."
				% [
					values.nominal_earth_moon_distance_km,
					values.one_way_seconds_rounded,
					values.round_trip_seconds_rounded
				]
			)
	return String(record.get("use", ""))


func _read_records() -> void:
	var parsed: Variant = (
		JSON.parse_string(FileAccess.get_file_as_string("res://" + String(config.data_snapshot)))
		if FileAccess.file_exists("res://" + String(config.data_snapshot))
		else null
	)
	if parsed is Dictionary and parsed.get("records") is Array:
		for record in parsed.records:
			if record is Dictionary and _valid_record(record):
				records.append(record)


func _valid_record(record: Dictionary) -> bool:
	if not record.get("source_url") is String:
		return false
	var data: Variant = record.get("observation", record.get("reference"))
	if not data is Dictionary:
		return false
	match String(record.get("id", "")):
		"nasa_lro_3d":
			return data.get("description") is String
		"donki_sep_20240510":
			return data.get("messageIssueTime") is String
		"radlab_artemis_i_hera":
			var samples: Variant = data.get("samples")
			return (
				data.get("instrument_id") is String
				and samples is Array
				and not samples.is_empty()
				and samples[0] is Dictionary
				and samples[0].get("absorbed_dose_rate") is float
			)
		"neows_2016_ft14":
			return (
				data.get("miss_distance_km") is float
				and data.get("name") is String
				and data.get("datetime_as_reported") is String
			)
		"tle_iss_25544":
			var derived: Variant = record.get("derived")
			return (
				data.get("name") is String
				and data.get("date") is String
				and derived is Dictionary
				and derived.get("estimated_period_minutes") is float
			)
		"ntrs_life_support_mass":
			return (
				data.get("oxygen") is float
				and data.get("drinking_and_food_water") is float
				and data.get("food_solids") is float
			)
		"ntrs_lunar_radio":
			return (
				data.get("nominal_earth_moon_distance_km") is float
				and data.get("one_way_seconds_rounded") is float
				and data.get("round_trip_seconds_rounded") is float
			)
	return false


func _in_range(start: float, span: float) -> bool:
	return elapsed >= start and elapsed < start + span


func _tutorial_use(player: int, station: StringName) -> String:
	if station != &"training":
		return "Usa la mesa de práctica"
	if tutorial_step == 0 and player == 0:
		_create_cargo(player, &"sample")
		tutorial_step = 1
		return "Pasa la muestra al jugador 2"
	if tutorial_step == 2 and player == 1 and cargo_kind(player) == &"sample":
		_consume_cargo(player)
		tutorial_step = 3
		return "¡Entrega correcta! Ya pueden iniciar"
	if tutorial_step == 3:
		phase = &"active"
		return "Turno iniciado"
	return "Sigue la instrucción del tutorial"


func _create_cargo(player: int, kind: StringName) -> void:
	var id := _next_crate
	_next_crate += 1
	crates[id] = {"kind": kind, "owner": player, "point": Vector3.ZERO}
	pilots[player].cargo = id


func _consume_cargo(player: int) -> void:
	crates.erase(pilots[player].cargo)
	pilots[player].cargo = 0


func _start_mining(player: int, kind: StringName) -> String:
	var pilot := pilots[player]
	if pilot.cargo != 0:
		return "Entrega o suelta la caja primero"
	if crates.size() >= 24:
		return "Recoge o entrega cajas del suelo antes de extraer más"
	if pilot.mine == kind:
		return "Extrayendo… quédate cerca"
	pilot.mine = kind
	pilot.mine_left = drill_seconds()
	return "Extrayendo… quédate cerca"


func _tick_mining(delta: float, nearby: Array[StringName]) -> void:
	for player in range(2):
		var pilot := pilots[player]
		if pilot.mine == &"":
			continue
		if pilot.mine != nearby[player] or pilot.cargo != 0:
			pilot.mine = &""
			continue
		pilot.mine_left -= delta
		if pilot.mine_left <= 0.0:
			_create_cargo(player, pilot.mine)
			pilot.mine = &""


func _refine(player: int) -> String:
	match cargo_kind(player):
		&"ice":
			var amount := int(targets.water_units_per_ice)
			if water + amount > int(runtime.water_capacity):
				return "Depósito de agua lleno"
			water += amount
			_consume_cargo(player)
			deliveries += 1
			return "+%d agua" % amount
		&"ore":
			if ore >= int(runtime.ore_capacity):
				return "Tolva de mineral llena"
			ore += 1
			_consume_cargo(player)
			deliveries += 1
			return "+1 mineral"
	return "Trae hielo o mineral"


func _operate_job(player: int, station: StringName) -> String:
	var is_crop := station == &"crop"
	var cargo: StringName = &"food" if is_crop else &"fuel"
	var supply := food if is_crop else fuel_ready
	var launch_target := int(config.launch_requirements.propellant_batches)
	if pilots[player].cargo == 0 and supply > 0:
		if is_crop:
			food -= 1
		else:
			fuel_ready -= 1
		_create_cargo(player, cargo)
		return "Lleva la caja a la plataforma"
	if float(jobs[station]) > 0.0:
		return "En proceso · %.0f s" % ceilf(float(jobs[station]))
	if not is_crop and fuel_prepared >= launch_target:
		return "Propelente suficiente · entrega los lotes"
	var cost := (
		int(runtime.crop_water) if is_crop else int(targets.water_units_per_propellant_batch)
	)
	if water < cost:
		return "Falta agua · necesitas %d" % cost
	if is_crop and food + int(targets.rations_per_crop_cycle) > int(runtime.rations_capacity):
		return "Retira raciones antes de sembrar"
	water -= cost
	jobs[station] = float(runtime.crop_seconds if is_crop else runtime.propellant_seconds)
	return "Cultivo sembrado" if is_crop else "Preparando propelente"


func _upgrade(station: StringName) -> String:
	var is_drill := station == &"drill"
	if drill if is_drill else auxiliary:
		return "Mejora instalada"
	var cost := int(targets.drill_upgrade_ore if is_drill else targets.aux_battery_ore)
	if ore < cost:
		return "Faltan %d de mineral" % (cost - ore)
	ore -= cost
	if is_drill:
		drill = true
		return "Taladro Mk2 · extrae en 4 s"
	auxiliary = true
	return "Batería auxiliar conectada"


func _eat(player: int) -> String:
	if not hungry and meals_clock >= 18.0:
		return "Respira aquí · el hábitat repone aire"
	if cargo_kind(player) == &"food":
		_consume_cargo(player)
	elif food > 0:
		food -= 1
	else:
		return "Cultiva una ración para la tripulación"
	hungry = false
	meals_clock = float(runtime.ration_seconds)
	return "Tripulación alimentada"


func _consume_supply() -> String:
	if not campaign.supply_pending:
		return "Sin suministros pendientes"
	var water_bonus := int(campaign.data.bonus.water)
	var rations_bonus := int(campaign.data.bonus.rations)
	if water + water_bonus > int(runtime.water_capacity):
		return "Usa agua para hacer lugar a la entrega"
	if food + rations_bonus > int(runtime.rations_capacity):
		return "Retira raciones para hacer lugar a la entrega"
	campaign.supply_pending = false
	water += water_bonus
	food += rations_bonus
	return "Suministros · +%d agua y +%d ración" % [water_bonus, rations_bonus]


func _radio() -> String:
	if earth_ok:
		return "Tierra confirmó la lista de vuelo"
	if radio_left > 0.0:
		return "La señal está viajando"
	if radio_cut():
		return (
			"Relé en sombra · espera el regreso de la luz"
			if shadow_active()
			else "Sin señal · la radio volverá al despejarse la ruta"
		)
	radio_left = float(config.radio_round_trip_seconds)
	return "Lista enviada · retorno en 2,56 s"


func _pad(player: int) -> String:
	match cargo_kind(player):
		&"fuel":
			if fuel_loaded < int(config.launch_requirements.propellant_batches):
				fuel_loaded += 1
				_consume_cargo(player)
				deliveries += 1
				return "Propelente cargado"
		&"food":
			if food_loaded < int(config.launch_requirements.rations):
				food_loaded += 1
				_consume_cargo(player)
				deliveries += 1
				return "Ración cargada"
	if pilots[player].cargo != 0:
		return "Esa caja no se necesita a bordo"
	return _embark(player)


func _embark(player: int) -> String:
	if pilots[player].seated:
		pilots[player].seated = false
		phase = &"active"
		countdown = 0.0
		return "Asiento libre · cuenta cancelada"
	if fuel_loaded < int(config.launch_requirements.propellant_batches):
		return "Falta propelente a bordo"
	if food_loaded < int(config.launch_requirements.rations):
		return "Faltan raciones a bordo"
	if not earth_ok:
		return "Pide confirmación en la radio"
	if not window_open():
		return "La ventana de lanzamiento aún no es segura"
	pilots[player].seated = true
	pilots[player].mine = &""
	if crew_seated() == int(config.launch_requirements.seated_players):
		phase = &"countdown"
		countdown = float(runtime.countdown)
		return "¡Ambos a bordo!"
	return "A bordo · espera a tu compañero"


func _tick_power(delta: float) -> void:
	if not shadow_active() and not energy_cut():
		charge = minf(battery_capacity(), charge + float(runtime.solar_output) * delta)
	life_powered = _draw(float(runtime.life_draw) * delta)
	var second: StringName = &"fuel" if priority == &"crop" else &"crop"
	for station: StringName in [priority, second]:
		powered[station] = jobs[station] > 0.0 and _draw(float(runtime.job_draw) * delta)
		if powered[station]:
			jobs[station] = maxf(0.0, float(jobs[station]) - delta)
			if jobs[station] == 0.0:
				_complete_job(station)


func _draw(cost: float) -> bool:
	if charge < cost:
		return false
	charge -= cost
	return true


func _complete_job(station: StringName) -> void:
	if station == &"crop":
		food = mini(int(runtime.rations_capacity), food + int(targets.rations_per_crop_cycle))
		crops_harvested += 1
	else:
		fuel_ready += 1
		fuel_prepared += 1


func _tick_crew(delta: float, sheltered: Array[bool]) -> void:
	meals_clock = maxf(0.0, meals_clock - delta)
	hungry = meals_clock == 0.0
	filter_clock = maxf(0.0, filter_clock - delta)
	if life_powered and filter_clock == 0.0 and water > 0 and _needs_air(sheltered):
		water -= 1
		filter_clock = float(runtime.life_water_cycle)
	for player in range(2):
		var pilot := pilots[player]
		var inside: bool = sheltered[player] or pilot.seated
		var drain := float(runtime.air_drain) * (1.55 if hungry else 1.0)
		if pilot.seated or (inside and life_powered and filter_clock > 0.0):
			drain = -float(runtime.air_recovery)
		pilot.air = clampf(float(pilot.air) - drain * delta, 0.0, float(runtime.air_capacity))
		if storm_active() and not inside:
			var scale := 1.0
			if practice:
				scale = float(runtime.practice_exposure_scale)
			elif solo:
				scale = float(runtime.solo_exposure_scale)
			pilot.exposure = minf(
				float(runtime.exposure_limit),
				float(pilot.exposure) + float(runtime.exposure_rate) * scale * delta
			)
		if pilot.air <= 0.0:
			_fail("El astronauta %d se quedó sin aire." % (player + 1))
		elif pilot.exposure >= float(runtime.exposure_limit):
			_fail("El astronauta %d superó el límite de exposición." % (player + 1))
		if terminal():
			return


func _needs_air(sheltered: Array[bool]) -> bool:
	for player in range(2):
		if sheltered[player] and pilots[player].air < 85.0:
			return true
	return false


func _fail(reason: String) -> void:
	phase = &"failed"
	result = reason
