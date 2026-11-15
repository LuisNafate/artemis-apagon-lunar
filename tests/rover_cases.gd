class_name RoverCases
extends RefCounted

## Casos del rover: radio mientras esta bloqueado, desbloqueo por entregas, conduccion,
## radio solo con el rover aparcado, regreso al amanecer y cooperativo (open_world_suite).

const BASE := "mons_mouton_plateau"

var _suite: Node


func _init(suite: Node) -> void:
	_suite = suite


func run() -> void:
	await _locked_radio()
	await _delivery()
	await _driving()
	await _parked_radio()
	await _persistence()
	await _air_out()
	await _coop()


func _locked_radio() -> void:
	_suite._cases += 1
	var game: Node = await _suite._game_solo(BASE)
	var ui: LunarInterface = game.ui
	_suite._check(game.rover.body.is_inside_tree(), "the rover is a body in the campaign world")
	_suite._check(
		game.rover.body.position.distance_to(RoverSpec.park_point()) < 0.01,
		"the rover starts at its parking spot"
	)
	_suite._check(not game.sim.rover.unlocked, "the rover starts locked")
	var footprint := CylinderShape3D.new()
	footprint.radius = float(RoverSpec.data.collision_radius) + 0.05
	footprint.height = 1.0
	var probe := PhysicsShapeQueryParameters3D.new()
	probe.shape = footprint
	probe.collision_mask = 1
	probe.exclude = [game.rover.body.get_rid()]
	probe.transform = Transform3D(Basis.IDENTITY, RoverSpec.park_point() + Vector3(0, 0.6, 0))
	var overlaps: Array = game.get_world_3d().direct_space_state.intersect_shape(probe, 8)
	_suite._check(
		overlaps.is_empty(), "nothing solid overlaps the parked rover (%d)" % overlaps.size()
	)
	await _stand_by(game)
	_suite._check(game._spots[0] == &"radio", "next to the locked rover the spot is the radio")
	_suite._check(ui.action_button.text == "Enviar lista de vuelo", "Action is the radio")
	_suite._check(not ui.action_button.disabled, "the radio can send")
	_suite._check("Mineral 0/3 · Hielo 0/3" in ui._zone_detail.text, "panel shows the progress")
	_suite._check(not ui.radio_button.visible, "no separate radio button while locked")
	ui.selected.emit("action", "")
	await _suite._frames(3)
	_suite._check(game.sim.radio_left > 0.0, "the flight list goes out as before")
	await _close(game)


func _delivery() -> void:
	_suite._cases += 1
	var game: Node = await _suite._game_solo(BASE)
	var ui: LunarInterface = game.ui
	var sim: LunarMission = game.sim
	await _stand_by(game)
	sim._create_cargo(0, &"fuel")
	await _suite._frames(3)
	_suite._check(not LunarItemContext.delivers(sim, 0, &"radio"), "fuel does not count")
	_suite._check(ui.release_button.text.begins_with("Soltar"), "fuel can only be dropped here")
	sim._consume_cargo(0)
	sim._create_cargo(0, &"ice")
	await _suite._frames(3)
	_suite._check(ui.release_button.text == "Entregar hielo al rover", "ice can be delivered")
	ui.selected.emit("release", "")
	await _suite._frames(3)
	_suite._check(sim.cargo_kind(0) == &"" and sim.rover.delivered.ice == 1, "delivery counts 1/3")
	_suite._check("Mineral 0/3 · Hielo 1/3" in ui._zone_detail.text, "panel shows 0/3 and 1/3")
	for kind in [&"ice", &"ice", &"ice"]:
		sim._create_cargo(0, kind)
		game._interact(0, true)
	_suite._check(sim.rover.delivered.ice == 3, "ice stops counting at 3")
	_suite._check(not sim.rover.unlocked, "ice alone does not unlock")
	for index in range(3):
		sim._create_cargo(0, &"ore")
		game._interact(0, true)
		_suite._check(
			sim.rover.unlocked == (index == 2), "unlocks exactly when both reach 3 (%d)" % index
		)
	_suite._check(sim.rover.delivered.ore == 3 and sim.rover.delivered.ice == 3, "3 ore and 3 ice")
	sim.crates.clear()
	await _suite._frames(3)
	_suite._check(ui.action_button.text == "Subir al rover", "unlocked: Action is Subir al rover")
	_suite._check(game._spots[0] == &"rover", "unlocked: the spot is the rover")
	_suite._check(ui.radio_button.visible, "parked and unlocked: the radio has its own button")
	await _close(game)


func _driving() -> void:
	_suite._cases += 1
	var game: Node = await _suite._game_solo(BASE)
	var ui: LunarInterface = game.ui
	var sim: LunarMission = game.sim
	sim.rover.unlocked = true
	var body: RoverBody = game.rover.body
	await _stand_by(game)
	ui.selected.emit("action", "")
	await _suite._frames(3)
	_suite._check(sim.rover.driver == 0, "Action boards the rover")
	_suite._check(ui.action_button.text == "Bajar del rover", "inside, Action says Bajar")
	_suite._check(not ui.jump_button.visible, "the rover has no Saltar button")
	_suite._check(not game.pilots[0].visible, "the rider is hidden")
	_suite._check(
		game.pilots[0].position.distance_to(body.position) < 0.05, "the pilot rides with the rover"
	)
	game._set_destination(0, Vector3(0, 0, 0))
	_suite._check(game._route[0].is_empty(), "tapping the ground draws no route while driving")
	# Hacia el oeste por la base: sube a 12 m/s y no pasa de ahi.
	var top := 0.0
	var start := body.position
	game.ui.joystick.axis = _axis(game, Vector2(-1, 0))
	for frame in range(150):
		await _suite._frames(1)
		top = maxf(top, Vector2(body.velocity.x, body.velocity.z).length())
	_suite._check(absf(top - 12.0) <= 0.6, "top speed 12 m/s +/- 5 percent (%.2f)" % top)
	_suite._check(start.distance_to(body.position) > 12.0, "the rover really travels")
	_suite._check(body.position.x > -19.0, "the west wall stops the rover (%.2f)" % body.position.x)
	_suite._check(
		game.pilots[0].position.distance_to(body.position) < 0.05, "pilot and rover stay together"
	)
	_suite._check(
		absf(game.camera.position.x - game.pilots[0].position.x) < 40.0, "camera keeps following"
	)
	# Contra el muro este: no lo atraviesa.
	_place_rover(game, Vector3(15.0, 0.04, -6.0), -PI * 0.5)
	game.ui.joystick.axis = _axis(game, Vector2(1, 0))
	await _suite._frames(120)
	_suite._check(body.position.x < 19.1, "the east wall stops the rover (%.2f)" % body.position.x)
	# No salta.
	var ground := body.position.y
	game._jump[0] = true
	var peak := ground
	for frame in range(30):
		await _suite._frames(1)
		peak = maxf(peak, body.position.y)
	_suite._check(peak - ground < 0.1, "the rover does not jump (%.3f)" % (peak - ground))
	# En el refugio el aire del traje no se repone: el rover no esta presurizado.
	_place_rover(game, Vector3(15.0, 0.04, 2.5), 0.0)
	game.ui.joystick.axis = Vector2.ZERO
	await _suite._frames(5)
	_suite._check(game.world.sheltered(game.pilots[0].position), "the rover is inside the refuge")
	_suite._check(not game._sheltered()[0], "driving inside the refuge is not sheltered")
	# Sale por la puerta de 3 m.
	var door: Vector3 = game.world.enclosure.door_point()
	_place_rover(game, Vector3(14.0, 0.04, door.z), -PI * 0.5)
	game.ui.joystick.axis = _axis(game, Vector2(1, 0))
	await _suite._frames(160)
	_suite._check(
		body.position.x > 26.0, "the rover leaves through the door (%.2f)" % body.position.x
	)
	# Bajar: aparece junto al rover y el piloto vuelve a verse.
	game.ui.joystick.axis = Vector2.ZERO
	await _suite._frames(30)
	_suite._check(game.streamer.is_ready_at(body.position), "chunk is loaded outside the base")
	ui.selected.emit("action", "")
	await _suite._frames(3)
	_suite._check(sim.rover.driver == -1, "Bajar frees the driver seat")
	var gap: float = game.pilots[0].position.distance_to(body.position)
	_suite._check(
		game.pilots[0].visible and gap > 1.0 and gap < 3.5, "the pilot steps out beside it"
	)
	_suite._check(game._spots[0] == &"rover", "next to the parked-away rover the spot is the rover")
	_suite._check(not ui.radio_button.visible, "away from its spot the radio button is hidden")
	# Sin chunk listo, se congela.
	sim.rover.driver = 0
	await _suite._frames(2)
	var unloaded := Vector3(400, 5, 400)
	body.position = unloaded
	_suite._check(not game.streamer.is_ready_at(unloaded), "the test chunk is not loaded")
	game.ui.joystick.axis = _axis(game, Vector2(1, 0))
	game._vectors[0] = game.ui.joystick.axis
	game.rover.step(1.0 / 60.0)
	_suite._check(
		body.position == unloaded and body.velocity == Vector3.ZERO,
		"the rover freezes while its chunk loads"
	)
	game.ui.joystick.axis = Vector2.ZERO
	await _close(game)


func _parked_radio() -> void:
	_suite._cases += 1
	var game: Node = await _suite._game_solo(BASE)
	var ui: LunarInterface = game.ui
	var sim: LunarMission = game.sim
	sim.rover.unlocked = true
	await _stand_by(game)
	_suite._check(ui.radio_button.visible and not ui.radio_button.disabled, "parked: radio offered")
	ui.selected.emit("radio", "")
	await _suite._frames(3)
	_suite._check(sim.radio_left > 0.0, "parked within its radius the radio sends")
	sim.radio_left = 0.0
	var spot := RoverSpec.park_point()
	_place_rover(game, spot + Vector3(2.5, 0.0, 0.0), -PI * 0.5)
	_suite._check(not sim.radio_available(), "out of the park radius the radio is off")
	_suite._check(
		sim.use_station(0, &"radio").begins_with("Trae el rover") and sim.radio_left == 0.0,
		"the radio does not send with the rover away"
	)
	_place_rover(game, spot + Vector3(0.0, 0.0, 6.0), -PI * 0.5)
	game._set_positions([RoverSpec.stand_point() + Vector3(0, 0.1, 0), Vector3.ZERO])
	await _suite._frames(5)
	_suite._check(game._spots[0] == &"radio", "at its spot with the rover away it is the radio")
	_suite._check(ui.action_button.disabled, "the radio action is disabled")
	_suite._check("rover" in ui._zone_detail.text, "the panel asks to bring the rover back")
	_place_rover(game, spot + Vector3(1.9, 0.0, 0.0), -PI * 0.5)
	_suite._check(sim.radio_available(), "1.9 m from its spot counts as parked")
	await _close(game)


func _persistence() -> void:
	_suite._cases += 1
	var game: Node = await _suite._game_solo(BASE)
	var sim: LunarMission = game.sim
	sim.rover.delivered.ore = 3
	sim.rover.delivered.ice = 3
	sim.rover.unlocked = true
	var away := Vector3(13.0, 0.04, -6.0)
	_place_rover(game, away, 1.25)
	await _suite._frames(3)
	_suite._check(game._save_base(true), "the base saves")
	var again: Node = await _suite._game_continue(game)
	_suite._check(again.sim.rover.unlocked, "still unlocked after saving and continuing")
	_suite._check(again.sim.rover.delivered.ore == 3, "deliveries survive the save")
	_suite._check(again.sim.rover.position.distance_to(away) < 0.05, "the rover keeps its place")
	_suite._check(is_equal_approx(float(again.sim.rover.yaw), 1.25), "the rover keeps its heading")
	await _suite._frames(5)
	_suite._check(again.rover.body.position.distance_to(away) < 0.05, "the body is restored there")
	await _close(again)


func _air_out() -> void:
	_suite._cases += 1
	var game: Node = await _suite._game_solo(BASE)
	var sim: LunarMission = game.sim
	sim.rover.unlocked = true
	sim.store_checkpoint()
	var dawn_spot := RoverSpec.park_point()
	_place_rover(game, Vector3(14.0, 0.04, -7.0), 0.0)
	sim.rover.driver = 0
	game._set_positions([Vector3(14.0, 0.1, -7.0), Vector3.ZERO])
	await _suite._frames(5)
	_suite._check(sim.rover.driver == 0, "driving before the air runs out")
	sim.pilots[0].air = 0.0
	await _suite._frames(5)
	_suite._check(sim.rover.driver == -1, "the driver is out after the air-out")
	_suite._check(sim.rover.unlocked, "the unlock survives the dawn restore")
	_suite._check(
		(
			Vector2(sim.rover.position.x - dawn_spot.x, sim.rover.position.z - dawn_spot.z).length()
			< 0.1
		),
		"the rover goes back to its dawn position"
	)
	_suite._check(
		game.rover.body.position.distance_to(sim.rover.position) < 0.05, "the body follows it back"
	)
	await _close(game)


func _coop() -> void:
	_suite._cases += 1
	var host: Node = _suite._new_game("user://rover-host-%d.dat" % randi())
	var guest: Node = _suite._new_game("user://rover-guest-%d.dat" % randi())
	var port := 46400 + randi_range(0, 150)
	await _suite._frames(2)
	host.host(BASE, port)
	guest.join("127.0.0.1", port)
	for index in range(160):
		if host.guest_peer != 0 and guest.net == &"guest":
			break
		OS.delay_msec(2)
		await _suite.get_tree().physics_frame
	_suite._check(host.guest_peer != 0 and guest.net == &"guest", "two peers connect")
	if guest.net != &"guest":
		return
	host.sim.finish_tutorial()
	host.sim.rover.unlocked = true
	await _suite._until(func() -> bool: return host.streamer.is_ready_at(host.pilots[0].position))
	var stand := RoverSpec.stand_point() + Vector3(0, 0.1, 0)
	host._set_positions([stand, stand + Vector3(0.0, 0.0, 1.2)])
	await _suite._frames(5)
	host.ui.selected.emit("action", "")
	await _suite._frames(3)
	_suite._check(host.sim.rover.driver == 0, "the host boards")
	var start: Vector3 = host.rover.body.position
	host.ui.joystick.axis = _axis(host, Vector2(1, 0))
	for index in range(60):
		OS.delay_msec(2)
		await _suite.get_tree().physics_frame
	host.ui.joystick.axis = Vector2.ZERO
	for index in range(40):
		OS.delay_msec(2)
		await _suite.get_tree().physics_frame
	_suite._check(host.rover.body.position.distance_to(start) > 3.0, "the host drove away")
	_suite._check(guest.sim.rover.driver == 0, "the guest sees the host at the wheel")
	_suite._check(
		guest.rover.body.position.distance_to(host.rover.body.position) < 1.0,
		"the guest sees the rover where the host drove it"
	)
	_suite._check(
		(
			host.sim.use_station(1, &"rover") == "Tu compañero conduce el rover"
			and host.sim.rover.driver == 0
		),
		"only one drives at a time"
	)
	_suite._check(
		LunarItemContext.at(host.sim, 1, &"rover", &"")[2], "the other seat's Action is disabled"
	)
	# El anfitrion baja y el invitado se sube desde su dispositivo.
	host.ui.selected.emit("action", "")
	await _suite._frames(3)
	_suite._check(host.sim.rover.driver == -1, "the host steps out")
	var beside: Vector3 = host.rover.body.position + Vector3(1.6, 0.1, 0.0)
	host._set_positions([beside + Vector3(0, 0, 5.0), beside])
	for index in range(40):
		OS.delay_msec(2)
		await _suite.get_tree().physics_frame
	guest.ui.selected.emit("action", "")
	for index in range(40):
		if host.sim.rover.driver == 1:
			break
		OS.delay_msec(2)
		await _suite.get_tree().physics_frame
	_suite._check(host.sim.rover.driver == 1, "the guest boards over the network")
	var before: Vector3 = host.rover.body.position
	guest.ui.joystick.axis = _axis(guest, Vector2(0, 1))
	for index in range(90):
		OS.delay_msec(2)
		await _suite.get_tree().physics_frame
	guest.ui.joystick.axis = Vector2.ZERO
	_suite._check(host.rover.body.position.distance_to(before) > 3.0, "the guest drives the rover")
	for node: Node in [host, guest]:
		DirAccess.remove_absolute(node.profile_path)
		node.get_parent().queue_free()
	await _suite.get_tree().process_frame


## Pone al astronauta junto al rover aparcado y espera a que el panel se actualice.
func _stand_by(game: Node) -> void:
	game._set_positions([RoverSpec.stand_point() + Vector3(0, 0.1, 0), Vector3.ZERO])
	await _suite._frames(5)


## Mueve el rover (cuerpo y estado) sin conductor ni animacion.
func _place_rover(game: Node, point: Vector3, yaw: float) -> void:
	game.sim.rover.position = point
	game.sim.rover.yaw = yaw
	game.rover.body.place(point, yaw)
	if int(game.sim.rover.driver) != -1:
		game.pilots[int(game.sim.rover.driver)].position = point


## Palanca que da una direccion de mundo con la camara actual.
func _axis(game: Node, world_direction: Vector2) -> Vector2:
	var right := Vector2(game.camera.basis.x.x, game.camera.basis.x.z).normalized()
	var back := Vector2(game.camera.basis.z.x, game.camera.basis.z.z).normalized()
	return Vector2(world_direction.dot(right), world_direction.dot(back))


func _close(game: Node) -> void:
	DirAccess.remove_absolute(game.profile_path)
	game.get_parent().queue_free()
	await _suite.get_tree().process_frame
