extends Node

const MISSION := preload("res://src/mission.tscn")
const CASES := 16

var _failures := 0
var _assertions := 0
var _mission: Node2D
var _map: LunarMap
var _hud: MissionHUD


func _ready() -> void:
	AdversarialDirector.set_process(false)
	_mission = MISSION.instantiate()
	add_child(_mission)
	_map = _mission.get_node("LunarMap")
	_hud = _mission.get_node("Interface/HUD")
	_mission.set_process(false)
	await get_tree().process_frame
	_check_context()
	_check_controls()
	var capture := "--capture" in OS.get_cmdline_user_args()
	if capture:
		await _capture("briefing")
	await _check_walkthrough(capture)
	_check_interaction_locks()
	_check_atomic_budget()
	_check_power()
	_check_suit_failure()
	_check_habitat_failure()
	_check_deadline()
	await _check_build_controls(capture)
	_check_construction_limits()
	_check_module_effects()
	await _check_drill(capture)
	await _check_reception_shift(capture)
	_check_missed_crew()
	_check_reset()
	print("ARTEMIS SUITE: %d cases, %d assertions, %d failed" % [CASES, _assertions, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _check_context() -> void:
	var graph: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://context_core/project_graph.json")
	)
	var ids := {}
	for node: Dictionary in graph.nodes:
		_check(not ids.has(node.id), "unique graph node %s" % node.id)
		ids[node.id] = true
		if node.has("path"):
			var path := "res://" + String(node.path)
			_check(FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path), path)
	for edge: Array in graph.edges:
		_check(ids.has(edge[0]) and ids.has(edge[2]), "graph edge %s" % str(edge))


func _check_controls() -> void:
	_check(AdversarialDirector.phase == AdversarialDirector.Phase.BRIEFING, "starts in briefing")
	_check(_map.astronaut.cell == LunarMap.SPAWN, "initial spawn")
	for station in _map.stations:
		_check(not _map.can_walk(station.footprint.position), "station blocks movement")
	_check(not _map.can_walk(Vector2i.ZERO), "crate blocks movement")
	_check(not _map.can_walk(LunarMap.EXIT_CELL), "EVA area inaccessible from base")
	for key in [&"life", &"solar", &"garden", &"airlock"]:
		var station := _station(key)
		_check(not _map.route(LunarMap.SPAWN, Vector2i.ZERO, station).is_empty(), "route to " + key)
	_check(
		_map.route(LunarMap.SPAWN, Vector2i.ZERO, _station(&"beacon")).is_empty(),
		"no path to EVA station from base"
	)


func _check_walkthrough(capture: bool) -> void:
	AdversarialDirector.start()
	_check(AdversarialDirector.phase == AdversarialDirector.Phase.ACTIVE, "HUD starts scenario")
	for key in [&"life", &"garden"]:
		_click_station(key)
		_hud.action_requested.emit()
	_check(AdversarialDirector.support.enabled, "life support starts via HUD")
	_check(AdversarialDirector.garden.active, "planting through HUD")
	_check(AdversarialDirector.build(&"walkway", Vector2i(4, 9)), "walkthrough connects the deck")
	_check(AdversarialDirector.build(&"habitat", Vector2i(4, 10)), "walkthrough places a habitat")
	_tick(33)
	_check(AdversarialDirector.solar.condition == SolarArray.Condition.CLEAR, "no early dust")
	_tick(1)
	_check(is_equal_approx(AdversarialDirector.snapshot().solar_kw, 0.27), "dust lowers generation")
	_check(AdversarialDirector.garden.minutes == 18, "garden reached goal")
	if capture:
		await _capture("lunar")
	_click_station(&"solar")
	_press_key(KEY_E)
	_check(
		is_equal_approx(AdversarialDirector.snapshot().solar_kw, 1.2),
		"cleaning recovers generation"
	)
	_click_station(&"airlock")
	var before := ResourceManager.amount(&"o2")
	_hud.action_requested.emit()
	_check(_map.outside and _map.astronaut.cell == LunarMap.EXIT_CELL, "airlock exit placement")
	_check(
		is_equal_approx(before - ResourceManager.amount(&"o2"), 0.032),
		"suit receives habitat oxygen"
	)
	_click_station(&"beacon")
	_check(_map.outside and _map.in_reach(_station(&"beacon"), _map.astronaut.cell), "EVA path")
	if capture:
		await _capture("eva")
	_hud.action_requested.emit()
	_check(AdversarialDirector.eva.stage == EVA.Stage.CALIBRATED, "valid calibration")
	_click_station(&"airlock")
	_hud.action_requested.emit()
	_check(
		not _map.outside and _map.astronaut.cell == LunarMap.ENTRY_CELL, "airlock return placement"
	)
	_check(AdversarialDirector.eva.stage == EVA.Stage.COMPLETE, "EVA completed")
	_tick(86)
	_check(AdversarialDirector.minute == 120, "run ends on the deadline")
	_check(AdversarialDirector.phase == AdversarialDirector.Phase.SUCCESS, "mission success")


func _check_interaction_locks() -> void:
	_hud.reset_requested.emit()
	AdversarialDirector.start()
	var before := ResourceManager.amounts()
	_mission.select_station(_station(&"life"))
	_hud.action_requested.emit()
	_check(not AdversarialDirector.support.enabled, "action blocked while en route")
	_check(ResourceManager.amounts() == before, "out-of-range action does not modify reserves")
	_check(not AdversarialDirector.perform(&"solar"), "early solar cleaning rejected")
	_check(not AdversarialDirector.perform(&"beacon"), "indoor calibration rejected")
	_check(not AdversarialDirector.perform(&"airlock"), "early EVA rejected")
	_check(AdversarialDirector.perform(&"garden"), "initial garden transaction")
	before = ResourceManager.amounts()
	_check(not AdversarialDirector.perform(&"garden"), "duplicate garden transaction rejected")
	_check(ResourceManager.amounts() == before, "duplicate transaction does not spend water")
	_hud.pause_requested.emit()
	_tick(10)
	_check(AdversarialDirector.minute == 0, "pause freezes the clock")
	_check(not AdversarialDirector.perform(&"life"), "pause blocks operations")
	_press_key(KEY_ESCAPE)
	_tick(1)
	_check(AdversarialDirector.minute == 1, "Escape resumes the clock")


func _check_atomic_budget() -> void:
	_prepare_eva()
	ResourceManager.adjust(&"energy", -1.0)
	var before := ResourceManager.amounts()
	_check(not AdversarialDirector.perform(&"airlock"), "low-battery EVA rejected")
	_check(ResourceManager.amounts() == before, "rejected EVA leaves both reservoirs unchanged")
	_check(not ResourceManager.consume({&"o2": 0.012, &"water": INF}), "non-finite cost rejected")
	_check(ResourceManager.amounts() == before, "invalid multi-resource purchase is atomic")
	_check(not ResourceManager.consume({&"unsupported": 0.0}), "unknown reservoir rejected")
	ResourceManager.adjust(&"o2", NAN)
	_check(ResourceManager.amounts() == before, "non-finite flow rejected")
	ResourceManager.adjust(&"energy", 0.1)
	_check(AdversarialDirector.perform(&"airlock"), "EVA accepted after refill")
	_tick(1)
	var habitat_o2 := ResourceManager.amount(&"o2")
	var suit_o2 := AdversarialDirector.eva.oxygen
	_check(AdversarialDirector.perform(&"airlock"), "can bail out of an incomplete EVA")
	_check(AdversarialDirector.eva.stage == EVA.Stage.INDOORS, "uncompleted EVA can retry")
	_check(
		is_equal_approx(ResourceManager.amount(&"o2"), habitat_o2 + suit_o2), "reclaims suit oxygen"
	)


func _check_power() -> void:
	_begin_fresh()
	AdversarialDirector.perform(&"life")
	_tick(34)
	AdversarialDirector.perform(&"garden")
	ResourceManager.adjust(&"energy", -1.0)
	ResourceManager.adjust(&"energy", 0.00913)
	_tick(1)
	var data := AdversarialDirector.snapshot()
	_check(data.essential_powered and data.support_powered, "priority loads receive power")
	_check(data.crop == 0 and not data.garden_powered, "garden waits for full power")
	var before := ResourceManager.amount(&"o2")
	_tick(1)
	data = AdversarialDirector.snapshot()
	_check(data.essential_powered and not data.support_powered, "battery depletes in stages")
	_check(ResourceManager.amount(&"o2") < before, "oxygen drops without powered support")
	_tick(1)
	_check(not AdversarialDirector.snapshot().essential_powered, "essential grid reports blackout")
	_check(AdversarialDirector.perform(&"solar"), "solar can be cleaned during blackout")
	_tick(1)
	_check(AdversarialDirector.snapshot().crop == 1, "garden resumes after cleaning")
	_check(ResourceManager.amount(&"energy") > 0.0, "solar recharges the battery")


func _check_suit_failure() -> void:
	_prepare_eva()
	AdversarialDirector.perform(&"airlock")
	_tick(37)
	_check(AdversarialDirector.phase == AdversarialDirector.Phase.ACTIVE, "suit lasts 37 steps")
	_tick(1)
	_check(
		AdversarialDirector.phase == AdversarialDirector.Phase.FAILED, "suit depletion is terminal"
	)
	_check(AdversarialDirector.result.contains("traje"), "suit failure explained")
	var minute := AdversarialDirector.minute
	_tick(10)
	_check(AdversarialDirector.minute == minute, "terminal mission stops ticking")
	_check(not AdversarialDirector.perform(&"airlock"), "terminal state blocks return")


func _check_habitat_failure() -> void:
	for key in [&"o2", &"water", &"co2"]:
		_begin_fresh()
		if key == &"co2":
			ResourceManager.adjust(key, 10.0)
		else:
			ResourceManager.adjust(key, -10.0)
		_tick(1)
		_check(
			AdversarialDirector.phase == AdversarialDirector.Phase.FAILED,
			"%s limit is terminal" % key
		)
	_check_reserves()
	_begin_fresh()
	AdversarialDirector.perform(&"life")
	ResourceManager.adjust(&"water", -1.0)
	_tick(1)
	_check(
		AdversarialDirector.phase == AdversarialDirector.Phase.FAILED,
		"recycling insufficient for crew demand cannot hide a water shortage"
	)


func _check_deadline() -> void:
	_begin_fresh()
	AdversarialDirector.perform(&"life")
	_tick(34)
	AdversarialDirector.perform(&"solar")
	_tick(86)
	_check(
		(
			AdversarialDirector.phase == AdversarialDirector.Phase.FAILED
			and AdversarialDirector.result.contains("pendientes")
		),
		"safe reserves alone do not win the scenario"
	)
	_prepare_eva()
	AdversarialDirector.perform(&"airlock")
	AdversarialDirector.perform(&"beacon")
	AdversarialDirector.perform(&"airlock")
	_tick(86)
	_check(
		AdversarialDirector.phase == AdversarialDirector.Phase.FAILED, "construction is required"
	)


func _check_build_controls(capture: bool) -> void:
	_begin_fresh()
	_click(Vector2(840, 671))
	var materials := AdversarialDirector.construction.materials
	_check(_map.blueprint == &"walkway", "build button opens the catalog")
	var first_tile := _map.to_global(LunarMap.project(Vector2i(3, 9)))
	_mouse_button(first_tile, true)
	_check(
		AdversarialDirector.construction.materials == materials - 1,
		"placing a walkway charges one material"
	)
	_check(
		not _map.route(LunarMap.SPAWN, Vector2i(3, 9)).is_empty(),
		"new walkway is reachable from the base"
	)
	_drag_to(_map.to_global(LunarMap.project(Vector2i(3, 10))))
	_check(_map.can_walk(Vector2i(3, 10)), "dragged walkway extends the route")
	_mouse_button(first_tile, false)
	_drag_to(_map.to_global(LunarMap.project(Vector2i(3, 11))))
	_check(not _map.can_walk(Vector2i(3, 11)), "drag begins only with a map press")
	_click(Vector2(295, 669))
	_check(_map.blueprint == &"habitat", "clicking habitat selects its blueprint")
	_click(_map.to_global(LunarMap.project(Vector2i(4, 9))))
	_check(not _map.can_walk(Vector2i(4, 9)), "site blocks movement while under construction")
	_check(
		AdversarialDirector.construction.completed_modules == 0, "site begins under construction"
	)
	_tick(4)
	_check(
		AdversarialDirector.construction.completed_modules == 1, "site finishes after four steps"
	)
	_check(is_equal_approx(ResourceManager.capacity(&"o2"), 0.36), "habitat adds oxygen capacity")
	if capture:
		_drag_to(_map.to_global(LunarMap.project(Vector2i(1, 9))), false)
		await _capture("construction")
	_press_key(KEY_ESCAPE)
	_check(_map.blueprint == &"", "Escape closes the catalog")
	_check(
		AdversarialDirector.phase == AdversarialDirector.Phase.ACTIVE,
		"closing catalog keeps clock running"
	)
	_click(_map.to_global(LunarMap.project(Vector2i(3, 10))))
	_check(not _map.astronaut.path.is_empty(), "clicking a new walkway starts a route")


func _check_construction_limits() -> void:
	_begin_fresh()
	var bay := AdversarialDirector.construction
	var before := bay.materials
	_check(
		not AdversarialDirector.build(&"walkway", Vector2i(8, 9)), "crate edge cannot seed routes"
	)
	_check(not AdversarialDirector.build(&"habitat", Vector2i(2, 10)), "isolated module rejected")
	_check(not AdversarialDirector.build(&"battery", Vector2i(8, 11)), "whole footprint must fit")
	_check(not AdversarialDirector.build(&"unknown", Vector2i(2, 9)), "unknown blueprint rejected")
	_check(bay.materials == before and bay.pieces.is_empty(), "invalid placements don't spend")
	_check(AdversarialDirector.build(&"walkway", Vector2i(1, 9)), "valid root")
	_check(not AdversarialDirector.build(&"walkway", Vector2i(1, 9)), "duplicate tile rejected")
	_check(not AdversarialDirector.build(&"habitat", Vector2i(0, 9)), "overlap rejected")
	AdversarialDirector.toggle_pause()
	_check(not AdversarialDirector.build(&"walkway", Vector2i(1, 10)), "pause locks construction")
	AdversarialDirector.toggle_pause()
	for x in range(2, 8):
		AdversarialDirector.build(&"walkway", Vector2i(x, 9))
	_check(AdversarialDirector.build(&"greenhouse", Vector2i(3, 10)), "budget allows first module")
	_check(AdversarialDirector.build(&"battery", Vector2i(5, 10)), "budget allows second module")
	_check(bay.materials == 1, "connected jobs charge exactly once")
	_check(
		not AdversarialDirector.build(&"habitat", Vector2i(1, 10)), "insufficient material rejected"
	)
	_check(bay.materials == 1, "rejected module does not charge")


func _check_module_effects() -> void:
	_begin_fresh()
	AdversarialDirector.perform(&"life")
	AdversarialDirector.perform(&"garden")
	AdversarialDirector.build(&"walkway", Vector2i(2, 9))
	AdversarialDirector.build(&"walkway", Vector2i(4, 9))
	AdversarialDirector.build(&"greenhouse", Vector2i(1, 10))
	AdversarialDirector.build(&"battery", Vector2i(3, 10))
	_tick(2)
	_check(
		is_equal_approx(ResourceManager.capacity(&"energy"), 0.84), "battery waits for completion"
	)
	_tick(1)
	_check(is_equal_approx(ResourceManager.capacity(&"energy"), 1.24), "battery adds capacity")
	_check(AdversarialDirector.construction.completed_modules == 1, "jobs finish by deadline")
	_tick(1)
	_check(AdversarialDirector.garden.minutes == 4, "unfinished greenhouse has no effect")
	_tick(1)
	_check(AdversarialDirector.garden.minutes == 6, "greenhouse doubles growth after completion")
	_tick(10)
	_check(AdversarialDirector.garden.minutes == 18, "fast growth clamps at goal")
	_check(is_equal_approx(ResourceManager.capacity(&"energy"), 1.24), "bonus is applied only once")
	_check(AdversarialDirector.construction.completed_modules == 2, "both modules count once")


func _check_drill(capture: bool) -> void:
	_hud.reset_requested.emit()
	_click(Vector2(116, 351))
	_check(
		AdversarialDirector.drill.step == TrainingDrill.Step.SUPPORT, "practice button opens drill"
	)
	_tick(10)
	_check(AdversarialDirector.minute == 0, "tutorial freezes clock")
	_check(not AdversarialDirector.perform(&"garden"), "tutorial waits for the demonstrated action")
	if capture:
		await _capture("tutorial")
	_click_station(&"life")
	_press_key(KEY_E)
	_click_station(&"garden")
	_press_key(KEY_E)
	_check(AdversarialDirector.filter_fault, "practice injects a filter fault")
	_click_station(&"life")
	_check(not AdversarialDirector.perform(&"life"), "repair requires diagnosis")
	_click(Vector2(320, 688))
	_check(not AdversarialDirector.filter_diagnosed, "incorrect diagnosis does not unlock repair")
	_click(Vector2(130, 688))
	_check(AdversarialDirector.filter_diagnosed, "correct diagnosis unlocks repair")
	_press_key(KEY_E)
	_check(not AdversarialDirector.filter_fault, "practices the actual repair interaction")
	_press_key(KEY_B)
	_click(_map.to_global(LunarMap.project(Vector2i(3, 9))))
	_click(Vector2(295, 669))
	_click(_map.to_global(LunarMap.project(Vector2i(4, 9))))
	_check(
		AdversarialDirector.construction.completed_modules == 1, "practice completes construction"
	)
	_check(AdversarialDirector.reception.waiting().name == "Cadetes", "practice stages a crew")
	_press_key(KEY_ESCAPE)
	_click_station(&"reception")
	_press_key(KEY_E)
	_check(
		AdversarialDirector.drill.step == TrainingDrill.Step.COMPLETE, "practice can be completed"
	)
	_click(Vector2(116, 351))
	_check(AdversarialDirector.reception_enabled, "then launches the full mission")
	_check(
		AdversarialDirector.construction.pieces.is_empty(), "full mission has its own base state"
	)


func _check_reception_shift(capture: bool) -> void:
	_hud.reset_requested.emit()
	_click(Vector2(285, 351))
	var director := AdversarialDirector
	_check(director.reception_enabled, "briefing can start mission directly")
	director.perform(&"life")
	director.perform(&"garden")
	director.build(&"walkway", Vector2i(3, 9))
	director.build(&"habitat", Vector2i(4, 9))
	_tick(24)
	_check(director.reception.waiting().name == "Alfa", "Alfa arrives on schedule")
	if capture:
		await _capture("reception")
	_click_station(&"reception")
	_press_key(KEY_E)
	_check(director.snapshot().crew == 4, "admission increases live crew")
	var entrance := _map.berth_entrance(Vector2i(4, 9))
	_check(
		not _map.route(CrewVisuals.ARRIVAL_CELLS[0], entrance, null, true).is_empty(),
		"the dock connects to assigned beds"
	)
	for step in range(24):
		_map.visitors._process(0.25)
	_check(_map.visitors.seated_count() == 2, "both visitors reach their bunks")
	if capture:
		await _capture("guests")
	_check(director.reception.free_berths(director.construction) == 0, "Alfa occupies the bunks")
	var oxygen := ResourceManager.amount(&"o2")
	_tick(10)
	_check(ResourceManager.amount(&"o2") < oxygen, "visitors increase oxygen demand")
	director.perform(&"solar")
	director.perform(&"airlock")
	director.perform(&"beacon")
	director.perform(&"airlock")
	_tick(26)
	_check(director.reception.waiting().name == "Bravo", "Bravo arrives while Alfa stays")
	_check(not director.perform(&"reception"), "occupied beds cannot be double booked")
	_tick(12)
	_check(director.reception.served == 1, "Alfa leaves and releases beds")
	_check(director.perform(&"reception"), "Bravo can reuse the beds")
	_tick(4)
	_check(director.filter_fault, "filter fault triggers during the shift")
	var materials := director.construction.materials
	director.diagnose_filter(&"co2")
	_check(director.perform(&"life"), "filter can be replaced")
	_check(director.construction.materials == materials - 2, "repair spends materials once")
	_tick(74)
	_check(director.reception.served == 2, "both trips served")
	_check(director.phase == director.Phase.SUCCESS, "reception mission can be won")


func _check_missed_crew() -> void:
	_hud.reset_requested.emit()
	AdversarialDirector.start_reception()
	AdversarialDirector.perform(&"life")
	_tick(24)
	_check(not AdversarialDirector.perform(&"reception"), "admission requires connected housing")
	_tick(27)
	var alpha: Dictionary = AdversarialDirector.reception.waves[0]
	_check(alpha.status == CrewReception.Status.MISSED, "missed window changes arrival state")


func _check_reset() -> void:
	_hud.reset_requested.emit()
	_check(AdversarialDirector.minute == 0 and not _map.outside, "reset clears clock and EVA")
	_check(_map.astronaut.cell == LunarMap.SPAWN, "reset restores position")
	_check(
		AdversarialDirector.phase == AdversarialDirector.Phase.BRIEFING, "reset restores briefing"
	)
	_check(is_equal_approx(ResourceManager.amount(&"water"), 0.84), "reset restores reserves")
	_check(
		not AdversarialDirector.support.enabled and not AdversarialDirector.garden.active,
		"reset clears work"
	)
	_check_reserves()
	_check(AdversarialDirector.construction.pieces.is_empty(), "reset removes all construction")
	_check(not _map.can_walk(Vector2i(2, 9)), "reset removes new routes")


func _begin_fresh() -> void:
	_hud.reset_requested.emit()
	AdversarialDirector.start()


func _prepare_eva() -> void:
	_begin_fresh()
	AdversarialDirector.perform(&"life")
	AdversarialDirector.perform(&"garden")
	_tick(34)
	AdversarialDirector.perform(&"solar")


func _tick(quantity: int) -> void:
	for index in range(quantity):
		AdversarialDirector.tick_minute()
		_check_reserves()


func _check_reserves() -> void:
	for key: StringName in ResourceManager.KEYS:
		var value := ResourceManager.amount(key)
		_check(
			is_finite(value) and value >= 0.0 and value <= ResourceManager.capacity(key),
			"%s reservoir bounded" % key
		)


func _click_station(key: StringName) -> void:
	var station := _station(key)
	var target := _map.to_global(station.position + Vector2(0, station.label_offset - 4))
	_click(target)
	_check(_map.station_at(_map.to_local(target)) == station, "label picks " + key)
	for step in range(32):
		var previous := _map.astronaut.cell
		_mission._process(0.2)
		var next := _map.astronaut.cell
		if previous != next:
			_check(_map.can_walk(next) and previous.distance_to(next) == 1.0, "legal path step")
		if _map.astronaut.path.is_empty():
			break
	_check(_map.in_reach(station, _map.astronaut.cell), "arrives in range of " + key)


func _click(point: Vector2) -> void:
	for pressed: bool in [true, false]:
		_mouse_button(point, pressed)


func _mouse_button(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	get_viewport().push_input(event, true)


func _drag_to(point: Vector2, painting: bool = true) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if painting else 0
	get_viewport().push_input(event, true)


func _press_key(physical: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = physical
	event.pressed = true
	get_viewport().push_input(event, true)


func _station(key: StringName) -> Station:
	for station in _map.stations:
		if station.key == key:
			return station
	return null


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := OS.get_environment("TEMP").path_join("artemis-%s.png" % name)
	_check(image.save_png(path) == OK, "saved rendered capture %s" % name)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures += 1
		push_error("TEST: " + description)
