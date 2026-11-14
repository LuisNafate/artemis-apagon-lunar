extends Node2D

const HOTKEYS := {
	KEY_D: Vector2i.RIGHT,
	KEY_RIGHT: Vector2i.RIGHT,
	KEY_S: Vector2i.DOWN,
	KEY_DOWN: Vector2i.DOWN,
	KEY_A: Vector2i.LEFT,
	KEY_LEFT: Vector2i.LEFT,
	KEY_W: Vector2i.UP,
	KEY_UP: Vector2i.UP,
}

var _selected: Station
var _data: Dictionary
var _walking_to_station := false
var _painting_walkway := false

@onready var map: LunarMap = $LunarMap
@onready var labels: Node2D = $LunarMap/WorldLabels
@onready var hud: MissionHUD = $Interface/HUD


func _ready() -> void:
	labels.z_index = 2
	labels.draw.connect(func() -> void: map.paint_labels(labels))
	hud.begin_requested.connect(_begin)
	hud.practice_requested.connect(AdversarialDirector.start_drill)
	hud.action_requested.connect(_operate)
	hud.pause_requested.connect(AdversarialDirector.toggle_pause)
	hud.reset_requested.connect(_reset)
	hud.build_toggled.connect(_toggle_build)
	hud.blueprint_selected.connect(_set_blueprint)
	hud.diagnosis_selected.connect(_diagnose)
	EventBus.telemetry_changed.connect(_refresh)
	_refresh(AdversarialDirector.snapshot())


func _process(delta: float) -> void:
	if _data.phase != AdversarialDirector.Phase.ACTIVE:
		return
	var agent := map.astronaut
	var cell := map.ground_cell(map.get_local_mouse_position())
	if cell != map.hover:
		map.hover = cell
		map.queue_redraw()
		if map.blueprint != &"":
			_refresh_blueprint()
	var prior_steps := agent.path.size()
	if prior_steps == 0 and map.blueprint == &"":
		for key: int in HOTKEYS:
			if Input.is_physical_key_pressed(key):
				var next: Vector2i = agent.cell + HOTKEYS[key]
				if map.can_walk(next):
					agent.path.assign([next])
					_selected = null
					_walking_to_station = false
				break
	agent.advance(delta)
	if prior_steps != agent.path.size():
		map.queue_redraw()
		_update_selection()
	if agent.path.is_empty():
		_walking_to_station = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			if map.blueprint != &"":
				_set_blueprint(&"")
			else:
				AdversarialDirector.toggle_pause()
		elif event.physical_keycode == KEY_B:
			_toggle_build()
		elif event.physical_keycode == KEY_E:
			_operate()
	if _data.phase != AdversarialDirector.Phase.ACTIVE:
		return
	if event is InputEventMouseMotion and map.blueprint != &"":
		var hovered := map.ground_cell(_to_map(event.position))
		if _painting_walkway and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			if hovered != map.hover:
				_place_blueprint(hovered, false)
		else:
			map.hover = hovered
			_refresh_blueprint()
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_RIGHT:
				_set_blueprint(&"")
			MOUSE_BUTTON_LEFT:
				_click_map(_to_map(event.position))


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_painting_walkway = false


func _to_map(point: Vector2) -> Vector2:
	return map.get_global_transform_with_canvas().affine_inverse() * point


func _click_map(point: Vector2) -> void:
	var destination := map.ground_cell(point)
	if map.blueprint != &"":
		_painting_walkway = map.blueprint == &"walkway"
		_place_blueprint(destination, true)
		return
	var station := map.station_at(point)
	if station != null:
		select_station(station)
	elif map.can_walk(destination):
		_navigate(destination, null)


func _toggle_build() -> void:
	var preferred := &"habitat" if _data.drill == TrainingDrill.Step.BERTHS else &"walkway"
	_set_blueprint(preferred if map.blueprint == &"" else &"")


func _set_blueprint(kind: StringName) -> void:
	if kind != &"" and (_data.phase != AdversarialDirector.Phase.ACTIVE or map.outside):
		return
	map.blueprint = kind
	_painting_walkway = false
	map.queue_redraw()
	_refresh_blueprint()
	_update_selection()


func _place_blueprint(cell: Vector2i, explain: bool) -> void:
	map.hover = cell
	var status := AdversarialDirector.build_status(map.blueprint, cell)
	if status.is_empty():
		AdversarialDirector.build(map.blueprint, cell)
	elif explain:
		EventBus.message_posted.emit(status, true)
	_refresh_blueprint()


func _refresh_blueprint() -> void:
	var kind := map.blueprint
	var catalog := AdversarialDirector.construction.catalog
	if kind == &"":
		hud.show_blueprint(kind, {}, "")
	else:
		var place_status := AdversarialDirector.build_status(kind, map.hover)
		map.preview_error = place_status
		if not ConstructionBay.ZONE.has_point(map.hover):
			place_status = "Apunta al sector de ampliación."
		elif place_status.is_empty():
			var minutes := int(catalog[kind].minutes)
			place_status = (
				"Clic para instalar." if minutes == 0 else "Clic para construir · %d min." % minutes
			)
		hud.show_blueprint(kind, catalog[kind], place_status)
	labels.queue_redraw()
	if kind != &"":
		hud.show_diagnosis(false)


func select_station(station: Station) -> void:
	if _data.phase != AdversarialDirector.Phase.ACTIVE:
		return
	_navigate(Vector2i.ZERO, station)


func _navigate(destination: Vector2i, station: Station) -> void:
	var agent := map.astronaut
	var moving := not agent.path.is_empty()
	var from := agent.path[0] if moving else agent.cell
	var next_path := map.route(from, destination, station)
	if moving:
		next_path.push_front(from)
	agent.path = next_path
	_selected = station
	_walking_to_station = station != null and not next_path.is_empty()
	map.queue_redraw()
	_update_selection()


func _update_selection() -> void:
	if not _walking_to_station:
		if _selected == null or not map.in_reach(_selected, map.astronaut.cell):
			for station in map.stations:
				if map.in_reach(station, map.astronaut.cell):
					_selected = station
					break
	_refresh_map()
	var explanation := ""
	var title := ""
	var action := ""
	if _selected != null:
		title = _selected.title
		action = _action_name(_selected.key)
		if not map.astronaut.path.is_empty() and _walking_to_station:
			explanation = "En camino a la estación."
		elif not map.in_reach(_selected, map.astronaut.cell) or not map.astronaut.path.is_empty():
			explanation = "Acércate por el área transitable."
		else:
			explanation = AdversarialDirector.action_status(_selected.key)
	hud.set_station(title, action, explanation)
	var at_support := _selected != null and _selected.key == &"life"
	hud.show_diagnosis(
		(
			at_support
			and _data.filter_fault
			and not _data.filter_diagnosed
			and map.blueprint == &""
			and map.astronaut.path.is_empty()
			and map.in_reach(_selected, map.astronaut.cell)
		)
	)


func _diagnose(answer: StringName) -> void:
	if _selected != null and _selected.key == &"life" and map.blueprint == &"":
		if map.astronaut.path.is_empty() and map.in_reach(_selected, map.astronaut.cell):
			AdversarialDirector.diagnose_filter(answer)


func _operate() -> void:
	if _data.phase != AdversarialDirector.Phase.ACTIVE or _selected == null or map.blueprint != &"":
		return
	var agent := map.astronaut
	if not agent.path.is_empty() or not map.in_reach(_selected, agent.cell):
		return
	var was_outside := map.outside
	if AdversarialDirector.perform(_selected.key):
		map.outside = AdversarialDirector.eva.is_outside()
		if map.outside != was_outside:
			agent.place(LunarMap.EXIT_CELL if map.outside else LunarMap.ENTRY_CELL)
			map.queue_redraw()
			_update_selection()


func _begin() -> void:
	if AdversarialDirector.drill.step == TrainingDrill.Step.COMPLETE:
		_reset()
	AdversarialDirector.start_reception()


func _reset() -> void:
	_selected = null
	_walking_to_station = false
	map.outside = false
	map.blueprint = &""
	_painting_walkway = false
	map.astronaut.place(LunarMap.SPAWN)
	map.queue_redraw()
	hud.reset_message()
	AdversarialDirector.reset()


func _refresh(data: Dictionary) -> void:
	_data = data
	if data.phase != AdversarialDirector.Phase.ACTIVE:
		map.blueprint = &""
		_painting_walkway = false
	map.refresh_construction()
	var training: bool = data.drill != TrainingDrill.Step.OFF
	map.refresh_reception(data.reception or training, data.drill == TrainingDrill.Step.COMPLETE)
	hud.render(data)
	_update_selection()
	_refresh_blueprint()


func _refresh_map() -> void:
	var objective := _objective_station()
	for station in map.stations:
		var focused := station == _selected
		var target := station.key == objective
		var color := Color("#edb67b") if target or focused else Color("#b9cadc")
		station.set_state(_station_state(station.key), color, focused, target)
	labels.queue_redraw()


func _objective_station() -> StringName:
	if _data.drill != TrainingDrill.Step.OFF:
		return _training_station()
	if _data.filter_fault or not _data.support:
		return &"life"
	match _data.suit_stage:
		EVA.Stage.OUTSIDE, EVA.Stage.CALIBRATED:
			return &"beacon" if _data.suit_stage == EVA.Stage.OUTSIDE else &"airlock"
	if _data.solar == SolarArray.Condition.DUSTY:
		return &"solar"
	if not _data.garden:
		return &"garden"
	return _operation_target()


func _operation_target() -> StringName:
	if _data.waiting:
		return &"reception"
	if (
		_data.crop == _data.crop_goal
		and _data.solar == SolarArray.Condition.CLEANED
		and _data.suit_stage != EVA.Stage.COMPLETE
	):
		return &"airlock"
	return &""


func _training_station() -> StringName:
	match int(_data.drill):
		TrainingDrill.Step.SUPPORT, TrainingDrill.Step.FILTER:
			return &"life"
		TrainingDrill.Step.CROP:
			return &"garden"
		TrainingDrill.Step.RECEIVE:
			return &"reception"
	return &""


func _station_state(key: StringName) -> String:
	match key:
		&"life":
			var enabled_text := "HABILITADO" if _data.support else "EN ESPERA"
			var status := "ACTIVO" if _data.support_powered else enabled_text
			var fault := "FILTRO SATURADO" if _data.filter_diagnosed else "ALERTA DE CO₂"
			return fault if _data.filter_fault else status
		&"garden":
			var planted_text := "EN ESPERA" if _data.garden else "SIN REGAR"
			var progress := "CRECIENDO" if _data.garden_powered else planted_text
			return "LISTO" if _data.crop == _data.crop_goal else progress
		&"solar":
			return "%.2f kW" % _data.solar_kw
		&"airlock":
			return "REGRESO REGISTRADO" if _data.suit_stage == EVA.Stage.COMPLETE else "ACCESO EVA"
		&"reception":
			return "EN LLEGADA" if _data.waiting else "%d CAMAS LIBRES" % _data.berths
	return "CALIBRADA" if _data.suit_stage >= EVA.Stage.CALIBRATED else "SIN CALIBRAR"


func _action_name(key: StringName) -> String:
	match key:
		&"life":
			return (
				"Cambiar filtro · %d" % _data.filter_cost
				if _data.filter_fault
				else "Activar soporte vital"
			)
		&"garden":
			return "Regar · %.2f kg" % _data.water_cost
		&"solar":
			return "Limpiar paneles"
		&"airlock":
			return "Volver a la base" if AdversarialDirector.eva.is_outside() else "Iniciar salida"
		&"reception":
			return "Admitir tripulación"
	return "Calibrar baliza"
