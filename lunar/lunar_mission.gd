# gdlint: disable=max-public-methods,max-returns
class_name LunarMission
extends CrestSim

const SAVE_FIELDS := [
	"elapsed",
	"days",
	"cycle_seed",
	"events",
	"countdown",
	"phase",
	"charge",
	"water",
	"ore",
	"food",
	"fuel_ready",
	"fuel_loaded",
	"food_loaded",
	"life_powered",
	"drill",
	"auxiliary",
	"irrigation",
	"solar",
	"priority",
	"radio_left",
	"earth_ok",
	"jobs",
	"paid_jobs",
	"powered",
	"pilots",
	"crates",
	"_next_crate",
	"returned",
	"launch_fx",
	"refining",
	"installing",
	"crops_harvested",
	"deliveries",
	"tutorial_step",
	"crew_briefed"
]

var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH)).campaign_2026
var resources: Dictionary = rules.resource
var base: Dictionary
var difficulty: Dictionary
var base_id: String
var days := 0
var cycle_seed := 0
var events: Array = []
var connected := [true, false]
var roles := ["", ""]
var checkpoint: Dictionary
var dawn := false
var withdrew := false
var returned := false
var launch_fx := 0.0
var irrigation := false
var solar := false
var crew_briefed := false
var refining: Array = []
var installing: Dictionary = {}
var paid_jobs := {&"crop": false, &"fuel": false}


func prepare(id: String, seed_value: int, single_player: bool = false) -> void:
	solo = single_player
	base_id = id
	base = rules.bases[id]
	difficulty = rules.difficulties[base.difficulty]
	phase = &"tutorial"
	charge = float(rules.prototype_parameters.starting_charge)
	water = int(resources.water_initial)
	food = int(rules.prototype_parameters.starting_rations)
	runtime = runtime.duplicate()
	runtime.crop_seconds = rules.prototype_parameters.crop_seconds
	for pilot in pilots:
		pilot.merge({"hunger": 100.0, "mined": 0, "harvested": 0, "pending_extra": &""})
	cycle_seed = seed_value
	_roll_events()
	store_checkpoint()


func store_checkpoint() -> void:
	checkpoint = state()


func state() -> Dictionary:
	var result_state := {}
	for key: String in SAVE_FIELDS:
		result_state[key] = get(key)
	return result_state.duplicate(true)


func restore(saved: Dictionary) -> void:
	saved = saved.duplicate(true)
	for key: String in SAVE_FIELDS:
		if saved.has(key):
			set(key, saved[key])
	var list: Array[Dictionary] = []
	list.assign(pilots)
	pilots = list
	dawn = false
	withdrew = false


func shadow_active() -> bool:
	return elapsed >= float(rules.cycle.day)


func storm_active() -> bool:
	return _event_left("sep") > 0.0


func energy_cut() -> bool:
	return _event_left("outage") > 0.0


func radio_cut() -> bool:
	var cut_at := float(rules.prototype_parameters.radio_cut_at)
	return (
		base_id == rules.events.radio_cut_base and _in_range(cut_at, rules.events.radio_cut_seconds)
	)


func radio_warning() -> bool:
	var left := float(rules.prototype_parameters.radio_cut_at) - elapsed
	return (
		base_id == rules.events.radio_cut_base and left > 0.0 and left <= rules.events.radio_warning
	)


func storm_warning() -> float:
	return _warning("sep", float(difficulty.warning))


func outage_warning() -> float:
	return _warning("outage", float(rules.events.outage_warning))


func battery_capacity() -> float:
	return float(resources.aux_charge if auxiliary else resources.charge)


func drill_seconds() -> float:
	return float(resources.fast_drill_seconds if drill else resources.drill_seconds)


func wallet_rate(multiplayer: bool) -> float:
	var increment := days * float(rules.wallet.step)
	var streak := minf(float(rules.wallet.cap), float(rules.wallet.start_multiplier) + increment)
	var share := float(rules.wallet.share if multiplayer else rules.solo_mode.day_reward_share)
	return float(rules.wallet.base) * float(difficulty.coins) * streak * share


func required_seats() -> int:
	return int(rules.solo_mode.seats if solo else rules.mission.seats)


func speed_factor(player: int) -> float:
	return float(resources.hunger_speed) if pilots[player].hunger <= 0.0 else 1.0


func set_guest(present: bool, point: Vector3) -> void:
	if not present and connected[1]:
		release(1, point, false)
		pilots[1].seated = false
		pilots[1].mine = &""
		_cancel_launch()
		if phase == &"tutorial":
			finish_tutorial()
	connected[1] = present


func finish_tutorial() -> void:
	for player in range(2):
		if cargo_kind(player) == &"sample":
			_consume_cargo(player)
	for id: int in crates.keys():
		if crates[id].kind == &"sample":
			crates.erase(id)
	phase = &"active"
	crew_briefed = true
	store_checkpoint()


func use_station(player: int, station: StringName) -> String:
	if not connected[player]:
		return ""
	if phase == &"tutorial":
		if station != &"training":
			return "Acércate a la mesa de práctica"
		var message := _tutorial_use(player, station)
		if phase == &"active":
			finish_tutorial()
		return message
	if pilots[player].seated:
		return _embark(player)
	match station:
		&"ice", &"ore":
			if _collect_extraction_bonus(player, station):
				return "Caja extra del geólogo"
			return _start_mining(player, station)
		&"refinery":
			return _refine(player)
		&"crop", &"fuel":
			return _operate_job(player, station)
		&"drill", &"battery", &"irrigation", &"solar":
			return _queue_upgrade(player, station)
		&"power":
			priority = &"fuel" if priority == &"crop" else &"crop"
			return (
				"Primero %s después del aire" % ("cultivo" if priority == &"crop" else "propelente")
			)
		&"life":
			return _eat(player)
		&"radio":
			if returned:
				return "Regreso a Tierra completado"
			if radio_cut():
				return "Sin señal. Sigue preparando la nave."
			return _radio()
		&"pad":
			return "Misión completada. Sigue explorando la base." if returned else _pad(player)
	return ""


func _tutorial_use(player: int, station: StringName) -> String:
	if not solo:
		return super._tutorial_use(player, station)
	if cargo_kind(player) == &"sample":
		finish_tutorial()
		return "Muestra entregada. Empieza el día."
	if tutorial_step == 0:
		_create_cargo(player, &"sample")
		tutorial_step = 1
		return "Toca Soltar / entregar junto a la mesa"
	return "Recoge la muestra que dejaste en el suelo"


func _collect_extraction_bonus(player: int, kind: StringName) -> bool:
	var pilot := pilots[player]
	if pilot.pending_extra != kind or pilot.cargo != 0:
		return false
	_create_cargo(player, kind)
	pilot.pending_extra = &""
	return true


func _tick_mining(delta: float, nearby: Array[StringName]) -> void:
	var before := [pilots[0].mine, pilots[1].mine]
	super._tick_mining(delta, nearby)
	for player in range(2):
		var pilot := pilots[player]
		if (
			roles[player] == "geologist"
			and before[player] != &""
			and cargo_kind(player) == before[player]
		):
			pilot.mined += 1
			if int(pilot.mined) % int(rules.roles.geologist.bonus_every) == 0:
				pilot.pending_extra = before[player]


func _refine(player: int) -> String:
	if cargo_kind(player) == &"ore":
		ore += 1
		_consume_cargo(player)
		return "Mineral guardado"
	if cargo_kind(player) != &"ice":
		return "Trae hielo o mineral"
	if energy_cut() or not life_powered:
		return "Taller sin energía"
	if not refining.is_empty():
		return "La refinadora está trabajando"
	_consume_cargo(player)
	refining = [float(resources.refine_seconds)]
	return "Refinando hielo · 5 s"


func _operate_job(player: int, station: StringName) -> String:
	var crop := station == &"crop"
	var supply := food if crop else fuel_ready
	if pilots[player].cargo != 0:
		return "Suelta o entrega tu caja primero"
	if supply > 0:
		if crop:
			food -= 1
		else:
			fuel_ready -= 1
		_create_cargo(player, &"food" if crop else &"fuel")
		return "Caja recogida"
	if not crop and (returned or fuel_loaded + fuel_ready >= int(rules.mission.propellant)):
		return "La nave ya tiene su propelente"
	if jobs[station] > 0.0:
		return "En proceso · %d s" % ceili(jobs[station])
	var cost := (
		float(resources.crop_water if crop else resources.fuel_water)
		* float(difficulty.consumption)
	)
	if water < cost:
		return "Busca hielo y refínalo en el taller"
	water -= cost
	jobs[station] = float(
		rules.prototype_parameters.crop_seconds if crop else rules.prototype_parameters.fuel_seconds
	)
	paid_jobs[station] = false
	if crop:
		pilots[player].harvested += int(roles[player] == "botanist")
		powered[&"planter"] = player
	return "Cultivo regado" if crop else "Preparando propelente"


func _queue_upgrade(player: int, station: StringName) -> String:
	var flags := {
		&"drill": drill, &"battery": auxiliary, &"solar": solar, &"irrigation": irrigation
	}
	if flags[station] or installing.has(station):
		return "Mejora instalada o en montaje"
	if station == &"solar":
		return "Cambio de generación solar pendiente"
	var cost := int(rules.upgrade_costs[String(station)])
	if ore < cost:
		return "Necesitas %d de mineral" % cost
	ore -= cost
	var seconds := float(rules.prototype_parameters.upgrade_seconds)
	if roles[player] == "engineer":
		seconds /= 1.0 + float(rules.roles.engineer.speed_bonus)
	installing[station] = seconds
	return "Instalando mejora"


func _eat(player: int) -> String:
	if pilots[player].hunger >= float(resources.hunger):
		return "Aquí recuperas aire y te proteges"
	if cargo_kind(player) == &"food":
		_consume_cargo(player)
	elif food > 0:
		food -= 1
	else:
		return "Busca una ración en cultivos"
	pilots[player].hunger = minf(resources.hunger, pilots[player].hunger + resources.meal)
	return "Ración consumida"


func _embark(player: int) -> String:
	if pilots[player].seated:
		pilots[player].seated = false
		_cancel_launch()
		return "Saliste de la nave"
	if fuel_loaded < int(rules.mission.propellant) or food_loaded < int(rules.mission.food):
		return "Carga 3 lotes de propelente y 2 raciones"
	if not earth_ok:
		return "Envía la lista desde la radio"
	if not solo and not connected[1]:
		return "Falta el otro astronauta"
	if storm_active():
		return "Espera en el refugio hasta que pase la alerta"
	pilots[player].seated = true
	pilots[player].mine = &""
	return "A bordo · listo para despegar" if solo else "A bordo · espera a tu equipo"


func tick(delta: float, sheltered: Array[bool], nearby: Array[StringName]) -> void:
	if phase == &"tutorial":
		return
	dawn = false
	withdrew = false
	elapsed += delta
	if elapsed >= float(rules.cycle.period):
		elapsed -= float(rules.cycle.period)
		days += 1
		_roll_events()
		dawn = true
		store_checkpoint()
	_tick_mining(delta, nearby)
	_tick_power(delta)
	_tick_crew(delta, sheltered)
	if withdrew:
		return
	if radio_left > 0.0:
		radio_left = maxf(0.0, radio_left - delta)
		earth_ok = radio_left == 0.0
	_tick_launch(delta)


func _tick_power(delta: float) -> void:
	var consumption := float(difficulty.consumption)
	if not shadow_active():
		charge = minf(battery_capacity(), charge + delta / float(resources.solar_seconds))
	life_powered = (
		not shadow_active() or _draw(delta * consumption / float(resources.life_energy_seconds))
	)
	if energy_cut() or not life_powered:
		return
	if not refining.is_empty():
		refining[0] -= delta
		if refining[0] <= 0.0:
			water += float(resources.ice_water)
			refining.clear()
	for station: StringName in installing.keys():
		installing[station] -= delta
		if installing[station] > 0.0:
			continue
		match station:
			&"drill":
				drill = true
			&"battery":
				auxiliary = true
			&"irrigation":
				irrigation = true
		installing.erase(station)
	var later := &"fuel" if priority == &"crop" else &"crop"
	for kind: StringName in [priority, later]:
		if jobs[kind] <= 0.0:
			continue
		var cost := float(resources.crop_energy if kind == &"crop" else resources.fuel_energy)
		if not paid_jobs[kind]:
			if not _draw(cost * consumption):
				continue
			paid_jobs[kind] = true
		jobs[kind] = maxf(0.0, float(jobs[kind]) - delta)
		if jobs[kind] == 0.0:
			_complete_job(kind)


func _complete_job(station: StringName) -> void:
	if station == &"fuel":
		fuel_ready += 1
		return
	food += int(resources.efficient_rations if irrigation else resources.crop_rations)
	var grower: int = powered.get(&"planter", 0)
	var count: int = pilots[grower].harvested
	if roles[grower] == "botanist" and count % int(rules.roles.botanist.bonus_every) == 0:
		food += 1
	crops_harvested += 1


func _tick_crew(delta: float, sheltered: Array[bool]) -> void:
	var consumption := float(difficulty.consumption)
	if life_powered:
		water = maxf(0.0, water - delta * consumption / float(resources.life_water_seconds))
	for player in range(2):
		if not connected[player]:
			continue
		var pilot := pilots[player]
		pilot.hunger = maxf(
			0.0, float(pilot.hunger) - delta * consumption / float(resources.hunger_seconds)
		)
		if sheltered[player] and life_powered and water > 0.0:
			var recovery := float(resources.air_recovery)
			if energy_cut() and not auxiliary:
				recovery = float(rules.events.blackout_air_recovery)
			pilot.air = minf(resources.air, float(pilot.air) + recovery * delta)
		elif not sheltered[player]:
			var divisor := float(
				resources.air_night_seconds if shadow_active() else resources.air_day_seconds
			)
			pilot.air = maxf(0.0, float(pilot.air) - delta * consumption / divisor)
		if pilot.air <= 0.000001:
			var is_dawn := dawn
			restore(checkpoint)
			dawn = is_dawn
			radio_left = 0.0
			earth_ok = false
			pilots[0].seated = false
			pilots[1].seated = false
			_cancel_launch()
			withdrew = true
			return


func _tick_launch(delta: float) -> void:
	launch_fx = maxf(0.0, launch_fx - delta)
	if returned:
		return
	if storm_active() and phase == &"countdown":
		pilots[0].seated = false
		pilots[1].seated = false
	if (
		storm_active()
		or (not solo and not connected[1])
		or crew_seated() != required_seats()
		or not earth_ok
	):
		_cancel_launch()
		return
	if phase != &"countdown":
		phase = &"countdown"
		countdown = float(rules.mission.countdown)
		return
	countdown = maxf(0.0, countdown - delta)
	if countdown == 0.0:
		returned = true
		radio_left = 0.0
		earth_ok = false
		launch_fx = 4.0
		pilots[0].seated = false
		pilots[1].seated = false
		_cancel_launch()


func _cancel_launch() -> void:
	if phase == &"countdown":
		phase = &"active"
		countdown = 0.0


func _event_left(kind: String) -> float:
	for event: Array in events:
		if event[0] == kind and _in_range(event[1], event[2]):
			return float(event[1] + event[2]) - elapsed
	return 0.0


func _warning(kind: String, span: float) -> float:
	for event: Array in events:
		var left := float(event[1]) - elapsed
		if event[0] == kind and left > 0.0 and left <= span:
			return left
	return -1.0


func _roll_events() -> void:
	events.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([cycle_seed, days])
	var cycle := days + 1
	var margin := int(rules.events.dawn_margin)
	var last := int(rules.cycle.period) - margin
	if cycle % int(difficulty.outage_every) == 0:
		var length := int(rules.events.outage_seconds)
		var start := rng.randi_range(int(rules.cycle.day), last - length)
		events.append(["outage", start, length])
	if cycle % int(difficulty.alert_every) != 0:
		return
	var length := int(rules.events.alert_seconds)
	for index in range(int(difficulty.alerts)):
		var available: Array[int] = []
		for start in range(margin, last - length + 1):
			var allowed := true
			for event: Array in events:
				if start < int(event[1] + event[2]) and start + length > int(event[1]):
					allowed = false
			if allowed:
				available.append(start)
		events.append(["sep", available[rng.randi_range(0, available.size() - 1)], length])
