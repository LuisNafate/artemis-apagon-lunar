# gdlint: disable=max-returns,max-public-methods,max-file-lines
class_name LunarGame
extends Node3D

const PORT := 44260
const SAMPLE_RATE := 0.10
const CAMERA_ELEVATION := 34.0
const SURFACE_SIZE := 27.0
const PLAY_SIZE := 9.8
const CAMERA_DISTANCE := 26.0
const PLAY_V_OFFSET := 2.9
const FOLLOW_FOV := 45.0
const FOLLOW_HEIGHT := 0.8
const BASE_HYSTERESIS := 1.0
const HORIZON_SPAN := 400.0
const DEPOSIT_REACH := 1.63
const LOOKAHEAD_FRAMES := 4.0
const SINK_TOLERANCE := 0.25
const TERRAIN_WAIT_MSEC := 8000
const CARGO_MODELS := {
	&"ice": [preload("res://assets/props_luna/estaciones/caja_hielo.glb"), 0.62],
	&"food": [preload("res://assets/props_luna/estaciones/cantimplora.glb"), 0.58]
}
const ROUTES := preload("res://lunar/lunar_routes.gd")
const MATCOLORS := {
	&"sample": CrestWorld.BLUE,
	&"ice": CrestWorld.BLUE,
	&"ore": CrestWorld.PURPLE,
	&"fuel": CrestWorld.AMBER,
	&"food": CrestWorld.LIME
}

var sim := LunarMission.new()
var profile: LunarProfile
var profile_path := LunarProfile.SAVE_PATH
var world := CrestWorld.new()
var camera := Camera3D.new()
var ui := LunarInterface.new()
var sky := LunarBackdrop.new()
var flight := LunarFlightView.new()
var streamer := ChunkStreamer.new()
var pilots: Array[CrestPilot] = []
var net := &"lobby"
var guest_peer := 0
var guest_id := ""
var positions_at_dawn: Array = []
var saved_run := 0
var play_started := false
var opening: LunarOpening
var _camera_home := Vector3.ZERO

var _base_mode := "solo"
var _loading := false
var _address := ""
var _vectors := [Vector2.ZERO, Vector2.ZERO]
var _jump: Array[bool] = [false, false]
var _chunk_ready: Array[bool] = [false, false]
var _route: Array[PackedVector2Array] = [[], []]
var _routes := ROUTES.new()
var _routes_ready := false
var _planner := RoutePlanner.new()
var _spots: Array[StringName] = [&"", &""]
var _boxes: Dictionary = {}
var _cargo_templates: Dictionary = {}
var _coins_by_guest: Dictionary = {}
var _pending_reward: Dictionary = {}
var _reward_retry := 0.0
var _award_retry := 0.0
var _science_index := 0
var _science_from_session := false
var _feedback := ""
var _feedback_time := 0.0
var _sync_left := 0.0
var _send_left := 0.0
var _inactivity := 0.0
var _replica_positions: Array = []
var _replica_headings: Array = []
var _alert_kind := ""
var _alert_audio := AudioStreamPlayer.new()
var _reward_audio := AudioStreamPlayer.new()


func _ready() -> void:
	if profile_path == LunarProfile.SAVE_PATH:
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--perfil="):
				var label := argument.trim_prefix("--perfil=")
				if label.is_valid_ascii_identifier() and label.length() <= 30:
					profile_path = "user://artemis_campaign_%s.dat" % label
	profile = LunarProfile.new(sim.rules, profile_path)
	var backdrop_layer := CanvasLayer.new()
	backdrop_layer.layer = -1
	add_child(backdrop_layer)
	backdrop_layer.add_child(sky)
	world.open_settings = sim.rules.open_world
	add_child(world)
	world.build()
	world.build_lunar_workshop()
	var starting_id: String = sim.rules.starting_base
	var initial: Dictionary = sim.rules.bases[starting_id]
	world.set_base(initial.soil, StringName(starting_id))
	world.show_field_models("")
	for station: Node3D in world.markers.values():
		station.hide()
	add_child(streamer)
	_configure_streamer(starting_id)
	sky.configure(starting_id, initial.horizon)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	add_child(camera)
	_surface_camera()
	camera.make_current()
	add_child(flight)
	flight.build()
	for player in range(2):
		_add_pilot(player)
	add_child(ui)
	ui.build()
	ui.selected.connect(_choose)
	multiplayer.peer_disconnected.connect(_peer_left)
	multiplayer.connected_to_server.connect(_request_join)
	multiplayer.connection_failed.connect(_connection_failed)
	multiplayer.server_disconnected.connect(_host_left)
	_build_alert_audio()
	if profile.error != OK:
		ui.wait_for_guest("PERFIL LOCAL", "", "No se pudo leer el progreso guardado.")
	else:
		_show_opening()


func _show_opening() -> void:
	if is_instance_valid(opening):
		return
	net = &"title"
	ui.hide_lobby()
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	opening = LunarOpening.new()
	opening.enter_requested.connect(func() -> void: _choose("title_enter", ""))
	layer.add_child(opening)
	opening.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## La intro se cierra al entrar al menu o al abrir una base por cualquier camino: si
## siguiera viva, al terminar devolveria la partida al lobby.
func _close_opening() -> void:
	if is_instance_valid(opening):
		opening.get_parent().queue_free()
		opening = null


func _surface_camera() -> void:
	var view := Vector2(0.228, 0.974).normalized()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = Vector3(
		view.x * CAMERA_DISTANCE,
		CAMERA_DISTANCE * tan(deg_to_rad(CAMERA_ELEVATION)),
		view.y * CAMERA_DISTANCE
	)
	camera.look_at(Vector3.ZERO)
	_camera_home = camera.position
	camera.size = SURFACE_SIZE
	camera.h_offset = 0.0
	camera.v_offset = PLAY_V_OFFSET
	sky.pan = 0.0


func _process(delta: float) -> void:
	if not _pending_reward.is_empty():
		_reward_retry -= delta
		if _reward_retry <= 0.0:
			_commit_reward()
	if net == &"host" and guest_peer != 0:
		_award_retry -= delta
		if _award_retry <= 0.0:
			_send_awards()
	sky.update_sky(delta, not sim.base.is_empty() and sim.radio_cut())


func _notification(what: int) -> void:
	if is_node_ready() and what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		ui.joystick.clear()
		_vectors[0] = Vector2.ZERO
		_route[0].clear()


func _physics_process(delta: float) -> void:
	if not _routes_ready:
		_routes.build(get_world_3d().direct_space_state)
		_routes_ready = true
	streamer.update(_focus_points())
	_planner.update(streamer)
	if net == &"host" and play_started:
		_local_frame(delta)
	elif net == &"solo" and ui.play.visible:
		_local_frame(delta)
	elif net == &"guest":
		_guest_frame(delta)
	if ui.play.visible and sim.phase != &"flight":
		_follow_camera(delta)


func _follow_camera(delta: float) -> void:
	# Cada dispositivo sigue a su propio piloto; la orientacion nunca cambia.
	var own := pilots[1 if net == &"guest" else 0].position
	var outside := _camera_outside(own)
	if outside != (camera.projection == Camera3D.PROJECTION_PERSPECTIVE):
		_switch_projection(outside)
	var blend := minf(1.0, delta * 4.0)
	if outside:
		var target := own + Vector3.UP * FOLLOW_HEIGHT + camera.basis.z * _follow_distance()
		camera.position = camera.position.lerp(target, blend)
		camera.v_offset = lerpf(camera.v_offset, 0.0, blend)
	else:
		# Zoom de juego: camara cercana que sigue a los pilotos conectados sin salir de la
		# plataforma (en solo, el piloto ausente no cuenta).
		var points := _focus_points()
		var focus := Vector3.ZERO
		for point in points:
			focus += point
		focus /= maxf(1.0, float(points.size()))
		# En z llega hasta el borde de la plataforma: con el desplazamiento vertical de la
		# vista, un tope menor dejaba al piloto bajo el borde inferior de la pantalla.
		var reach_z := CrestWorld.HALF_Z
		var shift := Vector3(clampf(focus.x, -12.0, 12.0), 0.0, clampf(focus.z, -reach_z, reach_z))
		camera.position = camera.position.lerp(_camera_home + shift, blend)
		camera.size = lerpf(camera.size, PLAY_SIZE, minf(1.0, delta * 2.5))
		camera.v_offset = lerpf(camera.v_offset, PLAY_V_OFFSET, blend)
	sky.pan = camera.position.dot(camera.basis.x) / HORIZON_SPAN


## Fuera de la plataforma plana (con histeresis para no alternar en el borde).
func _camera_outside(point: Vector3) -> bool:
	var values: Array = sim.rules.open_world.base_flat_rect
	var flat := Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))
	var perspective := camera.projection == Camera3D.PROJECTION_PERSPECTIVE
	var margin := -BASE_HYSTERESIS if perspective else BASE_HYSTERESIS
	return not flat.grow(margin).has_point(Vector2(point.x, point.z))


## Distancia en perspectiva que encuadra lo mismo que la ortografica de juego.
func _follow_distance() -> float:
	return PLAY_SIZE / (2.0 * tan(deg_to_rad(FOLLOW_FOV) * 0.5))


## Cambia de proyeccion conservando el punto mirado y el encuadre, para que el paso
## por el borde de la base sea una mezcla y no un salto.
func _switch_projection(perspective: bool) -> void:
	var back := camera.basis.z
	if perspective:
		var look := camera.position - back * CAMERA_DISTANCE
		var zoom := camera.size / PLAY_SIZE
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = FOLLOW_FOV
		camera.position = look + back * _follow_distance() * zoom
	else:
		var look := camera.position - back * _follow_distance()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = PLAY_SIZE
		camera.position = look + back * CAMERA_DISTANCE


func _unhandled_input(event: InputEvent) -> void:
	if not ui.play.visible or sim.phase == &"flight":
		return
	var tap: bool = event is InputEventScreenTouch and event.pressed
	if event is InputEventMouseButton:
		tap = event.button_index == MOUSE_BUTTON_LEFT and event.pressed
		tap = tap and event.device != InputEvent.DEVICE_ID_EMULATION
	if tap:
		var origin := camera.project_ray_origin(event.position)
		var ray := camera.project_ray_normal(event.position)
		var point: Variant = Plane(Vector3.UP, 0.0).intersects_ray(origin, ray)
		if point is Vector3:
			ui.show_zone(_zone_name_at(point))
			if net in [&"host", &"solo"]:
				_set_destination(0, point)
			elif net == &"guest":
				_guest_destination.rpc_id(1, point)
		get_viewport().set_input_as_handled()


func _zone_name_at(point: Vector3) -> String:
	var found := ""
	var closest := 2.2
	for key: StringName in CrestWorld.campaign_stations:
		if key in [&"training", &"supply"] or not CrestWorld.NAMES.has(key):
			continue
		var location: Vector3 = CrestWorld.campaign_stations[key]
		var distance := point.distance_to(location)
		if distance < closest:
			closest = distance
			found = String(CrestWorld.NAMES[key])
	return found


func _choose(action: String, argument: String) -> void:
	if profile.error != OK or _loading:
		return
	match action:
		"jump":
			_jump[0] = ui.play.visible  # el invitado lo envia con el siguiente eje
		"title_enter":
			_close_opening()
			net = &"lobby"
			_surface_camera()
			ui.lobby(profile, "")
		"title_replay":
			_show_opening()
		"lobby":
			ui.lobby(profile, "")
		"bases":
			if not argument.is_empty():
				_base_mode = argument
			ui.bases(profile, _base_mode)
		"roles":
			ui.roles(profile)
		"buy_base":
			var bought := profile.buy(argument, false)
			var message := "" if bought else "No puedes comprar esta base con tu saldo actual."
			if profile.save_error != OK:
				message = "No se pudo guardar la compra. Tu saldo sigue intacto."
			ui.bases(profile, _base_mode, message)
		"buy_role":
			if profile.buy(argument, true):
				ui.roles(profile)
			elif profile.save_error != OK:
				ui.lobby(profile, "No se pudo guardar la compra. Tu saldo sigue intacto.")
			else:
				ui.lobby(profile, "Reúne 250 monedas para desbloquear ese rol.")
		"choose_role":
			profile.data.active_role = argument
			profile.save()
			ui.roles(profile)
		"reset_confirm":
			ui.confirm_reset(sim.rules.bases[argument].name, argument)
		"reset":
			profile.saved_bases(_base_mode == "solo").erase(argument)
			var saved := profile.save()
			ui.bases(profile, _base_mode, "" if saved else "No se pudo guardar el reinicio.")
		"solo", "host":
			_load_base(argument, action == "solo")
		"join":
			join(ui.address.text.strip_edges())
		"leave":
			_leave()
		"menu":
			ui.session_menu(net)
		"back_to_play":
			ui.playing()
		"action", "release":
			if net in [&"host", &"solo"]:
				_interact(0, action == "release")
			elif net == &"guest":
				_guest_action.rpc_id(1, action == "release")
		"science":
			_science_from_session = net in [&"host", &"guest", &"solo"]
			_show_science(0)
		"previous_science":
			_show_science(-1)
		"next_science":
			_show_science(1)
		"close_science":
			if _science_from_session:
				ui.session_menu(net)
			else:
				ui.lobby(profile, "")


func _load_base(id: String, single_player: bool) -> void:
	if not profile.open_base(id):
		return
	_loading = true
	var base_name: String = sim.rules.bases[id].name
	ui.loading(base_name, "Preparando la base lunar", 0.25)
	await get_tree().process_frame
	await get_tree().process_frame
	ui.loading(base_name, "Comprobando las rutas de superficie", 0.68)
	_routes_ready = false
	await get_tree().create_timer(0.32).timeout
	if single_player:
		_start_solo(id)
	else:
		host(id)
	if net in [&"solo", &"host"]:
		await _await_terrain(base_name)
	_loading = false


## Mantiene la pantalla de carga hasta que haya suelo bajo las posiciones restauradas.
func _await_terrain(base_name: String) -> void:
	if _terrain_ready():
		return
	ui.loading(base_name, "Generando el terreno", 0.86)
	var deadline := Time.get_ticks_msec() + TERRAIN_WAIT_MSEC
	while not _terrain_ready() and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
	if net in [&"solo", &"host"]:
		_show_session()


func _terrain_ready() -> bool:
	return _focus_points().all(streamer.is_ready_at)


func _show_session() -> void:
	ui.show_balance(profile.balance_text())
	if net == &"host" and not play_started:
		ui.wait_for_guest(sim.base.name, _address, "Esperando al segundo astronauta…")
	else:
		ui.playing()


func host(id: String, port: int = PORT) -> void:
	if not profile.open_base(id):
		return
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(port, 1) != OK:
		ui.lobby(profile, "No se pudo abrir la partida. Comprueba el puerto UDP %d." % port)
		return
	multiplayer.multiplayer_peer = peer
	net = &"host"
	play_started = false
	_open_base(id)
	_address = _lan_address(port)
	_show_session()


func _start_solo(id: String) -> void:
	if not profile.open_base(id):
		return
	net = &"solo"
	_open_base(id)
	_show_session()


func _open_base(id: String) -> void:
	var single_player := net == &"solo"
	var slot: Dictionary = profile.saved_bases(single_player).get(id, {})
	saved_run = int(slot.get("run", randi()))
	_coins_by_guest = slot.get("guest_pending", {}).duplicate()
	_prepare_base(id, saved_run, single_player)
	if not slot.is_empty():
		sim.restore(slot.active.duplicate(true))
		sim.checkpoint = slot.checkpoint.duplicate(true)
		_set_positions(slot.positions)
		positions_at_dawn = slot.checkpoint_positions.duplicate()
	profile.data.recent = id
	profile.data.recent_mode = String(net)
	if slot.is_empty():
		_save_base(false)
	else:
		profile.save()


func join(address: String, port: int = PORT) -> void:
	if address.is_empty():
		ui.lobby(profile, "Escribe la dirección que aparece en el dispositivo del anfitrión.")
		return
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(address, port) != OK:
		ui.lobby(profile, "No se pudo abrir la conexión.")
		return
	net = &"joining"
	multiplayer.multiplayer_peer = peer
	ui.wait_for_guest("UNIÉNDOTE A LA BASE", address, "Conectando…")


func _prepare_base(id: String, seed_value: int, single_player: bool = false) -> void:
	_close_opening()
	sim = LunarMission.new()
	sim.prepare(id, seed_value, single_player)
	_feedback_time = 0.0
	sim.roles[0] = String(profile.data.active_role)
	world.set_base(sim.base.soil, StringName(id))
	world.show_field_models("")
	_configure_streamer(id)
	sky.configure(id, sim.base.horizon)
	_surface_camera()
	_set_positions(CrestWorld.SPAWNS)
	positions_at_dawn = _positions()
	_route[0].clear()
	_route[1].clear()
	_vectors.fill(Vector2.ZERO)
	_alert_kind = ""


func _configure_streamer(id: String) -> void:
	var settings: Dictionary = sim.rules.open_world
	streamer.configure(sim, settings, settings.regions[id], world.soil_color())
	streamer.ground_material = world.ground_material()


func _positions() -> Array:
	return [pilots[0].position, pilots[1].position]


## Puntos alrededor de los que se carga el mundo: los pilotos conectados.
func _focus_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	for index in range(2):
		if sim.connected[index]:
			points.append(pilots[index].position)
	return points


## Estación de la base al alcance o, si no hay, el depósito del mundo más cercano.
func _spot_at(point: Vector3) -> StringName:
	var tutorial := sim.phase == &"tutorial"
	var spot := world.nearest(point, tutorial)
	if spot == &"" and not tutorial:
		spot = streamer.nearest_deposit(point, DEPOSIT_REACH)
	return spot


func crate_visible(id: int) -> bool:
	return _boxes.has(id) and (_boxes[id] as Node3D).visible


func _set_positions(points: Array) -> void:
	for index in range(2):
		pilots[index].position = points[index]
		pilots[index].velocity = Vector3.ZERO
		_chunk_ready[index] = false


func _save_base(exact: bool) -> bool:
	var current := sim.state() if exact else sim.checkpoint.duplicate(true)
	var points := _positions() if exact else positions_at_dawn.duplicate()
	profile.saved_bases(sim.solo)[sim.base_id] = {
		"active": current,
		"checkpoint": sim.checkpoint.duplicate(true),
		"positions": points,
		"checkpoint_positions": positions_at_dawn.duplicate(),
		"guest_pending": _coins_by_guest.duplicate() if exact else {},
		"run": saved_run
	}
	return profile.save()


func _leave() -> void:
	if net in [&"host", &"solo"]:
		if not _commit_reward() or not _save_base(true):
			if play_started or net == &"solo":
				ui.session_menu(net, "El guardado falló. Inténtalo de nuevo.")
			else:
				ui.wait_for_guest(sim.base.name, _address, "El guardado falló. Inténtalo de nuevo.")
			return
		if guest_peer != 0:
			_end_session.rpc_id(guest_peer)
	_close_network()
	ui.lobby(profile, "")


func _close_network() -> void:
	net = &"lobby"
	_surface_camera()
	play_started = false
	guest_peer = 0
	guest_id = ""
	_replica_positions.clear()
	_replica_headings.clear()
	flight.present(-1, 0.0)
	ui.flight_status(-1, 0.0)
	multiplayer.multiplayer_peer = null
	for pilot in pilots:
		pilot.show()


func _lan_address(port: int) -> String:
	for address in IP.get_local_addresses():
		if (
			address.begins_with("192.168.")
			or address.begins_with("10.")
			or address.begins_with("172.")
		):
			return "%s   ·   UDP %d" % [address, port]
	return "Dirección local   ·   UDP %d" % port


func _request_join() -> void:
	_join_request.rpc_id(
		1, profile.data.id, PackedStringArray(profile.data.opened), profile.data.active_role
	)


@rpc("any_peer", "call_remote", "reliable")
func _join_request(id: String, unlocked: PackedStringArray, role: String) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if net != &"host" or guest_peer != 0 or sender <= 1:
		return
	if id.length() != 32 or not id.is_valid_hex_number() or sim.base_id not in unlocked:
		_join_rejected.rpc_id(sender, "Debes tener esta base desbloqueada.")
		return
	guest_peer = sender
	guest_id = id
	sim.roles[1] = role if sim.rules.roles.has(role) else ""
	sim.set_guest(true, pilots[1].position)
	_inactivity = 0.0
	_accept_join.rpc_id(sender, sim.base_id, saved_run, sim.roles)
	_send_awards()
	if not play_started:
		play_started = true
		ui.playing()
	_send_snapshot()
	_notice("Los dos astronautas están conectados.")


@rpc("authority", "call_remote", "reliable")
func _accept_join(id: String, seed_value: int, active_roles: Array) -> void:
	if net != &"joining":
		return
	_prepare_base(id, seed_value)
	sim.roles = active_roles
	sim.connected[1] = true
	net = &"guest"
	ui.show_balance(profile.balance_text())
	ui.playing()


@rpc("authority", "call_remote", "reliable")
func _join_rejected(reason: String) -> void:
	_close_network()
	ui.lobby(profile, reason)


@rpc("authority", "call_remote", "reliable")
func _end_session() -> void:
	_host_left()


func _peer_left(peer: int) -> void:
	if net != &"host" or peer != guest_peer:
		return
	var tutorial := sim.phase == &"tutorial"
	sim.set_guest(false, pilots[1].position)
	if tutorial:
		positions_at_dawn = _positions()
		_save_base(false)
	_route[1].clear()
	_vectors[1] = Vector2.ZERO
	guest_peer = 0
	guest_id = ""
	_notice("Tu compañero salió. La base sigue activa.")


func _host_left() -> void:
	if net in [&"guest", &"joining"]:
		_close_network()
		ui.lobby(profile, "El anfitrión salió. Se conservaron las monedas aseguradas.")


func _connection_failed() -> void:
	if net == &"joining":
		_close_network()
		ui.lobby(profile, "No se encontró la partida en esa dirección.")


func _local_frame(delta: float) -> void:
	if not _pending_reward.is_empty():
		_render(delta, 0)
		return
	_vectors[0] = ui.joystick.axis if ui.play.visible else Vector2.ZERO
	_inactivity += delta
	if _inactivity > 0.45:
		_vectors[1] = Vector2.ZERO
	for index in range(2):
		_move_pilot(index, delta)
		_spots[index] = _spot_at(pilots[index].position)

	if guest_peer != 0 and sim.phase not in [&"tutorial", &"flight"]:
		var period := float(sim.rules.cycle.period)
		var time := clampf(period - sim.elapsed, 0.0, delta)
		_coins_by_guest[guest_id] = (
			float(_coins_by_guest.get(guest_id, 0.0)) + sim.wallet_rate(true) * time / period
		)
	var day_rate := sim.wallet_rate(not sim.solo)
	var had_returned := sim.returned
	sim.tick(delta, _sheltered(), _spots)
	if sim.withdrew:
		_set_positions(positions_at_dawn)
		_route[0].clear()
		_route[1].clear()
		if not sim.dawn:
			_coins_by_guest.clear()
		_notice("Sin aire. Regreso al último amanecer.")
	if sim.dawn:
		positions_at_dawn = _positions()
		_pending_reward = {"day": sim.days, "amount": day_rate, "guests": _coins_by_guest}
		_coins_by_guest = {}
		_commit_reward()
	if not had_returned and sim.returned:
		sim.checkpoint.returned = true
		sim.checkpoint.earth_ok = false
		sim.checkpoint.radio_left = 0.0
		_pending_reward = {"difficulty": int(sim.difficulty.coins), "guest": guest_id}
		_commit_reward()
	_render(delta, 0)
	_sync_left -= delta
	if _sync_left <= 0.0:
		_sync_left = SAMPLE_RATE
		_send_snapshot()


func _commit_reward() -> bool:
	if _pending_reward.is_empty():
		return true
	var before := int(profile.data.balance)
	var daily := _pending_reward.has("day")
	if daily:
		profile.pay_day(
			sim.base_id,
			saved_run,
			_pending_reward.day,
			_pending_reward.amount,
			_pending_reward.guests
		)
	else:
		profile.pay_mission(sim.base_id, _pending_reward.difficulty, _pending_reward.guest)
	if not _save_base(false):
		_reward_retry = 1.0
		_notice("No se guardaron las monedas. Se está reintentando…", false)
		return false
	_pending_reward.clear()
	_send_awards()
	var message := "Amanecer. Progreso asegurado." if daily else "¡Misión de regreso completada!"
	_show_reward(int(profile.data.balance) - before, message)
	return true


func _guest_frame(delta: float) -> void:
	_send_left -= delta
	if _send_left <= 0.0:
		_send_left = 0.06
		_guest_move.rpc_id(1, ui.joystick.axis, _jump[0])
		_jump[0] = false
	if _replica_positions.is_empty():
		return
	for index in range(2):
		var pilot := pilots[index]
		var target: Vector3 = _replica_positions[index]
		var difference := pilot.position.distance_squared_to(target)
		pilot.position = (
			target if difference > 16.0 else pilot.position.lerp(target, minf(delta * 12.0, 1.0))
		)
		pilot.animate_replica(
			delta,
			_replica_headings[index],
			difference > 0.012,
			sim.pilots[index].cargo != 0,
			sim.pilots[index].seated
		)
		_spots[index] = _spot_at(pilot.position)
	_render(delta, 1)


func _interact(player: int, release: bool) -> void:
	if not _pending_reward.is_empty():
		return
	if sim.phase == &"flight":
		return
	var pilot := pilots[player]
	var spot := _spots[player]
	var message := ""
	var was_tutorial := sim.phase == &"tutorial"
	if release:
		var cargo := sim.cargo_kind(player)
		var station_deposit := (
			spot == &"training" and (sim.solo or player == 1) and cargo == &"sample"
		)
		station_deposit = station_deposit or (spot == &"refinery" and cargo in [&"ice", &"ore"])
		station_deposit = station_deposit or (spot == &"pad" and cargo in [&"fuel", &"food"])
		if station_deposit:
			message = sim.use_station(player, spot)
		else:
			var other := 1 - player
			var near: bool = (
				sim.connected[other] and pilot.position.distance_to(pilots[other].position) <= 2.35
			)
			message = sim.release(player, pilot.position, near)
	else:
		if sim.pilots[player].seated:
			spot = &"pad"
		var crate := sim.closest_crate(pilot.position) if sim.cargo_kind(player) == &"" else 0
		if crate != 0 and sim.pickup(player, crate):
			_notice("Caja recogida")
			return
		message = sim.use_station(player, spot)
		if sim.pilots[player].seated:
			pilot.position = CrestWorld.BOARDING[player]
	if was_tutorial and sim.phase == &"active":
		positions_at_dawn = _positions()
		_save_base(false)
	if message.is_empty():
		message = "Acércate a una estación o a una caja" if not release else "Toma una caja primero"
	_notice(message)


func _set_destination(player: int, point: Vector3) -> void:
	if point.is_finite():
		_route[player] = _planner.plan(
			_routes, pilots[player].position, point, sim.rules.open_world
		)


func _move_pilot(index: int, delta: float) -> void:
	var pilot := pilots[index]
	var jump := _jump[index]
	_jump[index] = false
	if sim.phase == &"flight" or not sim.connected[index] or sim.pilots[index].seated:
		pilot.velocity = Vector3.ZERO
		return
	# Sin colision bajo los pies el piloto espera quieto a que llegue su chunk.
	if not streamer.is_ready_at(pilot.position):
		pilot.velocity = Vector3.ZERO
		_chunk_ready[index] = false
		return
	# Solo al llegar el chunk: height_at es bilineal y la malla triangulada.
	if not _chunk_ready[index]:
		_chunk_ready[index] = true
		var ground := streamer.height_at(pilot.position)
		if pilot.position.y < ground - SINK_TOLERANCE:
			pilot.position.y = ground + 0.1
			pilot.velocity.y = 0.0
	var input: Vector2 = _vectors[index]
	var direction := Vector2.ZERO
	if input.length_squared() > 0.012:
		_route[index].clear()
		var right := Vector2(camera.basis.x.x, camera.basis.x.z).normalized()
		var back := Vector2(camera.basis.z.x, camera.basis.z.z).normalized()
		direction = (right * input.x + back * input.y).limit_length(input.length())
	else:
		direction = _follow_path(index, pilot.position)
	var heading := Vector3(direction.x, 0.0, direction.y) * FieldPilot.WALK_SPEED
	for motion: Vector3 in [pilot.velocity, heading]:
		if not streamer.is_ready_at(pilot.position + motion * delta * LOOKAHEAD_FRAMES):
			direction = Vector2.ZERO
			pilot.velocity.x = 0.0
			pilot.velocity.z = 0.0
	var carrying: bool = sim.pilots[index].cargo != 0
	pilot.jump_scale = float(sim.rules.open_world.jump_with_box) if carrying else 1.0
	pilot.lunar_gait = _camera_outside(pilot.position)
	pilot.drive(delta, direction * sim.speed_factor(index), jump, false)
	pilot.animate_gait(delta, carrying, false)


func _follow_path(index: int, point: Vector3) -> Vector2:
	var route := _route[index]
	while not route.is_empty():
		var displacement := route[0] - Vector2(point.x, point.z)
		if displacement.length_squared() > 0.072:
			return (
				displacement.limit_length(0.65).normalized()
				* minf(1.0, displacement.length() * 1.9)
			)
		route.remove_at(0)
	_route[index] = route
	return Vector2.ZERO


func _sheltered() -> Array[bool]:
	return [
		world.sheltered(pilots[0].position) or sim.pilots[0].seated,
		world.sheltered(pilots[1].position) or sim.pilots[1].seated
	]


func _render(delta: float, player: int) -> void:
	for index in range(2):
		pilots[index].visible = sim.connected[index] and sim.phase != &"flight"
	for id: int in _boxes.keys():
		if not sim.crates.has(id):
			_boxes[id].queue_free()
			_boxes.erase(id)
	for id: int in sim.crates:
		var crate: Dictionary = sim.crates[id]
		if not _boxes.has(id):
			var box := Node3D.new()
			if CARGO_MODELS.has(crate.kind):
				box.add_child(_cargo_model(crate.kind))
			else:
				FieldWorld.box(box, Vector3.ZERO, Vector3(0.53, 0.48, 0.49), MATCOLORS[crate.kind])
				FieldWorld.box(
					box, Vector3.UP * 0.245, Vector3(0.25, 0.038, 0.44), CrestWorld.FRAME
				)
			add_child(box)
			_boxes[id] = box
		var mesh: Node3D = _boxes[id]
		mesh.global_position = (
			crate.point + Vector3.UP * 0.29
			if crate.owner == -1
			else pilots[crate.owner].carrying.global_position
		)
		# Las cajas sueltas siguen en `sim.crates`; solo se ocultan si su chunk no esta cargado.
		mesh.visible = crate.owner != -1 or streamer.is_ready_at(crate.point)
	world.reflect(sim, _spots, delta, _focus_points(), pilots[player].position)
	world.show_refuge_alert(sim.storm_warning() > 0.0 or sim.storm_active())
	var view := sim.flight_stage()
	var flight_phase := int(view.x)
	world.present_lander(flight_phase, view.y, sim.returned)
	flight.present(flight_phase, view.y)
	_feedback_time = maxf(0.0, _feedback_time - delta)
	var note := _feedback if _feedback_time > 0.0 else ""
	ui.sync(sim, player, _spots[player], _sheltered(), note, pilots[player].position)
	ui.flight_status(flight_phase, view.y)
	_alert_if_changed()


## Copia del modelo de carga. Las copias comparten los materiales de una plantilla oculta:
## liberar una caja con materiales propios deja errores del servidor de render (headless).
func _cargo_model(kind: StringName) -> Node3D:
	if not _cargo_templates.has(kind):
		var info: Array = CARGO_MODELS[kind]
		var template: Node3D = (info[0] as PackedScene).instantiate()
		PaperMaterial.restyle(template, false)
		template.scale = Vector3.ONE * float(info[1])
		template.hide()
		add_child(template)
		_cargo_templates[kind] = template
	var model: Node3D = (_cargo_templates[kind] as Node3D).duplicate()
	model.show()
	return model


func _alert_if_changed() -> void:
	var kind := ""
	if sim.storm_warning() > 0.0 or sim.storm_active():
		kind = "solar"
	elif sim.outage_warning() > 0.0 or sim.energy_cut():
		kind = "power"
	elif sim.radio_warning() or sim.radio_cut():
		kind = "radio"
	if kind != _alert_kind and not kind.is_empty():
		_alert_audio.play()
	_alert_kind = kind


func _build_alert_audio() -> void:
	var stream := AudioStreamWAV.new()
	var buffer := PackedByteArray()
	buffer.resize(4000)
	for index in range(buffer.size()):
		var fade := minf(1.0, index / 300.0) * (1.0 - float(index) / buffer.size())
		buffer[index] = int(38.0 * sin(TAU * index * 660.0 / 22050.0) * fade) & 255
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 22050
	stream.data = buffer
	_alert_audio.stream = stream
	add_child(_alert_audio)
	_reward_audio.stream = stream
	_reward_audio.pitch_scale = 1.5
	add_child(_reward_audio)


func _send_snapshot() -> void:
	if guest_peer != 0:
		var snapshot := [
			sim.state(), sim.connected, _positions(), [pilots[0].direction, pilots[1].direction]
		]
		_snapshot.rpc_id(
			guest_peer, var_to_bytes(snapshot).compress(FileAccess.COMPRESSION_DEFLATE)
		)


@rpc("authority", "call_remote", "unreliable_ordered")
func _snapshot(packet: PackedByteArray) -> void:
	if net != &"guest":
		return
	var snapshot: Variant = bytes_to_var(
		packet.decompress_dynamic(16384, FileAccess.COMPRESSION_DEFLATE)
	)
	if snapshot is Array and snapshot.size() == 4:
		sim.restore(snapshot[0])
		sim.connected = snapshot[1]
		_replica_positions = snapshot[2]
		_replica_headings = snapshot[3]


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _guest_move(axis: Vector2, jump: bool) -> void:
	if net == &"host" and multiplayer.get_remote_sender_id() == guest_peer and axis.is_finite():
		_vectors[1] = axis.limit_length()
		_jump[1] = _jump[1] or jump
		_inactivity = 0.0


@rpc("any_peer", "call_remote", "reliable")
func _guest_destination(point: Vector3) -> void:
	if net == &"host" and multiplayer.get_remote_sender_id() == guest_peer and play_started:
		_set_destination(1, point)


@rpc("any_peer", "call_remote", "reliable")
func _guest_action(release: bool) -> void:
	if net == &"host" and multiplayer.get_remote_sender_id() == guest_peer and play_started:
		_interact(1, release)


func _notice(message: String, share: bool = true) -> void:
	_feedback = message
	_feedback_time = 3.1
	if share and net == &"host" and guest_peer != 0:
		_remote_notice.rpc_id(guest_peer, message)


@rpc("authority", "call_remote", "reliable")
func _remote_notice(message: String) -> void:
	if net == &"guest":
		_notice(message)


func _show_reward(amount: int, message: String) -> void:
	if amount > 0:
		_reward_audio.play()
		message += " +%.2f monedas" % (float(amount) / LunarProfile.SCALE)
	ui.show_balance(profile.balance_text())
	_notice(message, false)


func _send_awards() -> void:
	_award_retry = 2.0
	if guest_peer == 0:
		return
	var pending: Dictionary = profile.data.guest_awards.get(guest_id, {})
	var batch := {}
	for id: Variant in pending:
		if profile.valid_guest_award(id, pending[id]):
			batch[id] = pending[id]
			if batch.size() == LunarProfile.AWARD_BATCH:
				break
	if not batch.is_empty():
		_award.rpc_id(guest_peer, batch)


@rpc("authority", "call_remote", "reliable")
func _award(receipts: Dictionary) -> void:
	if net != &"guest" or receipts.size() > LunarProfile.AWARD_BATCH:
		return
	var before := int(profile.data.balance)
	var accepted := PackedStringArray()
	var changed := false
	for id: Variant in receipts:
		var amount: Variant = receipts[id]
		if profile.valid_guest_award(id, amount):
			changed = profile.credit(id, amount) or changed
			accepted.append(id)
	if changed and not profile.save():
		_notice("Tus monedas están pendientes de guardar. Se reintentará.", false)
		return
	if not accepted.is_empty():
		_confirm_awards.rpc_id(1, accepted)
	if changed:
		_show_reward(int(profile.data.balance) - before, "Recompensa asegurada.")


@rpc("any_peer", "call_remote", "reliable")
func _confirm_awards(receipts: PackedStringArray) -> void:
	if net != &"host" or guest_peer == 0 or multiplayer.get_remote_sender_id() != guest_peer:
		return
	if receipts.size() > LunarProfile.AWARD_BATCH:
		return
	var pending: Dictionary = profile.data.guest_awards.get(guest_id, {})
	var changed := false
	for id in receipts:
		changed = pending.erase(id) or changed
	if not changed:
		return
	if pending.is_empty():
		profile.data.guest_awards.erase(guest_id)
	if profile.save():
		_send_awards()


func _show_science(step: int) -> void:
	_science_index = posmod(_science_index + step, sim.records.size())
	var record := sim.records[_science_index]
	var title: String = CrestSim.SCIENCE_TITLES.get(record.id, record.instrument)
	ui.show_science(title, sim.science_text(record), _science_index, sim.records.size())


func _add_pilot(index: int) -> void:
	pilots.append(LunarPilotFactory.spawn(self, index, sim.rules.open_world))
