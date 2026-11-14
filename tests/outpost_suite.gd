extends Node

const SCENE := preload("res://outpost/outpost.tscn")
const TOTAL := 7

var _checks := 0
var _failed := 0


func _ready() -> void:
	_check_preview()
	_check_routes()
	_check_losses()
	_check_repairs()
	_check_empty_water()
	_check_limits()
	await _check_interface()
	print("OUTPOST SUITE: %d cases, %d assertions, %d failed" % [TOTAL, _checks, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _check_preview() -> void:
	var sim := OutpostSim.new()
	var orders := _orders()
	var initial := sim.state.duplicate()
	var next := sim.preview(orders)
	_check(sim.preview(orders) == next, "forecast is deterministic")
	_check(sim.state == initial and sim.turn == 0, "preview has no side effects")
	_check(sim.resolve(orders) == next, "commit equals forecast")
	_check(sim.state == next.state and sim.turn == 1, "commit advances exactly one turn")


func _check_routes() -> void:
	var sim := OutpostSim.new()
	for plan in ["repair", "bridge"]:
		sim.reset(0)
		_run(sim, plan)
		_check(sim.won and sim.turn == 8, "storm survives using " + plan)
		_check(int(sim.state.harvests) >= 2 and sim.state.dose == 1, "storm objectives complete")
	sim.reset(1)
	_run(sim, "repair")
	_check(sim.won and sim.turn == 8, "second scenario survives both breaks")
	_check(int(sim.state.kits) == 0, "both repairs consume kits")


func _check_losses() -> void:
	var sim := OutpostSim.new()
	_run(sim, "no farm")
	_check(sim.result.contains("comida") and not sim.won, "no crop eventually starves crew")
	sim.reset(0)
	_run(sim, "no shelter")
	_check(int(sim.state.dose) == int(sim.config.limits.dose), "storm causes irreversible exposure")
	_check(sim.result.contains("exposición") and not sim.won, "exposure terminates before victory")
	sim.reset(0)
	var orders := _orders()
	orders.life = false
	while sim.result.is_empty():
		sim.resolve(orders)
	_check(sim.result.contains("aire") and sim.turn == 3, "no life support depletes air")


func _check_repairs() -> void:
	var sim := OutpostSim.new()
	var orders := _orders()
	orders.repair = "south"
	_check(sim.preview(orders).state.kits == 2, "repair on intact branch is free")
	for index in range(3):
		orders = _orders()
		orders.inside = index == 2
		sim.resolve(orders)
	orders.inside = true
	orders.repair = "south"
	_check(not sim.preview(orders).powered.shelter, "a repaired line still needs energy")
	sim.state.charge = 1
	var planned := sim.preview(orders)
	_check(planned.state.south and planned.state.kits == 1, "repair follows announced damage")
	_check(planned.powered.shelter, "same-turn repair restores ventilation")
	orders.repair = ""
	orders.bridge = true
	planned = sim.preview(orders)
	_check(not planned.state.south and planned.powered.shelter, "bridge bypasses the break")
	sim.state.kits = 0
	planned = sim.preview(orders)
	_check(not planned.state.bridge and not planned.powered.shelter, "cannot overspend kits")
	_check(
		int(planned.state.kits) == 0 and int(planned.state.dose) >= 3, "passive shelter fallback"
	)


func _check_empty_water() -> void:
	var sim := OutpostSim.new()
	sim.state.water = 2
	sim.state.growth = 1
	var orders := _orders()
	orders.life = false
	var next := sim.preview(orders)
	_check(next.state.growth == 2 and next.state.harvests == 0, "water shortage delays harvest")
	orders.life = true
	next = sim.preview(orders)
	_check(next.state.harvests == 1 and next.state.water == 1, "restoring water allows harvest")


func _check_limits() -> void:
	var sim := OutpostSim.new()
	var orders := _orders()
	_run(sim, "repair")
	var finished := sim.state.duplicate()
	sim.resolve(orders)
	_check(sim.turn == 8 and sim.state == finished, "terminal commit is idempotent")
	sim.reset(0)
	_check(sim.result.is_empty() and not sim.won and sim.turn == 0, "restart restores active state")
	_check(
		sim.state.air == 6 and sim.state.kits == 2 and not sim.state.bridge,
		"restart restores resources"
	)
	for index in range(8):
		var event: Array = sim.events()[sim.turn]
		orders.inside = int(event[2]) > 0
		orders.bridge = not String(event[3]).is_empty()
		sim.resolve(orders)
		for key: StringName in OutpostSim.KEYS:
			_check(
				sim.state[key] >= 0 and sim.state[key] <= sim.config.limits[key], "bounded " + key
			)


func _check_interface() -> void:
	var game := SCENE.instantiate()
	add_child(game)
	await get_tree().process_frame
	var capture := "--capture" in OS.get_cmdline_user_args()
	if capture:
		await _capture("inicio")
	_click(Vector2(415, 242))
	_press(KEY_2)
	_check(game.orders.life and game.orders.farm, "mouse and keyboard change the plan")
	_click(Vector2(1067, 647))
	_check(game.sim.turn == 1 and game.sim.state.growth == 1, "confirm executes visible preview")
	_press(KEY_SPACE)
	_check(game.sim.state.harvests == 1, "second cycle produces food")
	_press(KEY_E)
	_check(game.orders.inside and game.orders.shelter, "shelter key queues protection")
	if capture:
		await _capture("alerta")
	_press(KEY_R)
	_check(game.sim.turn == 0 and not game.orders.life, "keyboard restart resets plan")
	_press(KEY_TAB)
	_check(game.sim.scenario == 1, "alternate scenario opens")
	for index in range(4):
		_press(KEY_SPACE)
	_check(game._result.visible and not game.sim.won, "failure opens result card")
	_click(Vector2(345, 402))
	_check(not game._result.visible and game.sim.turn == 0, "retry button starts immediately")
	_press(KEY_1)
	_press(KEY_2)
	for index in range(game.sim.events().size()):
		var event: Array = game.sim.events()[game.sim.turn]
		if game.orders.inside != (int(event[2]) > 0):
			_press(KEY_E)
		if not String(event[3]).is_empty():
			_click(Vector2(390, 655))
		_press(KEY_SPACE)
	_check(game.sim.won and game._result.visible, "second scenario wins through interface")
	if capture:
		await _capture("victoria")


func _run(sim: OutpostSim, plan: String) -> void:
	for event: Array in sim.events():
		if not sim.result.is_empty():
			break
		var orders := _orders()
		orders.inside = int(event[2]) > 0 and plan != "no shelter"
		orders.shelter = orders.inside
		orders.farm = plan != "no farm"
		orders.repair = event[3] if plan == "repair" else ""
		orders.bridge = not String(event[3]).is_empty() and plan == "bridge"
		sim.resolve(orders)


func _orders() -> Dictionary:
	return {
		"life": true, "farm": true, "shelter": true, "inside": false, "repair": "", "bridge": false
	}


func _click(point: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		get_viewport().push_input(event, true)


func _press(key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	get_viewport().push_input(event, true)


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := OS.get_environment("TEMP").path_join("artemis-outpost-%s.png" % name)
	_check(get_viewport().get_texture().get_image().save_png(path) == OK, "saved " + name)


func _check(ok: bool, description: String) -> void:
	_checks += 1
	if not ok:
		_failed += 1
		push_error("OUTPOST: " + description)
