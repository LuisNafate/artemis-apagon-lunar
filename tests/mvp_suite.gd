# gdlint: disable=max-returns
extends Node

const GAME := preload("res://lunar/lunar.tscn")
const STEP_LIMIT := 2400

var _game: LunarGame
var _path := "user://artemis-mvp-%d.dat" % OS.get_process_id()
var _case := ""
var _checks := 0
var _failed := 0
var _cases := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	seed(20261115)
	_game = GAME.instantiate()
	_game.profile_path = _path
	add_child(_game)
	await get_tree().physics_frame
	_game.opening._skip.pressed.emit()
	_objective_references()
	var selected := OS.get_cmdline_user_args()
	var controls := _game.ui._list.get_children()
	_check(
		not controls.any(
			func(node: Node) -> bool: return node is Button and "en línea" in node.text
		),
		"la portada ofrece el recorrido individual"
	)
	var bases: Array = _game.sim.rules.bases.keys()
	if "--mvp-one" in selected:
		bases.resize(1)
	for id: String in bases:
		_case = id
		if not await _open(id):
			break
		_cases += 1
		var completed := false
		if "--mvp-guide" in selected:
			completed = await _guided_mission("--mvp-capture" in selected)
		else:
			completed = await _complete()
		if not completed:
			break
		print(
			(
				"MVP BASE %s: returned on day %d at %.1f s (wallet %s)"
				% [id, _game.sim.days + 1, _game.sim.elapsed, _game.profile.balance_text()]
			)
		)
		if "--mvp-capture" in selected and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("user://artemis-mvp-regreso.png")
		if not await _fund_next(bases, id):
			break
		_press_menu("Guardar y salir")
		if not _check(_game.net == &"lobby", "regresa al selector y guarda"):
			break
		var saved := LunarProfile.new(_game.sim.rules, _path)
		if not _check(saved.saved_bases(true)[id].active.returned, "victoria persistente"):
			break
	if _failed == 0 and bases.size() > 1:
		_check(_game.profile.campaign_finished(), "el perfil registra la campaña completa")
		_check("Campaña completada" in _game.ui._message.text, "final visible al volver al menú")
	_game.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	DirAccess.remove_absolute(_path)
	print("MVP SUITE: %d cases, %d assertions, %d failed" % [_cases, _checks, _failed])
	get_tree().quit(int(_failed > 0))


func _objective_references() -> void:
	var mission := LunarMission.new()
	mission.prepare("mons_mouton_plateau", 42, true)
	var initial := LunarObjective.next(mission, 0, false)
	_check(
		initial[0] == &"training" and "mesa de práctica" in initial[1],
		"tutorial names its exact station"
	)
	mission.use_station(0, &"training")
	mission.release(0, Vector3.ZERO, false)
	_check(
		LunarObjective.next(mission, 0, false)[0] == &"loose_sample",
		"dropped sample becomes the active target"
	)
	mission.pickup(0, mission.crates.keys()[0])
	mission.use_station(0, &"training")
	_check(
		LunarObjective.next(mission, 0, false)[0] == &"fuel",
		"delivery advances the guide to production"
	)
	mission.water = 0.0
	_check(LunarObjective.next(mission, 0, false)[0] == &"ice", "missing water points to ice")
	mission._create_cargo(0, &"ice")
	var restored := mission.state()
	_check(
		LunarObjective.next(mission, 0, false)[0] == &"refinery", "carried ice points to refinery"
	)
	mission.use_station(0, &"refinery")
	_check(
		LunarObjective.next(mission, 0, false)[0] == &"refinery",
		"running refinery remains the target"
	)
	mission.restore(restored)
	_check(
		LunarObjective.next(mission, 0, false)[0] == &"refinery",
		"loaded carriage restores the exact target"
	)
	mission.events = [["sep", 0, 45]]
	_check(LunarObjective.next(mission, 0, false)[0] == &"life", "storm redirects to shelter")
	mission.phase = &"flight"
	_check(LunarObjective.next(mission, 0, false)[0] == &"", "flight clears surface guidance")


func _open(id: String) -> bool:
	if not _press_menu("Jugar"):
		return false
	if not _game.profile.open_base(id):
		if not _check(_game.ui.globe.enter_base(id), "puede seleccionar la compra"):
			return false
		if not _check(_game.profile.open_base(id), "compra con recompensas ganadas"):
			return false
	if not _check(_game.ui.globe.enter_base(id), "puede seleccionar la base"):
		return false
	var deadline := Time.get_ticks_msec() + 20000
	while _game._loading and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
	return _check(_game.net == &"solo" and _game.ui.play.visible, "partida individual cargada")


## This driver reads the displayed controls only. World positions and interaction keys
## are deliberately absent from navigation decisions.
func _guided_mission(capture: bool) -> bool:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if capture and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://artemis-objetivo-despues.png")
	var last_marker := ""
	var retry := 0
	var guide_clicks := 0
	for step in range(3600):
		if _game.sim.returned:
			return _check(guide_clicks >= 5, "visible guidance leads to the Earth return")
		var marker := _visible_button(["↓", "↑", "→", "←"], true)
		if is_instance_valid(marker):
			var name := marker.text.substr(3)
			if name != last_marker or retry <= 0:
				print("GUI RUTA: %s" % name)
				_click_control(marker)
				guide_clicks += 1
				retry = 36
			last_marker = name
			retry -= 1
		else:
			last_marker = ""
			var action := _visible_button(
				[
					"Tomar muestra",
					"Entregar muestra",
					"Preparar propelente",
					"Recoger propelente",
					"Cargar propelente",
					"Sembrar cultivo",
					"Recoger ración",
					"Cargar ración",
					"Enviar lista de vuelo",
					"Subir a la nave",
					"Extraer hielo",
					"Entregar hielo",
					"Recoger muestra",
					"Recoger hielo"
				],
				false
			)
			if is_instance_valid(action):
				print("GUI ACCIÓN: %s" % action.text)
				_click_control(action)
		for frame in range(15):
			await get_tree().physics_frame
	return _check(false, "ruta usando solo los controles visibles")


func _visible_button(captions: Array, prefix: bool) -> Button:
	for node: Node in _game.find_children("*", "Button", true, false):
		var button := node as Button
		if button.disabled or not button.is_visible_in_tree():
			continue
		for caption: String in captions:
			if (prefix and button.text.begins_with(caption)) or button.text == caption:
				return button
	return null


func _click_control(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = down
		get_viewport().push_input(event, true)


func _complete() -> bool:
	if not await _station(&"training"):
		return false
	_game.ui.action_button.pressed.emit()
	_game.ui.action_button.pressed.emit()
	if not _check(_game.sim.phase == &"active", "práctica mediante botones de juego"):
		return false
	for step in range(int(_game.sim.rules.mission.propellant)):
		if not await _produce(&"fuel", &"fuel", float(_game.sim.resources.fuel_water)):
			return false
	for step in range(int(_game.sim.rules.mission.food)):
		if not await _produce(&"crop", &"food", float(_game.sim.resources.crop_water)):
			return false
	return await _launch()


func _launch() -> bool:
	var sim := _game.sim
	for attempt in range(3):
		if sim.storm_active() or sim.storm_warning() > 0.0:
			if not await _station(&"life"):
				return false
			if not await _until(
				func() -> bool: return not sim.storm_active() and sim.storm_warning() <= 0.0,
				"espera la tormenta en el refugio",
				5100
			):
				return false
		if not await _station(&"radio"):
			return false
		_game.ui.action_button.pressed.emit()
		if not await _until(func() -> bool: return sim.earth_ok, "respuesta de la radio", 720):
			return false
		if not await _station(&"pad"):
			return false
		_game.ui.action_button.pressed.emit()
		if sim.storm_active() or not sim.pilots[0].seated:
			continue
		for frame in range(3600):
			if sim.returned or (not sim.pilots[0].seated and sim.phase != &"flight"):
				break
			await get_tree().physics_frame
		if sim.returned:
			await get_tree().physics_frame
			return _check(
				(
					_game.profile.data.paid_missions.has(_case)
					and "Regreso a Tierra completado" in _game.ui.next_step.text
				),
				"victoria, bono y estado final visibles"
			)
	return _check(false, "regreso a Tierra")


func _produce(station: StringName, kind: StringName, water: float) -> bool:
	var sim := _game.sim
	for attempt in range(8):
		if not await _station(station):
			return false
		_game.ui.action_button.pressed.emit()
		if sim.cargo_kind(0) == kind:
			break
		if sim.jobs[station] > 0:
			if not await _until(
				func() -> bool: return sim.jobs[station] == 0.0, "producción " + String(kind), 6000
			):
				return false
			_game.ui.action_button.pressed.emit()
			break
		if not _check(
			sim.water < water * float(sim.difficulty.consumption), "faltó agua para producir"
		):
			return false
		if not await _refill():
			return false
	if not _check(sim.cargo_kind(0) == kind, "carga preparada " + String(kind)):
		return false
	if not await _station(&"pad"):
		return false
	_game.ui.release_button.pressed.emit()
	return _check(sim.cargo_kind(0) == &"", "carga entregada " + String(kind))


func _refill() -> bool:
	var sim := _game.sim
	var pilot := _game.pilots[0]
	var choices: Array[Dictionary] = []
	for cell: Vector2i in _game.streamer.loaded_coords():
		var chunk := _game.streamer.data_at(cell)
		for deposit: Dictionary in chunk.deposits:
			var key := LunarMission.deposit_key(cell, int(deposit.id))
			if deposit.kind == &"ice" and sim.deposit_left(key) > 0:
				choices.append({"key": key, "point": deposit.point})
	choices.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return (
				pilot.position.distance_squared_to(a.point)
				< pilot.position.distance_squared_to(b.point)
			)
	)
	if not _check(not choices.is_empty(), "hielo accesible dentro de la zona cargada"):
		return false
	var point: Vector3 = choices[0].point
	var key: StringName = choices[0].key
	if not await _walk(point, key):
		return false
	_game.ui.action_button.pressed.emit()
	if not await _until(func() -> bool: return sim.cargo_kind(0) == &"ice", "extrae hielo", 800):
		return false
	if not await _station(&"refinery"):
		return false
	_game.ui.release_button.pressed.emit()
	if not _check(not sim.refining.is_empty(), "entrega hielo sin perderlo"):
		return false
	return await _until(func() -> bool: return sim.refining.is_empty(), "refina hielo", 1800)


func _station(spot: StringName) -> bool:
	return await _walk(CrestWorld.STATIONS[spot], spot)


func _walk(point: Vector3, spot: StringName) -> bool:
	if spot == &"training":
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = _game.camera.unproject_position(point)
		_game._unhandled_input(click)
	else:
		_game._set_destination(0, point)
	return await _until(func() -> bool: return _game._spots[0] == spot, "llega a %s" % spot)


func _fund_next(bases: Array, id: String) -> bool:
	var index := bases.find(id) + 1
	if index == bases.size():
		return true
	var next: String = bases[index]
	var cost := int(_game.sim.rules.bases[next].cost) * LunarProfile.SCALE
	if int(_game.profile.data.balance) >= cost:
		return true
	if not await _station(&"life"):
		return false
	if not await _until(
		func() -> bool: return _game._route[0].is_empty(), "se detiene en el refugio", 360
	):
		return false
	# Use the normal checkpoint path with an accelerated wait while stationary and sheltered.
	_game.set_physics_process(false)
	var sim := _game.sim
	for step in range(int(sim.rules.cycle.period) * 8):
		if int(_game.profile.data.balance) >= cost:
			break
		_game._local_frame(4.0)
	_game.set_physics_process(true)
	return _check(int(_game.profile.data.balance) >= cost, "gana el precio de la próxima base")


func _press_menu(caption: String) -> bool:
	if caption == "Guardar y salir":
		_game.ui.selected.emit("menu", "")
	for node: Node in _game.ui._list.get_children():
		if node is Button and (node.text == caption or node.text.begins_with(caption)):
			node.pressed.emit()
			return true
	return _check(false, "botón %s" % caption)


func _until(condition: Callable, title: String, frames := STEP_LIMIT) -> bool:
	for frame in range(frames):
		if condition.call():
			return _check(true, title)
		await get_tree().physics_frame
	return _check(condition.call(), title)


func _check(condition: bool, message: String) -> bool:
	_checks += 1
	if not condition:
		_failed += 1
		push_error(
			(
				"%s: %s, piloto %s, zona %s, tiempo %.2f, agua %.2f, aire %.2f, aviso %s"
				% [
					_case,
					message,
					_game.pilots[0].position,
					_game._spots[0],
					_game.sim.elapsed,
					_game.sim.water,
					_game.sim.pilots[0].air,
					_game._feedback
				]
			)
		)
	return condition
