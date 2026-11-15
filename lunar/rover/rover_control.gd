class_name RoverControl
extends Node

## Une el rover con la partida: el anfitrion (o el modo individual) lo conduce y escribe su
## estado en `LunarMission.rover`; el invitado solo sigue ese estado. El conductor viaja con el
## rover: su piloto queda oculto y la camara lo sigue como siempre.

const RIDE_HEIGHT := 0.6
const CLEARANCE := 0.4

var body := RoverBody.new()
var _game: LunarGame
var _known: Dictionary = {}
var _driver := -1


func _init(game: LunarGame) -> void:
	name = "RoverControl"
	_game = game


func _ready() -> void:
	# Ya aparcado al entrar al arbol: la rejilla de rutas de la base lo ve donde esta.
	body.place(RoverSpec.park_point(), RoverSpec.park_yaw())
	add_child(body)


## Estacion que corresponde a un punto cerca del rover (vacia si esta lejos).
func spot_at(point: Vector3) -> StringName:
	var sim := _game.sim
	if sim.phase in [&"tutorial", &"flight"]:
		return &""
	var at: Vector3 = sim.rover.position
	# El conductor va dentro del rover: sus estaciones son las de alrededor, no el propio rover.
	if int(sim.rover.driver) != -1 and point.distance_to(at) < 0.2:
		return &""
	if Vector2(point.x - at.x, point.z - at.z).length() > float(RoverSpec.data.reach):
		return &""
	return &"rover" if sim.rover.unlocked else &"radio"


## Un fotograma del anfitrion: conduce, congela si falta suelo y publica el estado.
func step(delta: float) -> void:
	var sim := _game.sim
	var info := sim.rover
	if not is_same(info, _known):
		_adopt(info)
	var driver := int(info.driver)
	if driver != -1 and not sim.connected[driver]:
		RoverState.release_driver(sim)
		driver = -1
	if driver != _driver:
		_change_driver(driver)
	var terrain := _game.streamer
	if driver != -1 and terrain.is_ready_at(body.position):
		_drive(delta, driver, terrain)
	else:
		body.hold(delta, terrain)
	info.position = body.position
	info.yaw = body.yaw
	_present(info, terrain)
	if driver != -1:
		_game.pilots[driver].position = body.position
		_game.pilots[driver].velocity = Vector3.ZERO


## Un fotograma del invitado: sigue lo que publica el anfitrion.
func replicate(delta: float) -> void:
	var info := _game.sim.rover
	body.follow(delta, info.position, info.yaw, _game.streamer)
	_present(info, _game.streamer)


## Boton de radio aparte (el Accion queda para subir al rover desbloqueado).
func press_radio() -> void:
	if _game.net == &"guest":
		_guest_radio.rpc_id(1)
	elif _game.net in [&"host", &"solo"]:
		_use_radio(0)


@rpc("any_peer", "call_remote", "reliable")
func _guest_radio() -> void:
	var sender := multiplayer.get_remote_sender_id()
	if _game.net == &"host" and sender == _game.guest_peer and _game.play_started:
		_use_radio(1)


func _use_radio(player: int) -> void:
	var sim := _game.sim
	if not sim.connected[player] or sim.driving(player) or not _game._pending_reward.is_empty():
		return
	var spot := _game._spot_at(_game.pilots[player].position)
	if spot in [&"rover", &"radio"]:
		_game._notice(sim.use_station(player, &"radio"))


func _drive(delta: float, driver: int, terrain: ChunkStreamer) -> void:
	_game._route[driver].clear()
	_game._jump[driver] = false
	var input: Vector2 = _game._vectors[driver]
	var heading := Vector2.ZERO
	if input.length_squared() > 0.012:
		heading = LunarSteer.direction(_game.camera, input)
	# Sin colision por delante el rover espera quieto a que llegue su chunk.
	var motion := body.velocity + Vector3(heading.x, 0.0, heading.y) * float(RoverSpec.data.speed)
	var ahead := body.position + motion * delta * LunarGame.LOOKAHEAD_FRAMES
	if not terrain.is_ready_at(ahead):
		heading = Vector2.ZERO
		body.velocity = Vector3.ZERO
	body.drive(delta, heading, terrain)


func _present(info: Dictionary, terrain: ChunkStreamer) -> void:
	body.visible = terrain.is_ready_at(body.position)
	body.show_tray(info.tray, _game, _game._cargo_templates)
	var driver := int(info.driver)
	if driver == -1:
		body.show_driver("", Color.WHITE)
	else:
		body.show_driver("● J1" if driver == 0 else "◆ J2", _game.pilots[driver].tint)


## El estado cambio por fuera (partida cargada, regreso al amanecer): el cuerpo lo sigue.
func _adopt(info: Dictionary) -> void:
	_known = info
	_driver = int(info.driver)
	body.place(info.position, float(info.yaw))
	var radius := float(RoverSpec.data.collision_radius) + CLEARANCE
	for player in range(2):
		var pilot := _game.pilots[player]
		var gap := Vector2(pilot.position.x - body.position.x, pilot.position.z - body.position.z)
		if player != _driver and _game.sim.connected[player] and gap.length() < radius:
			_place_pilot(player)


## Quien baja aparece junto al rover, en el primer lado libre.
func _change_driver(driver: int) -> void:
	var before := _driver
	_driver = driver
	if driver != -1:
		_game._route[driver].clear()
	if before != -1:
		_place_pilot(before)


func _place_pilot(player: int) -> void:
	var forward := RoverBody.heading_of(body.yaw)
	var right := Vector2(-forward.y, forward.x)
	var distance := float(RoverSpec.data.collision_radius) + float(RoverSpec.data.dismount_gap)
	var chosen := Vector3.INF
	for side: Vector2 in [right, -right, -forward, forward]:
		var point := body.position + Vector3(side.x, 0.0, side.y) * distance
		if _free_at(point):
			chosen = point
			break
		if chosen == Vector3.INF:
			chosen = point
	var ground := _game.streamer.height_at(chosen)
	chosen.y = (ground if ground != -INF else body.position.y) + 0.1
	var pilot := _game.pilots[player]
	pilot.position = chosen
	pilot.velocity = Vector3.ZERO
	_game._chunk_ready[player] = false


func _free_at(point: Vector3) -> bool:
	if not _game.streamer.is_ready_at(point):
		return false
	var probe := PhysicsShapeQueryParameters3D.new()
	var shape := SphereShape3D.new()
	shape.radius = CLEARANCE
	probe.shape = shape
	probe.collision_mask = RoverBody.LAYER
	var ground := _game.streamer.height_at(point)
	probe.transform = Transform3D(Basis.IDENTITY, Vector3(point.x, ground + RIDE_HEIGHT, point.z))
	return _game.get_world_3d().direct_space_state.intersect_shape(probe, 1).is_empty()


## El conductor descarga: en el refinado entra como una entrega; en otro sitio, caja al suelo.
func unload(player: int, spot: StringName) -> String:
	var sim := _game.sim
	if LunarItemContext.delivers(sim, player, spot):
		return RoverTray.unload_refinery(sim, player)
	var back := -RoverBody.heading_of(body.yaw) * (float(RoverSpec.data.collision_radius) + 0.6)
	var ground: Variant = _game._cargo_ground(body.position + Vector3(back.x, 0.0, back.y))
	if ground == null:
		return "Espera a estar sobre terreno cargado."
	return RoverTray.drop(sim, ground)
