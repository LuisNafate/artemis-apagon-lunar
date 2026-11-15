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
	await _tray_ground()
	await _tray_hand()
	await _tray_refinery()
	await _tray_drop()
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
	_check_seated(game, 0, game, "the driver")
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
	_check_seated(game, 0, game, "after driving the driver")
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
	host.sim.rover.tray.append(&"ice")
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
	_check_seated(guest, 0, host, "the guest sees the host seated:")
	_suite._check(
		guest.rover.body._tray_kinds == [&"ice"] and guest.rover.body._tray.get_child_count() == 1,
		"the guest sees the crate in the tray"
	)
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


## Conduciendo junto a cajas sueltas: Cargar caja, maximo 2, con la bandeja llena no carga.
func _tray_ground() -> void:
	_suite._cases += 1
	var game: Node = await _suite._game_solo(BASE)
	var ui: LunarInterface = game.ui
	var sim: LunarMission = game.sim
	sim.rover.unlocked = true
	await _stand_by(game)
	ui.selected.emit("action", "")
	await _suite._frames(3)
	_suite._check(sim.rover.driver == 0, "boarded to load crates")
	var spot: Vector3 = sim.rover.position
	sim.spawn_crate(&"ice", spot + Vector3(1.6, 0.0, 0.0))
	sim.spawn_crate(&"ore", spot + Vector3(-1.6, 0.0, 0.0))
	sim.spawn_crate(&"fuel", spot + Vector3(0.0, 0.0, 1.6))
	sim.spawn_crate(&"ice", spot + Vector3(0.0, 0.0, 9.0))
	await _until_ready(game, spot + Vector3(0.0, 0.0, 9.0))
	await _suite._frames(5)
	_suite._check(ui.action_button.text == "Cargar caja", "next to a loose crate: Cargar caja")
	_suite._check("Bandeja 0/2" in ui._zone_detail.text, "the panel shows the tray")
	ui.selected.emit("action", "")
	await _suite._frames(3)
	_suite._check(sim.rover.tray.size() == 1 and sim.crates.size() == 3, "one crate is on the tray")
	_suite._check(sim.rover.driver == 0, "loading keeps the driver at the wheel")
	ui.selected.emit("action", "")
	await _suite._frames(3)
	_suite._check(sim.rover.tray.size() == 2, "the tray holds 2")
	_suite._check(sim.crates.size() == 2, "a loaded crate leaves the ground")
	_suite._check(game.rover.body._tray.get_child_count() == 2, "the tray crates show on the model")
	await _suite._frames(3)
	_suite._check(ui.action_button.text == "Bajar del rover", "full tray: no more loading")
	_suite._check("llena" in ui._zone_detail.text, "full tray is shown")
	game._interact(0, false)
	await _suite._frames(2)
	_suite._check(sim.rover.tray.size() == 2, "a third crate is not loaded")
	_suite._check(sim.crates.size() == 2, "the far crate stays on the ground")
	_suite._check(sim.state().rover.tray.size() == 2, "the tray rides in the saved state")
	await _close(game)


## Bajado junto al rover con una caja en la mano: Cargar en el rover.
func _tray_hand() -> void:
	_suite._cases += 1
	var game: Node = await _suite._game_solo(BASE)
	var ui: LunarInterface = game.ui
	var sim: LunarMission = game.sim
	sim.rover.unlocked = true
	await _stand_by(game)
	sim._create_cargo(0, &"ore")
	await _suite._frames(4)
	_suite._check(ui.action_button.text == "Cargar en el rover", "with a crate: Cargar en el rover")
	_suite._check(not ui.action_button.disabled, "loading from hands is enabled")
	ui.selected.emit("action", "")
	await _suite._frames(3)
	_suite._check(
		sim.cargo_kind(0) == &"" and sim.rover.tray == [&"ore"], "the crate is on the tray"
	)
	_suite._check(sim.crates.is_empty(), "the hand crate is consumed")
	sim._create_cargo(0, &"ice")
	game._interact(0, false)
	_suite._check(sim.rover.tray.size() == 2, "a second crate fits")
	sim._create_cargo(0, &"ice")
	await _suite._frames(4)
	_suite._check(ui.action_button.disabled, "full tray: loading from hands is disabled")
	game._interact(0, false)
	_suite._check(sim.rover.tray.size() == 2 and sim.cargo_kind(0) == &"ice", "nothing more loads")
	await _close(game)


## En el refinado, conduciendo, Entregar descarga: hielo se refina, mineral se guarda.
func _tray_refinery() -> void:
	_suite._cases += 1
	var game: Node = await _suite._game_solo(BASE)
	var ui: LunarInterface = game.ui
	var sim: LunarMission = game.sim
	sim.rover.unlocked = true
	var station: Vector3 = CrestWorld.campaign_stations[&"refinery"]
	var at := station + Vector3(1.3, 0.04, 0.0)
	_place_rover(game, at, 0.0)
	sim.rover.driver = 0
	game._set_positions([at + Vector3(0, 0.1, 0), Vector3.ZERO])
	sim.rover.tray.assign([&"ice", &"ore", &"fuel"])
	await _until_ready(game, at)
	await _suite._frames(5)
	_suite._check(game._spots[0] == &"refinery", "the driver is at the refinery")
	_suite._check(ui.release_button.visible, "the driver sees the unload button")
	_suite._check(ui.release_button.text == "Descargar en Refinado", "unload caption at refinery")
	var ore := sim.ore
	ui.selected.emit("release", "")
	await _suite._frames(3)
	_suite._check(not sim.refining.is_empty(), "the ice goes to the refinery")
	_suite._check(sim.rover.tray == [&"ore", &"fuel"], "one crate left the tray")
	ui.selected.emit("release", "")
	await _suite._frames(3)
	_suite._check(sim.ore == ore + 1 and sim.rover.tray == [&"fuel"], "the ore is stored")
	_suite._check(ui.release_button.text == "Soltar caja", "only fuel left: it can only be dropped")
	_suite._check(
		(
			RoverTray.unload_refinery(sim, 0) == "Nada que descargar aquí"
			and sim.rover.tray == [&"fuel"]
		),
		"the refinery does not take fuel"
	)
	sim.rover.tray.assign([&"ice", &"ice"])
	game._interact(0, true)
	await _suite._frames(2)
	_suite._check(sim.rover.tray.size() == 2, "a busy refinery keeps the crate in the tray")
	_suite._check(ui.feedback.text == "La refinadora está trabajando", "the busy refinery says so")
	sim.rover.tray.assign([&"ice", &"ore"])
	game._interact(0, true)
	_suite._check(sim.rover.tray == [&"ice"], "busy for ice: the ore still goes in")
	await _close(game)


## En otro sitio, Soltar deja una caja junto al rover y se puede volver a recoger.
func _tray_drop() -> void:
	_suite._cases += 1
	var game: Node = await _suite._game_solo(BASE)
	var ui: LunarInterface = game.ui
	var sim: LunarMission = game.sim
	sim.rover.unlocked = true
	var at := Vector3(13.0, 0.04, -6.0)
	_place_rover(game, at, 0.0)
	sim.rover.driver = 0
	game._set_positions([at + Vector3(0, 0.1, 0), Vector3.ZERO])
	sim.rover.tray.assign([&"ore", &"ice"])
	await _until_ready(game, at)
	await _suite._frames(5)
	_suite._check(ui.release_button.text == "Soltar caja", "away from the refinery: Soltar caja")
	ui.selected.emit("release", "")
	await _suite._frames(4)
	_suite._check(sim.rover.tray == [&"ore"], "the top crate leaves the tray")
	_suite._check(sim.crates.size() == 1, "a loose crate appears")
	var crate: Dictionary = sim.crates.values()[0]
	_suite._check(crate.kind == &"ice" and crate.owner == -1, "it is the ice crate, on the ground")
	_suite._check(
		Vector2(crate.point.x - at.x, crate.point.z - at.z).length() < 3.0,
		"it lands next to the rover"
	)
	await _suite._frames(4)
	_suite._check(ui.action_button.text == "Cargar caja", "the dropped crate can be loaded again")
	sim.use_station(0, &"rover")
	await _suite._frames(3)
	_suite._check(sim.rover.driver == -1, "the driver steps out")
	var id: int = sim.crates.keys()[0]
	game._set_positions([crate.point + Vector3(0.0, 0.1, 0.6), Vector3.ZERO])
	await _suite._frames(5)
	_suite._check(game._pickup_at(0) == id, "the dropped crate can be picked up again")
	_suite._check(sim.pickup(0, id) and sim.cargo_kind(0) == &"ice", "and carried")
	await _close(game)


## El conductor se ve sentado encima del rover, mirando hacia donde va. `viewer` es la partida
## que lo dibuja; `source`, la que lo conduce (el invitado ve lo que publica el anfitrion).
func _check_seated(viewer: Node, player: int, source: Node, label: String) -> void:
	var pilot: CrestPilot = viewer.pilots[player]
	var body: RoverBody = viewer.rover.body
	var tolerance := 0.05 if viewer == source else 0.6
	var gap := pilot.position.distance_to(body.seat_point())
	_suite._check(gap < tolerance, "%s sits at the seat point (%.2f)" % [label, gap])
	var rise := pilot.position.y - body.position.y
	_suite._check(rise > 0.3, "%s sits above the ground (%.2f)" % [label, rise])
	_suite._check(pilot.is_visible_in_tree(), "%s is visible" % label)
	_suite._check(pilot.is_seated, "%s is in the seated pose" % label)
	var turn := absf(angle_difference(pilot.rig.rotation.y, body.yaw))
	_suite._check(
		turn < deg_to_rad(10.0), "%s faces the rover heading (%.1f deg)" % [label, rad_to_deg(turn)]
	)


## Pone al astronauta junto al rover aparcado y espera a que el panel se actualice.
func _stand_by(game: Node) -> void:
	game._set_positions([RoverSpec.stand_point() + Vector3(0, 0.1, 0), Vector3.ZERO])
	await _until_ready(game, RoverSpec.stand_point())
	await _suite._frames(5)


## Espera a que el chunk de ese punto tenga suelo.
func _until_ready(game: Node, point: Vector3) -> void:
	await _suite._until(func() -> bool: return game.streamer.is_ready_at(point))


## Mueve el rover (cuerpo y estado) sin conductor ni animacion.
func _place_rover(game: Node, point: Vector3, yaw: float) -> void:
	game.sim.rover.position = point
	game.sim.rover.yaw = yaw
	game.rover.body.place(point, yaw)
	if int(game.sim.rover.driver) != -1:
		game.pilots[int(game.sim.rover.driver)].position = game.rover.body.seat_point()


## Palanca que da una direccion de mundo con la camara actual.
func _axis(game: Node, world_direction: Vector2) -> Vector2:
	var right := Vector2(game.camera.basis.x.x, game.camera.basis.x.z).normalized()
	var back := Vector2(game.camera.basis.z.x, game.camera.basis.z.z).normalized()
	return Vector2(world_direction.dot(right), world_direction.dot(back))


func _close(game: Node) -> void:
	DirAccess.remove_absolute(game.profile_path)
	game.get_parent().queue_free()
	await _suite.get_tree().process_frame
