extends Node

enum Phase { BRIEFING, ACTIVE, PAUSED, SUCCESS, FAILED }

const SCENARIO_PATH := "res://context_core/state_registry.json"

var phase := Phase.BRIEFING
var minute := 0
var result := ""
var solar := SolarArray.new()
var support := LifeSupport.new()
var garden := Greenhouse.new()
var eva := EVA.new()
var construction := ConstructionBay.new()
var reception := CrewReception.new()
var drill := TrainingDrill.new()
var reception_enabled := false
var filter_fault := false
var filter_diagnosed := false

var _config: Dictionary
var _elapsed := 0.0
var _essential_powered := true


func _ready() -> void:
	var registry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SCENARIO_PATH))
	_config = registry.scenario
	reset()


func _process(delta: float) -> void:
	if phase != Phase.ACTIVE or drill.is_running():
		return
	_elapsed += delta
	while _elapsed >= 1.0 and phase == Phase.ACTIVE:
		_elapsed -= 1.0
		tick_minute()


func reset() -> void:
	phase = Phase.BRIEFING
	minute = 0
	result = ""
	_elapsed = 0.0
	_essential_powered = true
	solar = SolarArray.new()
	support = LifeSupport.new()
	garden = Greenhouse.new()
	eva = EVA.new()
	drill = TrainingDrill.new()
	reception = CrewReception.new()
	reception_enabled = false
	filter_fault = false
	filter_diagnosed = false
	construction = ConstructionBay.new()
	construction.setup(_config.construction)
	ResourceManager.reset(_config.initial, _config.capacity)
	_publish()


func start() -> void:
	if phase == Phase.BRIEFING:
		phase = Phase.ACTIVE
		_publish()


func start_reception() -> void:
	if phase == Phase.BRIEFING:
		reception_enabled = true
		reception.setup(_config.reception, false)
		start()


func start_drill() -> void:
	if phase == Phase.BRIEFING:
		drill.start()
		reception.setup(_config.reception, true)
		start()


func _duration() -> int:
	return int(
		_config.reception.duration_minutes if reception_enabled else _config.duration_minutes
	)


func toggle_pause() -> void:
	if phase == Phase.ACTIVE:
		phase = Phase.PAUSED
	elif phase == Phase.PAUSED:
		phase = Phase.ACTIVE
	else:
		return
	_publish()


func snapshot() -> Dictionary:
	return {
		"phase": phase,
		"minute": minute,
		"duration": _duration(),
		"crew": int(_config.crew) + reception.guests,
		"result": result,
		"reserves": ResourceManager.amounts(),
		"capacity": ResourceManager.capacities(),
		"solar": solar.condition,
		"solar_kw": solar.output_kw(_config),
		"essential_powered": _essential_powered,
		"support": support.enabled,
		"support_powered": support.powered,
		"garden": garden.active,
		"garden_powered": garden.powered,
		"crop": garden.minutes,
		"crop_goal": int(_config.crop_powered_minutes),
		"water_cost": float(_config.greenhouse_water_kg),
		"suit_stage": eva.stage,
		"suit_o2": eva.oxygen,
		"suit_capacity": float(_config.suit_o2_kg),
		"suit_rate": float(_config.suit_o2_per_minute),
		"materials": construction.materials,
		"built_modules": construction.completed_modules,
		"drill": drill.step,
		"reception": reception_enabled,
		"crew_report": reception.report(minute),
		"berths": reception.free_berths(construction) if not reception.rules.is_empty() else 0,
		"waiting": not reception.waiting().is_empty(),
		"served": reception.served,
		"filter_fault": filter_fault,
		"filter_diagnosed": filter_diagnosed,
		"filter_cost": int(_config.reception.filter_cost),
	}


func build_status(kind: StringName, origin: Vector2i) -> String:
	if phase != Phase.ACTIVE or eva.is_outside():
		return "Construye durante el turno desde la base."
	if drill.is_running():
		var expected := &"walkway" if drill.step == TrainingDrill.Step.WALKWAY else &"habitat"
		if (
			drill.step not in [TrainingDrill.Step.WALKWAY, TrainingDrill.Step.BERTHS]
			or kind != expected
		):
			return "Sigue el plano indicado en la práctica."
	return construction.placement_status(kind, origin)


func build(kind: StringName, origin: Vector2i) -> bool:
	if not build_status(kind, origin).is_empty():
		return false
	construction.place(kind, origin, minute)
	if drill.is_running():
		_finish_drill_build()
	var plan: Dictionary = construction.catalog[kind]
	var message := (
		"Pasarela conectada."
		if kind == &"walkway"
		else "%s en obra · %d min." % [plan.title, int(plan.minutes)]
	)
	EventBus.message_posted.emit(message, false)
	_publish()
	return true


func tick_minute() -> void:
	if phase != Phase.ACTIVE or drill.is_running():
		return
	minute += 1
	for kind in construction.finish_ready(minute):
		EventBus.message_posted.emit("%s conectado." % construction.catalog[kind].title, false)
	if reception_enabled:
		reception.tick(minute, construction)
		if minute == int(_config.reception.filter_fault_minute):
			filter_fault = true
			EventBus.message_posted.emit(
				"Alerta de CO₂. Diagnostica la avería en Soporte vital.", true
			)
	if minute == int(_config.dust_minute):
		solar.condition = SolarArray.Condition.DUSTY
		EventBus.message_posted.emit("Cayó la generación. Limpia los paneles solares.", true)

	# La generación alimenta la carga primero y la batería cubre el déficit.
	var charge := ResourceManager.amount(&"energy")
	var budget := solar.output_kw(_config) / 60.0 + charge
	var guest_load := reception.guests * float(_config.reception.guest_kw)
	var essential := (float(_config.essential_kw) + guest_load) / 60.0
	var eclss := float(_config.eclss_kw) / 60.0
	var grow := float(_config.greenhouse_kw) / 60.0
	_essential_powered = budget >= essential
	budget -= essential if _essential_powered else budget
	var support_powered := support.enabled and budget >= eclss
	if support_powered:
		budget -= eclss
	var crop_goal := int(_config.crop_powered_minutes)
	var garden_powered := garden.active and not garden.complete(crop_goal) and budget >= grow
	if garden_powered:
		budget -= grow
	ResourceManager.adjust(&"energy", budget - charge)

	var scrub_factor := float(_config.reception.filter_scrub_factor) if filter_fault else 1.0
	var habitat_safe := support.tick(_config, support_powered, reception.guests, scrub_factor)
	var crop_was_complete := garden.complete(crop_goal)
	garden.tick(garden_powered, crop_goal, construction.garden_boost)
	if garden.complete(crop_goal) and not crop_was_complete:
		EventBus.message_posted.emit("Cultivo listo. Revisa la generación antes de salir.", false)

	eva.tick(float(_config.suit_o2_per_minute))
	if not habitat_safe:
		_fail_habitat()
	elif eva.is_outside() and eva.oxygen <= 0.0:
		_finish(Phase.FAILED, "Se agotó el O₂ del traje.")
	elif minute >= _duration():
		_close_shift()
	_publish()


func action_status(station: StringName) -> String:
	if phase != Phase.ACTIVE:
		return "Reanuda el turno para operar."
	if drill.is_running() and station != _drill_station():
		return "Sigue la instrucción de la práctica."
	var blocked := ""
	match station:
		&"life":
			if filter_fault and not filter_diagnosed:
				blocked = "Usa la telemetría para diagnosticar la avería."
			elif filter_fault and construction.materials < int(_config.reception.filter_cost):
				blocked = "Faltan materiales para cambiar el filtro."
			elif support.enabled and not filter_fault:
				blocked = "Soporte vital habilitado."
		&"reception":
			return reception.status(
				construction,
				support.powered and not filter_fault,
				garden.complete(int(_config.crop_powered_minutes))
			)
		&"garden":
			if garden.active:
				blocked = "El cultivo ya recibió agua."
			elif ResourceManager.amount(&"water") <= float(_config.greenhouse_water_kg):
				blocked = "Falta agua para regar y conservar la reserva."
		&"solar":
			if solar.condition == SolarArray.Condition.CLEAR:
				blocked = "Revisa Solar si cae la generación."
			elif solar.condition == SolarArray.Condition.CLEANED:
				blocked = (
					"Paneles limpios. Generación al %d %s."
					% [roundi(float(_config.cleaned_factor) * 100.0), "%"]
				)
		&"airlock":
			return _airlock_status()
		&"beacon":
			if eva.stage != EVA.Stage.OUTSIDE:
				blocked = "La baliza se calibra una vez durante la salida."
		_:
			blocked = "Estación desconocida."
	return blocked


func perform(station: StringName) -> bool:
	if not action_status(station).is_empty():
		return false
	var message := ""
	match station:
		&"life":
			support.enabled = true
			message = "Soporte vital habilitado. Revisa el O₂ y el CO₂."
			if filter_fault:
				construction.materials -= int(_config.reception.filter_cost)
				filter_fault = false
				message = "Filtro nuevo. La extracción de CO₂ se recuperó."
		&"reception":
			var crew_name: String = reception.waiting().name
			reception.admit(minute, construction)
			message = "%s admitida. La base consume más agua y oxígeno." % crew_name
		&"garden":
			if not ResourceManager.consume({&"water": float(_config.greenhouse_water_kg)}):
				return false
			garden.active = true
			message = (
				"Cultivo regado. Necesita %d minutos con energía." % _config.crop_powered_minutes
			)
		&"solar":
			solar.condition = SolarArray.Condition.CLEANED
			message = "Paneles limpios. Generación recuperada a %.2f kW." % solar.output_kw(_config)
		&"airlock":
			message = _cycle_airlock()
			if message.is_empty():
				return false
		&"beacon":
			eva.stage = EVA.Stage.CALIBRATED
			message = "Baliza calibrada. Vuelve a la esclusa."
	EventBus.message_posted.emit(message, false)
	if drill.is_running():
		_advance_drill()
	_publish()
	return true


func _close_shift() -> void:
	var reception_done := not reception_enabled or reception.served == reception.waves.size()
	var maintenance_done := support.enabled and solar.condition == SolarArray.Condition.CLEANED
	var expansion_done := construction.completed_modules > 0
	if (
		maintenance_done
		and expansion_done
		and eva.stage == EVA.Stage.COMPLETE
		and reception_done
		and not filter_fault
	):
		_finish(Phase.SUCCESS, "Turno completo. La base conservó sus reservas.")
	elif not reception_done:
		_finish(
			Phase.FAILED,
			"Atendiste a %d de %d tripulaciones." % [reception.served, reception.waves.size()]
		)
	else:
		_finish(Phase.FAILED, "Terminó el turno con tareas pendientes.")


func diagnose_filter(answer: StringName) -> void:
	if phase != Phase.ACTIVE or not filter_fault or filter_diagnosed:
		return
	if answer != &"co2":
		EventBus.message_posted.emit("La red tiene energía. Revisa la extracción de CO₂.", true)
		return
	filter_diagnosed = true
	EventBus.message_posted.emit("Diagnóstico confirmado. Ya puedes reemplazar el filtro.", false)
	_publish()


func _drill_station() -> StringName:
	match drill.step:
		TrainingDrill.Step.SUPPORT, TrainingDrill.Step.FILTER:
			return &"life"
		TrainingDrill.Step.CROP:
			return &"garden"
		TrainingDrill.Step.RECEIVE:
			return &"reception"
	return &""


func _advance_drill() -> void:
	drill.advance()
	match drill.step:
		TrainingDrill.Step.CROP:
			support.powered = true
		TrainingDrill.Step.FILTER:
			filter_fault = true
			EventBus.message_posted.emit("Avería de práctica. Detecta qué sistema falló.", true)
		TrainingDrill.Step.COMPLETE:
			_finish(Phase.SUCCESS, "Ya puedes iniciar la misión de recepción.")


func _finish_drill_build() -> void:
	var step := drill.step
	if step == TrainingDrill.Step.BERTHS:
		construction.finish_ready(minute + int(construction.catalog.habitat.minutes))
		reception.tick(minute, construction)
	drill.advance()


func _airlock_status() -> String:
	if eva.stage == EVA.Stage.COMPLETE:
		return "Salida completada."
	if eva.is_outside():
		return ""
	if not support.enabled or not garden.complete(int(_config.crop_powered_minutes)):
		return "Habilita soporte vital y completa el cultivo."
	if solar.condition != SolarArray.Condition.CLEANED:
		return "Recupera la generación solar antes de salir."
	if ResourceManager.amount(&"o2") <= float(_config.suit_o2_kg):
		return "Falta oxígeno para cargar el traje y conservar la reserva."
	var enough_power := ResourceManager.amount(&"energy") >= float(_config.suit_charge_kwh)
	return "" if enough_power else "Falta batería para preparar el traje."


func _cycle_airlock() -> String:
	if eva.is_outside():
		var completed := eva.stage == EVA.Stage.CALIBRATED
		eva.stage = EVA.Stage.COMPLETE if completed else EVA.Stage.INDOORS
		ResourceManager.adjust(&"o2", eva.oxygen)
		eva.oxygen = 0.0
		if completed:
			return "Regreso confirmado. Mantén las reservas hasta el fin del turno."
		return "Volviste a la base. Puedes intentar calibrar la baliza de nuevo."

	var oxygen := float(_config.suit_o2_kg)
	if not ResourceManager.consume({&"o2": oxygen, &"energy": float(_config.suit_charge_kwh)}):
		return ""
	eva.oxygen = oxygen
	eva.stage = EVA.Stage.OUTSIDE
	return "Estás fuera. Calibra la baliza y vuelve antes de agotar el traje."


func _fail_habitat() -> void:
	if ResourceManager.amount(&"o2") <= 0.0:
		_finish(Phase.FAILED, "Se agotó el O₂ de la base.")
	elif ResourceManager.amount(&"water") <= 0.0:
		_finish(Phase.FAILED, "Se agotó la reserva de agua.")
	else:
		_finish(Phase.FAILED, "El CO₂ alcanzó el límite del ejercicio.")


func _finish(next_phase: Phase, reason: String) -> void:
	phase = next_phase
	result = reason


func _publish() -> void:
	EventBus.telemetry_changed.emit(snapshot())
