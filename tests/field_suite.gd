extends Node

const FIELD := preload("res://field/field.tscn")
const TICK := 1.0 / 60.0

var _assertions := 0
var _failed := 0


func _ready() -> void:
	_check_simulation()
	_check_hazards()
	await _check_scene()
	print("FIELD SUITE: 3 cases, %d assertions, %d failed" % [_assertions, _failed])
	get_tree().quit(1 if _failed else 0)


func _check_simulation() -> void:
	var sim := FieldSim.new()
	sim.advance(40, false)
	_check(sim.elapsed == 0, "timer waits for first delivery")
	_check(not sim.pickup(&"seed_a"), "farm supplies wait for the grid")
	_check(sim.pickup(&"battery"), "take initial cargo")
	_check(not sim.pickup(&"battery"), "capacity is one")
	_check(not sim.use_station(&"generator").is_empty(), "restore the grid")
	_check(not sim.pickup(&"battery"), "cannot collect delivered cargo")
	_check(sim.pickup(&"seed_a") and not sim.use_station(&"farm").is_empty(), "plant first capsule")
	_check(
		sim.pickup(&"seed_b") and not sim.use_station(&"farm").is_empty(), "plant second capsule"
	)
	_check(sim.use_station(&"shelter").is_empty(), "no early victory")
	sim.charge = 0.0
	sim.advance(2.0, true)
	_check(sim.growing == 0.0 and sim.harvested == 0, "growth needs power")
	sim.charge = 100.0
	for frame in range(721):
		sim.advance(TICK, true)
	_check(sim.harvested == 2, "both crops mature")
	_check(not sim.use_station(&"shelter").is_empty() and sim.won, "close the mission")
	sim.advance(100.0, false)
	_check(sim.won and sim.failure.is_empty(), "terminal victory remains stable")


func _check_hazards() -> void:
	var inside := FieldSim.new()
	var outside := FieldSim.new()
	for sim in [inside, outside]:
		sim.pickup(&"battery")
		sim.use_station(&"generator")
		sim.elapsed = 18.0
	for frame in range(60):
		inside.advance(TICK, true)
		outside.advance(TICK, false)
	_check(inside.dose == 0.0 and outside.dose > 6.9, "roof blocks storm exposure")
	_check(inside.air > outside.air, "powered shelter restores air")
	outside.pickup(&"seed_a")
	_check(outside.fall() == &"seed_a" and outside.cargo.is_empty(), "fall drops cargo")
	_check(outside.air < 86.0, "fall costs air")
	outside.elapsed = 41.0
	outside.dose = 99.0
	outside.advance(1.0, false)
	_check(outside.finished() and not outside.won, "exposure can fail mission")
	var deadline := FieldSim.new()
	deadline.pickup(&"battery")
	deadline.use_station(&"generator")
	deadline.elapsed = 84.9
	deadline.advance(0.2, true)
	_check(deadline.failure.contains("turno"), "time can fail mission")


func _check_scene() -> void:
	var game := FIELD.instantiate()
	add_child(game)
	game.set_physics_process(false)
	await get_tree().physics_frame
	game.step(TICK, Vector2.ZERO, false, false, false)
	_check(game.camera.current and game.hud.objective.text == "Recoge la batería", "playable start")
	if "--capture" in OS.get_cmdline_user_args():
		await _capture("inicio")
	_check(not game.try_interact(), "remote interaction rejected")
	await _walk_to(game, Vector3(0, 0, 5.0))
	_check(game.try_interact() and game.sim.cargo == &"battery", "battery collected by proximity")
	await _walk_to(game, Vector3(0, 0, 1.0))
	for frame in range(55):
		await get_tree().physics_frame
		game.step(TICK, Vector2.ZERO, false, false, false)
	_check(
		game.pilot.position.z > 3.4 and game.pilot.position.y >= -0.05,
		"fall returns to firm terrain"
	)
	_check(
		game.sim.cargo.is_empty() and game.world.props.battery.visible,
		"dropped battery can be recovered"
	)
	_check(game.try_interact(), "recovered battery can still be carried")
	await _walk_to(game, Vector3(0, 0, 3.45))
	_check(game.pilot.is_on_floor(), "jump launched from ground")
	for frame in range(41):
		await get_tree().physics_frame
		game.step(TICK, Vector2.UP, frame == 0, frame == 10, false)
	_check(
		game.pilot.position.z < -2.0 and game.pilot.position.y >= -0.05,
		"jump and boost cross trench"
	)
	await _walk_to(game, Vector3(0, 0, -9.0))
	_check(game.try_interact() and game.sim.online, "first delivery powers base")
	if "--capture" in OS.get_cmdline_user_args():
		await _capture("red")
	await _walk_to(game, Vector3(0, 0, -2.7))
	await _go_and_use(game, Vector3(-17, 0, -2.7))
	await _go_and_use(game, Vector3(-21, 0, 5))
	_check(game.sim.cargo == &"seed_a", "west loop collects capsule")
	await _go_and_use(game, Vector3(-18, 0, -2.7))
	await _go_and_use(game, Vector3(-12, 0, -2.7))
	_check(game.sim.planted == 1, "west capsule reaches farm")
	await _go_and_use(game, Vector3(18, 0, -2.7))
	await _go_and_use(game, Vector3(20, 0, 7))
	_check(game.sim.cargo == &"seed_b", "east loop collects capsule")
	await _go_and_use(game, Vector3(18, 0, -2.7))
	await _go_and_use(game, Vector3(-12, 0, -2.7))
	_check(game.sim.planted == 2, "east capsule reaches farm")
	await _walk_to(game, Vector3(8, 0, -3))
	_check(game.sheltered(), "player enters physical shelter")
	var remaining := 480
	while game.sim.harvested < 2 and not game.sim.finished() and remaining > 0:
		await get_tree().physics_frame
		game.step(TICK, Vector2.ZERO, false, false, false)
		remaining -= 1
	game.step(TICK, Vector2.ZERO, false, false, true)
	_check(game.sim.won, "full field mission wins")
	_check(game.hud._card.visible and not game.hud._result.text.is_empty(), "result card appears")
	if "--capture" in OS.get_cmdline_user_args():
		await _capture("final")


func _go_and_use(game: Node3D, point: Vector3) -> void:
	await _walk_to(game, point)
	game.try_interact()


func _walk_to(game: Node3D, target: Vector3) -> void:
	for frame in range(440):
		var difference: Vector3 = target - game.pilot.position
		var direction := Vector2(difference.x, difference.z)
		if direction.length() < 0.26 or game.sim.finished():
			return
		await get_tree().physics_frame
		game.step(TICK, direction.normalized(), false, false, false)
	_check(false, "unable to walk to " + str(target))


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var output := OS.get_environment("TEMP").path_join("artemis-field-%s.png" % name)
	_check(get_viewport().get_texture().get_image().save_png(output) == OK, "capture " + name)


func _check(ok: bool, description: String) -> void:
	_assertions += 1
	if not ok:
		_failed += 1
		push_error("FIELD: " + description)
