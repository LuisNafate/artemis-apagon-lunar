extends Node

const GAME := preload("res://crest/crest.tscn")
const NO_SPOTS: Array[StringName] = [&"", &""]
const INDOORS: Array[bool] = [true, true]
const OUTSIDE: Array[bool] = [false, false]

var cases := 0
var checks := 0
var failures := 0


func _ready() -> void:
	await get_tree().process_frame
	_finishing_route(false, &"drill")
	_finishing_route(true, &"battery")
	_safe_failure()
	_shared_inventory()
	_power_and_hazards()
	_science()
	await _input_and_world()
	if "--crest-capture" in OS.get_cmdline_user_args():
		await _capture_liftoff()
	else:
		await _map_route(false)
		await _map_route(true)
	print("CREST SUITE: %d cases, %d assertions, %d failed" % [cases, checks, failures])
	get_tree().quit(1 if failures else 0)


func _finishing_route(solo: bool, upgrade: StringName) -> void:
	cases += 1
	var sim := CrestSim.new()
	sim.solo = solo
	sim.begin(false)
	sim.use_station(0, &"training")
	sim.tick(1.0, INDOORS, NO_SPOTS)
	_check(sim.elapsed == 0 and sim.tutorial_step == 1, "tutorial no consume tiempo")
	sim.release(0, Vector3.ZERO, true)
	sim.use_station(1, &"training")
	sim.use_station(1, &"training")
	_check(sim.elapsed == 0 and sim.phase == &"active", "inicio solo tras entrega")
	for index in range(2):
		_deliver_raw(sim, index, &"ore")
	sim.use_station(0, upgrade)
	var charge_capacity := sim.battery_capacity()
	sim.use_station(1, upgrade)
	_check(sim.ore == 0 and sim.battery_capacity() == charge_capacity, "mejora de compra única")
	_check(sim.drill or sim.auxiliary, "una mejora instalada")
	sim.use_station(0, &"crop")
	sim.use_station(0, &"pad")
	sim.use_station(0, &"crop")
	_run(sim, float(sim.runtime.crop_seconds) + 0.2, INDOORS)
	sim.use_station(1, &"crop")
	sim.use_station(1, &"pad")
	_check(sim.food_loaded == 2 and sim.crops_harvested == 1, "alimento de cultivo embarcado")
	for batch in range(3):
		while sim.water < 2:
			_deliver_raw(sim, batch % 2, &"ice")
		sim.use_station(batch % 2, &"fuel")
		_run(sim, float(sim.runtime.propellant_seconds) + 0.2, INDOORS)
		sim.use_station(batch % 2, &"fuel")
		sim.use_station(batch % 2, &"pad")
	sim.use_station(0, &"radio")
	var radio_delay := float(sim.config.radio_round_trip_seconds)
	_run(sim, radio_delay - 0.2, INDOORS)
	_check(not sim.earth_ok, "se respeta demora de Tierra")
	_run(sim, 0.3, INDOORS)
	_check(sim.earth_ok and sim.fuel_loaded == 3, "cohete abastecido con confirmación")
	if not sim.window_open():
		_run(sim, float(sim.runtime.launch_opens) - sim.elapsed + 0.2, INDOORS)
	sim.use_station(1, &"pad")
	_check(sim.crew_seated() == 1 and sim.phase == &"active", "una plaza nunca lanza")
	sim.use_station(0, &"pad")
	_check(sim.phase == &"countdown", "la segunda plaza inicia cuenta")
	sim.use_station(1, &"pad")
	_check(sim.phase == &"active" and sim.fuel_loaded == 3, "salida cancela y conserva carga")
	sim.use_station(1, &"pad")
	_run(sim, float(sim.runtime.countdown) + 0.1, INDOORS)
	_check(sim.phase == &"success", "despegue en la estrategia " + String(upgrade))


func _safe_failure() -> void:
	cases += 1
	var sim := CrestSim.new()
	sim.begin(false, true)
	_run(sim, 200.0, OUTSIDE)
	_check(sim.phase == &"failed" and sim.result.contains("aire"), "perder por falta de aire")
	var time := sim.elapsed
	sim.tick(30, OUTSIDE, NO_SPOTS)
	_check(sim.elapsed == time and not sim.window_open(), "estado terminal inmóvil")
	sim = CrestSim.new()
	sim.begin(false, true)
	sim.elapsed = sim.duration() - 0.01
	sim.tick(0.02, INDOORS, NO_SPOTS)
	_check(sim.phase == &"failed" and sim.result.contains("ventana"), "cerrar ventana")


func _shared_inventory() -> void:
	cases += 1
	var sim := CrestSim.new()
	sim.begin(false, true)
	sim.use_station(0, &"ice")
	var at_mine: Array[StringName] = [&"ice", &""]
	_run(sim, sim.drill_seconds() + 0.1, INDOORS, at_mine)
	var id: int = sim.pilots[0].cargo
	_check(id > 0 and sim.crates[id].owner == 0, "unidad física con dueño")
	sim.release(0, Vector3.ZERO, false)
	_check(sim.pickup(0, id) and not sim.pickup(1, id), "recogida concurrente exclusiva")
	sim.release(0, Vector3.ZERO, true)
	_check(sim.pilots[0].cargo == 0 and sim.pilots[1].cargo == id, "traspaso atómico")
	var previous := sim.water
	sim.use_station(1, &"refinery")
	sim.use_station(1, &"refinery")
	_check(sim.water == previous + 1 and not sim.crates.has(id), "no se acredita dos veces")
	sim.water = 0
	sim.use_station(0, &"fuel")
	_check(sim.jobs[&"fuel"] == 0.0 and sim.water == 0, "receta sin insumos rechazada")


func _power_and_hazards() -> void:
	cases += 1
	var sim := CrestSim.new()
	sim.begin(false, true)
	sim.elapsed = float(sim.runtime.storm_start)
	var half_sheltered: Array[bool] = [true, false]
	_run(sim, 5.0, half_sheltered)
	_check(sim.pilots[0].exposure == 0.0 and sim.pilots[1].exposure > 0.0, "blindaje físico")
	sim.elapsed = float(sim.runtime.storm_repeat) - 8.0
	_check(is_equal_approx(sim.storm_warning(), 8.0), "aviso también para la segunda alerta")
	sim.elapsed = float(sim.runtime.shadow_start)
	sim.charge = 0.0
	sim.use_station(0, &"fuel")
	var job: float = sim.jobs[&"fuel"]
	_run(sim, 3.0, INDOORS)
	_check(
		not sim.life_powered and sim.jobs[&"fuel"] == job, "apagón pausa receta sin cobrar de nuevo"
	)
	_check(sim.water == 0 and sim.charge == 0.0, "reservas no negativas")
	_check(sim.use_station(0, &"radio").contains("sombra"), "relé apagado impide un envío nuevo")
	sim.elapsed = float(sim.runtime.shadow_start) + float(sim.runtime.shadow_duration) + 0.1
	_run(sim, job + 0.2, INDOORS)
	_check(sim.fuel_ready == 1 and sim.life_powered, "reanuda receta con retorno de luz")


func _science() -> void:
	cases += 1
	var sim := CrestSim.new()
	_check(sim.records.size() == 6, "todas las muestras disponibles offline")
	for record in sim.records:
		_check(
			(
				sim.science_text(record).length() > 20
				and String(record.source_url).begins_with("https://")
			),
			"atribución legible"
		)
	_check(
		not sim._valid_record(
			{"id": "tle_iss_25544", "source_url": "https://example.org", "observation": {}}
		),
		"muestra dañada se omite"
	)


func _input_and_world() -> void:
	cases += 1
	var game := GAME.instantiate()
	add_child(game)
	await get_tree().physics_frame
	var rendered := DisplayServer.get_name() != "headless"
	if rendered and "--crest-capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://crest-lobby.png")
	_tap(KEY_2)
	_tap(KEY_1)
	await get_tree().physics_frame
	_check(game.sim.phase == &"tutorial" and not game.sim.solo, "selector cooperativo por teclado")
	_tap(KEY_E)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(game.sim.tutorial_step == 1, "E toma la muestra en el mapa")
	_tap(KEY_Q)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(game.sim.tutorial_step == 2, "Q pasa a jugador dos en el mapa")
	_tap(KEY_ENTER)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(game.sim.tutorial_step == 3, "Intro entrega muestra")
	_tap(KEY_ENTER)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(game.sim.phase == &"active", "controles reales comienzan partida")
	var first: Vector3 = game.pilots[0].position
	var second: Vector3 = game.pilots[1].position
	_key(KEY_A, true)
	_key(KEY_RIGHT, true)
	for frame in range(25):
		await get_tree().physics_frame
	_key(KEY_A, false)
	_key(KEY_RIGHT, false)
	_check(
		game.pilots[0].position.x < first.x - 1.0 and game.pilots[1].position.x > second.x + 1.0,
		"bancos simultáneos"
	)
	if rendered and "--crest-capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://crest-play.png")
	_tap(KEY_ESCAPE)
	await get_tree().physics_frame
	var before: float = game.sim.elapsed
	for frame in range(8):
		await get_tree().physics_frame
	_check(game.sim.elapsed == before and game._menu == &"paused", "Escape pausa simulación")
	game.queue_free()
	await get_tree().process_frame
	var solo := GAME.instantiate()
	add_child(solo)
	await get_tree().physics_frame
	_tap(KEY_1)
	_tap(KEY_1)
	await get_tree().physics_frame
	_check(solo.sim.solo and solo.sim.phase == &"tutorial", "selector individual por teclado")
	_tap(KEY_E)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_tap(KEY_Q)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_tap(KEY_TAB)
	_tap(KEY_E)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(
		solo.sim.tutorial_step == 3 and solo._active_pilot == 1,
		"en individual se pasa y entrega alternando"
	)
	solo.queue_free()


func _capture_liftoff() -> void:
	if DisplayServer.get_name() == "headless":
		return
	cases += 1
	var game := GAME.instantiate()
	add_child(game)
	await get_tree().physics_frame
	_tap(KEY_2)
	_tap(KEY_3)
	game.sim.elapsed = float(game.sim.runtime.launch_opens) + 2
	game.sim.fuel_loaded = 3
	game.sim.food_loaded = 2
	game.sim.earth_ok = true
	for player in range(2):
		game.pilots[player].position = CrestWorld.BOARDING[player]
		_act(game, player)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(game.sim.phase == &"countdown", "cuenta se muestra en pantalla")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://crest-countdown.png")
	game.sim.countdown = 0.01
	for frame in range(35):
		await get_tree().physics_frame
	_check(game.sim.phase == &"success" and game.world.rocket.position.y > 0.5, "ascenso animado")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://crest-liftoff.png")
	game.queue_free()


func _map_route(solo: bool) -> void:
	cases += 1
	var game := GAME.instantiate()
	add_child(game)
	await get_tree().physics_frame
	_tap(KEY_1 if solo else KEY_2)
	_tap(KEY_3)
	await _walk(game, 0, Vector3(-10.9, 0.0, 5.0))
	await _walk(game, 0, CrestWorld.STATIONS[&"ice"])
	_act(game, 0)
	for frame in range(370):
		await get_tree().physics_frame
	_check(game.sim.cargo_kind(0) == &"ice", "extraer hielo con movimiento y E")
	await _walk(game, 0, CrestWorld.STATIONS[&"refinery"])
	_act(game, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(game.sim.water == 3 and game.sim.cargo_kind(0) == &"", "trayecto de cantera a refinado")
	await _walk(game, 0, Vector3(-0.7, 0, 0.35))
	await _walk(game, 0, Vector3(0.05, 0, 2.5))
	await _walk(game, 0, Vector3(0.05, 0, 4.85))
	_check(game.world.sheltered(game.pilots[0].position), "vuelta desde cantera por refugio")
	await _walk(game, 1, CrestWorld.STATIONS[&"radio"])
	_act(game, 1)
	for frame in range(165):
		await get_tree().physics_frame
	_check(game.sim.earth_ok, "confirmación real desde consola con Intro")
	await _take_to_pad(game, 1, &"crop")
	await _walk(game, 1, CrestWorld.STATIONS[&"crop"])
	_act(game, 1)
	for frame in range(850):
		await get_tree().physics_frame
	await _take_to_pad(game, 1, &"crop")
	_check(game.sim.food_loaded == 2, "raciones cargadas con controles de juego")
	for batch in range(3):
		while game.sim.water < 3:
			await _walk(game, 0, Vector3(-2.0, 0, 0.1))
			await _walk(game, 0, CrestWorld.STATIONS[&"ice"])
			_act(game, 0)
			for frame in range(370):
				await get_tree().physics_frame
			await _walk(game, 0, CrestWorld.STATIONS[&"refinery"])
			_act(game, 0)
			await get_tree().physics_frame
			await get_tree().physics_frame
			if game.sim.terminal():
				_check(false, game.sim.result)
				game.queue_free()
				return
		await _walk(game, 0, Vector3(-0.7, 0, 0.5))
		await _walk(game, 0, Vector3(0.05, 0, 2.5))
		await _walk(game, 1, CrestWorld.STATIONS[&"fuel"])
		_act(game, 1)
		await get_tree().physics_frame
		await get_tree().physics_frame
		_check(game.sim.jobs[&"fuel"] > 0.0, "receta iniciada con agua")
		await _walk(game, 1, Vector3(6.8, 0, 0.85))
		await _walk(game, 1, Vector3(0.15, 0, 2.4))
		for frame in range(3400):
			if game.sim.fuel_ready > 0 or game.sim.terminal():
				break
			await get_tree().physics_frame
		_check(game.sim.fuel_ready == 1, "propelente listo tras esperar en refugio")
		await _take_to_pad(game, 1, &"fuel")
		await _walk(game, 1, Vector3(5.0, 0, 4.85))
		await _walk(game, 1, Vector3(0.05, 0, 4.7))
		if game.sim.hungry or game.sim.meals_clock < 18.0:
			await _walk(game, 1, CrestWorld.STATIONS[&"life"])
			_act(game, 1)
			await get_tree().physics_frame
			await get_tree().physics_frame
	_check(game.sim.fuel_loaded == 3, "lotes cargados recorriendo planta y vehículo")
	_check(game.sim.window_open(), "preparados con ventana abierta")
	for player in range(2):
		await _walk(game, player, Vector3(0.02, 0, 4.85))
		await _walk(game, player, Vector3(4.2, 0, 4.85))
		await _walk(game, player, CrestWorld.STATIONS[&"pad"])
		_act(game, player)
		await get_tree().physics_frame
		await get_tree().physics_frame
	for frame in range(320):
		await get_tree().physics_frame
	_check(
		game.sim.phase == &"success",
		"despegue con teclado en modo " + ("individual" if solo else "cooperativo")
	)
	game.queue_free()


func _take_to_pad(game, player: int, station: StringName) -> void:
	await _walk(game, player, CrestWorld.STATIONS[station])
	_act(game, player)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if station == &"fuel":
		await _walk(game, player, Vector3(6.8, 0, 0.5))
		await _walk(game, player, Vector3(9.4, 0, 0.7))
	await _walk(game, player, CrestWorld.STATIONS[&"pad"])
	_act(game, player)
	await get_tree().physics_frame
	await get_tree().physics_frame


func _act(game, player: int) -> void:
	_focus(game, player)
	_tap(KEY_E if player == 0 or game.sim.solo else KEY_ENTER)


func _focus(game, player: int) -> void:
	if game.sim.solo and game._active_pilot != player:
		_tap(KEY_TAB)


func _walk(game, player: int, destination: Vector3) -> void:
	_focus(game, player)
	var first_bank: bool = player == 0 or game.sim.solo
	var keys: Array = (
		[KEY_A, KEY_D, KEY_W, KEY_S] if first_bank else [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]
	)
	var previous: Array[bool] = [false, false, false, false]
	var right: Vector3 = game.camera.basis.x
	var back: Vector3 = game.camera.basis.z
	right.y = 0
	back.y = 0
	for frame in range(320):
		var remaining: Vector3 = destination - game.pilots[player].position
		remaining.y = 0
		if remaining.length() < 0.47:
			break
		var x := remaining.dot(right.normalized())
		var y := remaining.dot(back.normalized())
		var requested: Array[bool] = [x < -0.22, x > 0.22, y < -0.22, y > 0.22]
		for index in range(keys.size()):
			if requested[index] != previous[index]:
				_key(keys[index], requested[index])
		previous = requested
		await get_tree().physics_frame
	for index in range(keys.size()):
		if previous[index]:
			_key(keys[index], false)
	var point: Vector3 = game.pilots[player].position
	_check(
		point.distance_to(destination) < 0.86,
		"ruta %s llegó a %s · %s" % [destination, point, game.sim.result]
	)


func _deliver_raw(sim: CrestSim, player: int, kind: StringName) -> void:
	var mine: Array[StringName] = [&"", &""]
	mine[player] = kind
	sim.use_station(player, kind)
	_run(sim, sim.drill_seconds() + 0.2, INDOORS, mine)
	sim.use_station(player, &"refinery")


func _run(
	sim: CrestSim, span: float, sheltered: Array[bool], nearby: Array[StringName] = NO_SPOTS
) -> void:
	var left := span
	while left > 0.001 and not sim.terminal():
		var step := minf(left, 0.1)
		sim.tick(step, sheltered, nearby)
		left -= step


func _tap(keycode: Key) -> void:
	_key(keycode, true)
	_key(keycode, false)


func _key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _check(passed: bool, description: String) -> void:
	checks += 1
	if not passed:
		failures += 1
		push_error(description)
