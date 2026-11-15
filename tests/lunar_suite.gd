extends Node

const GAME := preload("res://lunar/lunar.tscn")
const SAFE: Array[bool] = [true, true]
const OUTSIDE: Array[bool] = [false, false]
const AWAY: Array[StringName] = [&"", &""]

var _checks := 0
var _failed := 0
var _cases := 0
var _capture := false


func _ready() -> void:
	_capture = "--lunar-capture" in OS.get_cmdline_user_args()
	_run.call_deferred()


func _run() -> void:
	_cycle()
	_survival()
	_logistics()
	_launch()
	_profile()
	_wallet_adversarial()
	_item_limits()
	await _terrain()
	await _solo()
	await _recovery()
	await _item_controls()
	await _network()
	print("LUNAR SUITE: %d cases, %d assertions, %d failed" % [_cases, _checks, _failed])
	get_tree().quit(int(_failed > 0))


func _mission(base_id: String = "mons_mouton") -> LunarMission:
	var mission := LunarMission.new()
	mission.prepare(base_id, 41)
	mission.connected[1] = true
	mission.finish_tutorial()
	return mission


func _cycle() -> void:
	_cases += 1
	var mission := _mission()
	_check(
		mission.rules.bases.size() == 9 and mission.rules.starting_base == "mons_mouton_plateau",
		"canonical bases"
	)
	for entry: Dictionary in mission.rules.bases.values():
		_check(mission.rules.difficulties.has(entry.difficulty), "canonical difficulty")
	mission.elapsed = 419.5
	mission.tick(0.5, SAFE, AWAY)
	_check(mission.shadow_active(), "night starts at 420 seconds")
	mission.elapsed = 899.5
	mission.tick(0.5, SAFE, AWAY)
	_check(mission.dawn and mission.days == 1 and mission.elapsed == 0.0, "dawn checkpoint")
	_check(is_equal_approx(mission.wallet_rate(true), 41.25), "day 2 payout in medium")
	mission.days = 24
	_check(is_equal_approx(mission.wallet_rate(true), 75.0), "streak cap")
	for id in ["mons_mouton_plateau", "mons_mouton", "haworth"]:
		mission = _mission(id)
		for cycle in range(1, 8):
			mission.days = cycle - 1
			mission._roll_events()
			var prev := mission.events.duplicate(true)
			mission._roll_events()
			_check(mission.events == prev, "deterministic schedule")
			var power := 0
			var alerts := 0
			for event: Array in mission.events:
				_check(event[1] >= 60 and event[1] + event[2] <= 840, "dawn margin")
				if event[0] == "outage":
					_check(event[1] >= 420 and event[2] == 60, "night blackout")
					power += 1
				elif event[0] == "flare":
					_check(event[2] == 8, "false alarm notice length")
				else:
					_check(event[2] == 45, "solar alert duration")
					alerts += 1
				for other: Array in mission.events:
					if event != other:
						_check(
							event[1] + event[2] <= other[1] or other[1] + other[2] <= event[1],
							"events never overlap"
						)
			_check(
				power == int(cycle % int(mission.difficulty.outage_every) == 0), "outage frequency"
			)
			var expected := (
				int(mission.difficulty.alerts)
				if cycle % int(mission.difficulty.alert_every) == 0
				else 0
			)
			_check(alerts == expected, "alert frequency")


func _survival() -> void:
	_cases += 1
	var mission := _mission()
	mission.tick(3.0, OUTSIDE, AWAY)
	_check(is_equal_approx(float(mission.pilots[0].air), 99.0), "medium daytime oxygen")
	mission.elapsed = 420
	mission.tick(2.0, OUTSIDE, AWAY)
	_check(is_equal_approx(float(mission.pilots[0].air), 98.0), "50% more oxygen in cold")
	mission.events = [["outage", 430, 60]]
	mission.elapsed = 430
	mission.pilots[0].air = 50.0
	mission.tick(1.0, SAFE, AWAY)
	_check(is_equal_approx(float(mission.pilots[0].air), 51.0), "outage recovery at half speed")
	mission.auxiliary = true
	mission.tick(1.0, SAFE, AWAY)
	_check(
		is_equal_approx(float(mission.pilots[0].air), 53.0), "auxiliary battery restores normal air"
	)
	mission.pilots[0].hunger = 0.0
	_check(is_equal_approx(mission.speed_factor(0), 0.7), "hunger slows only this pilot")
	_check(mission.use_station(0, &"life") == "Ración consumida", "eat an available ration")
	_check(is_equal_approx(float(mission.pilots[0].hunger), 30.0), "ration adds 30 hunger")
	mission.earth_ok = true
	mission.drill = true
	mission.pilots[0].air = 0.1
	mission.tick(0.5, OUTSIDE, AWAY)
	_check(mission.withdrew and not mission.drill and not mission.earth_ok, "retreat restores dawn")
	mission.pilots[0].air = 0.1
	mission.tick(0.5, OUTSIDE, AWAY)
	_check(
		mission.withdrew and is_equal_approx(float(mission.pilots[0].air), 100.0),
		"checkpoint remains immutable after retreat"
	)


func _logistics() -> void:
	_cases += 1
	var mission := _mission()
	mission.use_station(0, &"ice")
	mission._tick_mining(5.9, [&"ice", &""])
	_check(mission.cargo_kind(0) == &"", "drill has not finished early")
	mission._tick_mining(0.11, [&"ice", &""])
	_check(mission.cargo_kind(0) == &"ice", "one physical crate after six seconds")
	var id: int = mission.pilots[0].cargo
	mission.release(0, Vector3.ZERO, true)
	_check(mission.cargo_kind(1) == &"ice" and not mission.pickup(0, id), "transfer is exclusive")
	mission.use_station(1, &"refinery")
	_check(
		mission.cargo_kind(1) == &"" and mission.water == 6.0, "refinery consumes exactly one crate"
	)
	mission._tick_power(4.99)
	_check(mission.water == 6.0, "refinement takes five seconds")
	mission._tick_power(0.011)
	_check(mission.water == 7.0, "refinement yields exactly one water")
	mission.ore = 4
	mission.use_station(0, &"drill")
	mission.use_station(1, &"drill")
	_check(mission.ore == 2 and mission.installing.size() == 1, "duplicate upgrade does not charge")
	mission.use_station(1, &"battery")
	mission._tick_power(5.0)
	_check(
		mission.drill and mission.auxiliary and mission.drill_seconds() == 4.0,
		"two upgrades coexist"
	)
	_check(mission.battery_capacity() == 16.0, "capacity increases to sixteen")
	mission.food = 0
	mission.use_station(0, &"crop")
	mission._tick_power(15.0)
	_check(mission.food == 2 and mission.water == 6.0, "crop grows two rations per irrigation")


func _launch() -> void:
	_cases += 1
	var mission := _mission("nobile_rim_2")
	mission.elapsed = 430
	mission.use_station(0, &"radio")
	_check(mission.radio_left == 0.0, "radio cut blocks send in Nobile 2")
	mission.elapsed = 418
	mission.use_station(0, &"radio")
	mission.tick(2.56, SAFE, AWAY)
	_check(mission.earth_ok, "reply takes 2.56 seconds even across a later cut")
	mission.fuel_loaded = 3
	mission.food_loaded = 2
	mission.use_station(0, &"pad")
	mission.use_station(1, &"pad")
	mission.tick(0.01, SAFE, AWAY)
	_check(mission.countdown == 30.0 and mission.radio_cut(), "cut does not block committed flight")
	mission.events = [["sep", mission.elapsed + 0.01, 45]]
	mission.tick(0.02, SAFE, AWAY)
	_check(
		mission.countdown == 0.0 and mission.earth_ok and mission.fuel_loaded == 3,
		"solar event cancels only the countdown"
	)
	_check(mission.crew_seated() == 0, "solar alert requires boarding again")
	mission.events.clear()
	mission.use_station(0, &"pad")
	mission.use_station(1, &"pad")
	mission.tick(0.01, SAFE, AWAY)
	mission.set_guest(false, Vector3.ZERO)
	_check(mission.countdown == 0.0 and mission.crew_seated() == 1, "disconnect cancels launch")
	mission.set_guest(true, Vector3.ZERO)
	mission.use_station(1, &"pad")
	mission.tick(0.01, SAFE, AWAY)
	mission.store_checkpoint()
	mission.tick(30.0, SAFE, AWAY)
	_check(mission.flight_stage().x == 0 and not mission.returned, "ascent is not Earth arrival")
	var elapsed := mission.elapsed
	mission.tick(4.0, SAFE, AWAY)
	_check(mission.flight_stage().x == 1 and mission.elapsed == elapsed, "orbital docking")
	mission.tick(5.0, SAFE, AWAY)
	_check(mission.flight_stage().x == 2, "trans-Earth flight")
	mission.tick(4.0, SAFE, AWAY)
	_check(mission.flight_stage().x == 3, "command module separates for Earth entry")
	mission.tick(4.0, SAFE, AWAY)
	mission.tick(1.0, SAFE, AWAY)
	_check(
		mission.returned and mission.phase == &"active" and mission.elapsed > elapsed,
		"mission allows free play"
	)
	_check(
		(
			mission.checkpoint.returned
			and mission.checkpoint.phase == &"active"
			and mission.checkpoint.countdown == 0.0
			and not mission.checkpoint.pilots[0].seated
		),
		"return clears countdown and seats from the dawn checkpoint"
	)
	var legacy := mission.checkpoint.duplicate(true)
	legacy.phase = &"countdown"
	legacy.countdown = 12.0
	legacy.pilots[0].seated = true
	mission.restore(legacy)
	_check(mission.phase == &"active" and mission.crew_seated() == 0, "old return saves recover")


func _profile() -> void:
	_cases += 1
	var mission := _mission()
	var path := _temp_profile("persistence")
	var profile := LunarProfile.new(mission.rules, path)
	_check(not profile.buy("slater_plain", false), "coins required")
	profile.credit("dawn-test", 500 * LunarProfile.SCALE)
	profile.credit("dawn-test", 500 * LunarProfile.SCALE)
	_check(
		profile.buy("slater_plain", false) and profile.buy("engineer", true), "buy base and role"
	)
	profile.pay_mission("slater_plain", 1, "")
	profile.pay_mission("slater_plain", 1, "")
	_check(profile.save(), "atomic local write")
	profile = LunarProfile.new(mission.rules, path)
	_check(
		profile.open_base("slater_plain") and profile.data.balance == 300 * LunarProfile.SCALE,
		"persistent balance and one bonus"
	)
	DirAccess.remove_absolute(path)


func _wallet_adversarial() -> void:
	_cases += 1
	var rules := _mission().rules
	var path := _temp_profile("wallet-errors")
	var profile := LunarProfile.new(rules, path)
	var guest_id := "0123456789abcdef0123456789abcdef"
	var base := "mons_mouton_plateau"
	_check(not profile.credit("negative", -1), "negative reward rejected")
	_check(not profile.credit("", 100), "empty receipt rejected")
	_check(
		not profile.credit("overflow", LunarProfile.MAX_BALANCE + 1), "oversized reward rejected"
	)
	profile.pay_day(base, 33, 1, NAN, {})
	profile.pay_day(base, 33, 1, INF, {})
	profile.pay_day("invalid", 33, 1, 25.0, {})
	profile.pay_day(base, 33, 0, 25.0, {})
	_check(profile.data.balance == 0, "invalid dawn input never credits")
	profile.pay_day(base, 33, 1, 25.0, {guest_id: 12.5})
	profile.pay_day(base, 33, 1, 25.0, {guest_id: 18.75})
	var receipt := "%s/%s/33/1" % [profile.data.id, base]
	_check(profile.data.balance == 250000, "same dawn credited exactly once")
	_check(profile.data.guest_awards[guest_id][receipt] == 125000, "guest award stays immutable")
	_check(profile.valid_guest_award(receipt, 125000), "valid guest award")
	_check(not profile.valid_guest_award(receipt, 99900000), "guest award bound by base")
	_check(not profile.valid_guest_award(receipt, 125000.0), "wire award must be integer")
	_check(
		not profile.valid_guest_award("%s/%s/33/01" % [profile.data.id, base], 100),
		"alias rejected"
	)
	_check(
		not profile.valid_guest_award("lunar/mission/invalid", 1500000), "unknown mission rejected"
	)
	profile.pay_day(base, 33, 2, 37.5, {guest_id: 37.5000000001})
	var capped_share := "%s/%s/33/2" % [profile.data.id, base]
	_check(
		profile.data.guest_awards[guest_id][capped_share] == 375000, "round-off at guest cap paid"
	)
	_check(profile.credit("seed", 500 * LunarProfile.SCALE) and profile.save(), "wallet saved")
	var stale := LunarProfile.new(rules, path)
	var before := int(profile.data.balance)
	profile.path = path + "/missing/profile"
	_check(not profile.buy("slater_plain", false), "failed write rejects purchase")
	_check(
		not profile.open_base("slater_plain") and profile.data.balance == before, "buy rolled back"
	)
	profile.path = path
	_check(profile.buy("slater_plain", false), "purchase retry succeeds")
	_check(not profile.buy("slater_plain", false), "double purchase rejected")
	_check(
		not stale.buy("engineer", true) and stale.save_error == ERR_BUSY, "stale writer rejected"
	)
	var reloaded := LunarProfile.new(rules, path)
	_check(
		(
			reloaded.data.balance == before - 100 * LunarProfile.SCALE
			and reloaded.open_base("slater_plain")
		),
		"disk keeps exact debit and unlock"
	)
	var staged := FileAccess.open(path + ".interrupted.tmp", FileAccess.WRITE)
	staged.store_var({"version": 1, "balance": -1}, false)
	staged.close()
	reloaded = LunarProfile.new(rules, path)
	_check(reloaded.data.balance == profile.data.balance, "interrupted staging file ignored")
	_check(reloaded.credit("cap", LunarProfile.MAX_BALANCE), "valid large award reaches the cap")
	_check(reloaded.credit("at-cap", 1), "receipt consumed at capacity")
	_check(reloaded.data.balance == LunarProfile.MAX_BALANCE, "never exceeds capacity")
	_check(not reloaded.credit("at-cap", 1), "capped awards cannot be replayed")
	_check(reloaded.save(), "cap survives persistence")
	var corrupt_path := _temp_profile("corrupt-wallet")
	var file := FileAccess.open(corrupt_path, FileAccess.WRITE)
	file.store_var({"version": 1, "balance": -10}, false)
	file.close()
	var corrupt := LunarProfile.new(rules, corrupt_path)
	_check(
		corrupt.error == ERR_FILE_CORRUPT and not corrupt.save(), "corrupt wallet stays protected"
	)
	for temporary in [path, path + ".interrupted.tmp", corrupt_path]:
		DirAccess.remove_absolute(temporary)


func _terrain() -> void:
	_cases += 1
	var player := _endpoint("Alignment")
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.net = &"lobby"
	player._surface_camera()
	var stations := CrestWorld.campaign_stations.duplicate()
	stations.erase(&"supply")
	_check(not stations.has(&"ice") and not stations.has(&"ore"), "ice and ore left the base")
	var coordinates: Array[Vector3] = [CrestWorld.SPAWNS[0], CrestWorld.SPAWNS[1]]
	for key: StringName in stations:
		coordinates.append(stations[key])
		for spawn: Vector3 in CrestWorld.SPAWNS:
			var points: PackedVector2Array = player._routes.path(spawn, stations[key])
			_check(not points.is_empty(), "route exists from spawn to %s" % key)
			if endpoints_close(points, stations[key]):
				_check(true, "route reaches the station")
			else:
				_check(
					false,
					(
						"%s goal redirects to %s"
						% [key, points[-1] if not points.is_empty() else "nowhere"]
					)
				)
		var projected: Vector2 = player.camera.unproject_position(stations[key])
		_check(
			Rect2(Vector2(0.017, 0.197), Vector2(0.966, 0.672)).has_point(
				projected / Vector2(player.get_viewport().size)
			),
			"%s fits the gameplay camera" % key
		)
	var direct: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	for point in coordinates:
		var ray := PhysicsRayQueryParameters3D.create(
			point + Vector3.UP * 0.2, point - Vector3.UP * 0.2, 1
		)
		var hit := direct.intersect_ray(ray)
		_check(not hit.is_empty() and absf(hit.position.y) < 0.002, "station and spawn floor datum")
	var longest := 0.0
	for point in coordinates:
		var path: PackedVector2Array = player._routes.path(point, CrestWorld.STATIONS[&"life"])
		var length := 0.0
		for index in range(1, path.size()):
			length += path[index - 1].distance_to(path[index])
		longest = maxf(longest, length)
	_check(
		longest / FieldPilot.WALK_SPEED < 9.0, "longest refuge route fits inside a 20 second alert"
	)
	for base_id: String in player.sim.rules.bases:
		var profile: Dictionary = player.sim.rules.bases[base_id]
		player.world.set_base(profile.soil, StringName(base_id))
		player.sky.configure(base_id, profile.horizon)
		_check(
			not player.world.has_node("CrateresLaterales"),
			"%s leaves the craters to the open world" % base_id
		)
		player.sky.update_sky(2.0, true)
		_check(
			player.sky.earth_level == float(profile.horizon.earth == "visible"),
			"%s planet obeys its horizon profile" % base_id
		)

	player._start_solo("mons_mouton_plateau")
	player.sim.finish_tutorial()
	var settings: Dictionary = player.sim.rules.open_world
	var quarry: Vector3 = ChunkGenerator.starter_deposits(player.sim.world_seed, settings)[0].point
	player._set_positions([quarry, Vector3.ZERO])
	player._set_destination(0, CrestWorld.STATIONS[&"life"])
	await _until(func() -> bool: return player.streamer.is_ready_at(quarry))
	var frames := 0
	var longest_step := 0.0
	while not player.world.sheltered(player.pilots[0].position) and frames < 1200:
		frames += 1
		var before: Vector3 = player.pilots[0].position
		await get_tree().physics_frame
		var step: Vector3 = (player.pilots[0].position - before) * Vector3(1, 0, 1)
		longest_step = maxf(longest_step, step.length())
	_check(
		player.world.sheltered(player.pilots[0].position) and longest_step < 0.5,
		"pilot follows a real route from the starter ice deposit into cover"
	)
	print("TERRAIN: tested quarry-to-cover motion %.2f simulated seconds" % (frames / 60.0))
	DirAccess.remove_absolute(player.profile_path)
	print("TERRAIN: %d station anchors, longest refuge path %.2f m" % [stations.size(), longest])
	player.get_parent().queue_free()


func endpoints_close(points: PackedVector2Array, station: Vector3) -> bool:
	return not points.is_empty() and points[-1].distance_to(Vector2(station.x, station.z)) <= 0.77


func _solo() -> void:
	_cases += 1
	var player := _endpoint("Solo")
	var existing_peer: MultiplayerPeer = player.multiplayer.multiplayer_peer
	var base_id := "mons_mouton_plateau"
	var legacy_mission := _mission(base_id)
	player.profile.data.bases[base_id] = {
		"run": 12345,
		"active": legacy_mission.state(),
		"checkpoint": legacy_mission.checkpoint,
		"positions": [Vector3.ZERO, Vector3.ZERO],
		"checkpoint_positions": [Vector3.ZERO, Vector3.ZERO]
	}
	player.profile.data.erase("solo_bases")
	player.profile.data.erase("recent_mode")
	player.profile.save()
	player.profile = LunarProfile.new(player.sim.rules, player.profile_path)
	_check(
		player.profile.data.recent_mode == "host",
		"previous profiles default to online continuation"
	)
	_check(player.profile.saved_bases(true).is_empty(), "previous profiles gain empty solo slots")
	_check(player.net == &"title", "startup shows the title")
	var opening: LunarOpening = player.opening
	_check(opening._film.stream != null and not opening.landing, "title starts the flight clip")
	opening._film.finished.emit()
	_check(opening.landing and not opening._film.loop, "title plays the landing once")
	opening._film.finished.emit()
	_check(player.net == &"lobby" and player.opening == null, "intro ends in the mode menu")
	player.ui.selected.emit("title_replay", "")
	_check(player.net == &"title" and not player.opening.landing, "replay restarts the flight")
	player.opening._skip.pressed.emit()
	_check(player.net == &"lobby" and player.opening == null, "skip opens the mode menu")
	if _capture:
		for frame in range(8):
			await get_tree().process_frame
		_capture_image(player, "artemis-portada.png")
	_press_menu_button(player, "Jugar solo · sin conexión")
	if _capture:
		for frame in range(8):
			await get_tree().process_frame
		_capture_image(player, "artemis-bases.png")
	_press_menu_button(player, "Mons Mouton Plateau · Fácil")
	_check(player._loading and not player.ui.play.visible, "base selection displays loading")
	if _capture:
		for frame in range(8):
			await get_tree().process_frame
		_capture_image(player, "artemis-carga.png")
	await _until(func() -> bool: return not player._loading)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(player.net == &"solo" and player.ui.play.visible, "main menu opens solo directly")
	_check(player.multiplayer.multiplayer_peer == existing_peer, "no network peer opened")
	_check(player.pilots[0].visible and not player.pilots[1].visible, "only one astronaut in solo")
	# Los puntos de salida del plano 40x22 quedan a unos 3.9 m del puesto de práctica.
	var desk: Vector3 = CrestWorld.STATIONS[&"training"]
	player._set_positions([desk, Vector3.ZERO])
	await get_tree().physics_frame
	player.ui.action_button.pressed.emit()
	_check(player.sim.cargo_kind(0) == &"sample", "solo tutorial picks up a sample")
	player.ui.release_button.pressed.emit()
	_check(
		player.sim.phase == &"active" and player.sim.crates.is_empty(),
		"solo tutorial deposits and completes"
	)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check("A bordo 0/1" in player.ui.next_step.text, "solo HUD shows one required seat")
	if _capture:
		_capture_image(player, "artemis-modo-individual.png")

	var elapsed: float = player.sim.elapsed
	player.ui.selected.emit("menu", "")
	for index in range(10):
		await get_tree().physics_frame
	_check(player.sim.elapsed == elapsed, "solo menu pauses the simulation")
	_press_menu_button(player, "Volver a la partida")
	player.sim.elapsed = 899.99
	for index in range(5):
		await get_tree().physics_frame
	_check(
		player.profile.data.balance == 25 * LunarProfile.SCALE,
		"solo gets 100 percent of daily coins"
	)

	var pad: Vector3 = CrestWorld.STATIONS[&"pad"]
	player._set_positions([pad, Vector3.ZERO])
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.ui.action_button.pressed.emit()
	_check(not player.sim.pilots[0].seated, "solo still requires cargo and radio")
	for kind in [&"fuel", &"fuel", &"fuel", &"food", &"food"]:
		player.sim._create_cargo(0, kind)
		player.ui.release_button.pressed.emit()
	_check(
		player.sim.fuel_loaded == 3 and player.sim.food_loaded == 2,
		"solo loads normal cargo targets"
	)
	var radio: Vector3 = CrestWorld.STATIONS[&"radio"]
	player._set_positions([radio, Vector3.ZERO])
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.ui.action_button.pressed.emit()
	for index in range(167):
		await get_tree().physics_frame
	_check(player.sim.earth_ok, "solo receives radio confirmation")
	player._set_positions([pad, Vector3.ZERO])
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.ui.action_button.pressed.emit()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(
		player.sim.phase == &"countdown" and player.sim.crew_seated() == 1,
		"one seat starts launch countdown"
	)
	player.sim.countdown = 0.01
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(
		player.sim.phase == &"flight" and player.world.descent_stage.visible,
		"the descent stage stays parked"
	)
	player.sim.launch_fx = 10.5
	for index in range(4):
		await get_tree().process_frame
	if _capture:
		_capture_image(player, "artemis-acoplamiento.png")
	player.sim.launch_fx = 0.01
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(
		player.sim.returned and player.profile.data.balance == 175 * LunarProfile.SCALE,
		"solo completes the mission and earns its bonus"
	)

	elapsed = player.sim.elapsed
	player.ui.selected.emit("menu", "")
	_press_menu_button(player, "Guardar y salir")
	player.profile = LunarProfile.new(player.sim.rules, player.profile_path)
	player.ui.lobby(player.profile, "")
	_check(player.profile.data.bases[base_id].run == 12345, "coop slot survives solo writes")
	_press_menu_button(player, "Continuar misión")
	await _until(func() -> bool: return not player._loading)
	_check(
		player.sim.returned and absf(player.sim.elapsed - elapsed) < 0.04,
		"continue restores exact solo state"
	)
	player._leave()
	_press_menu_button(player, "Jugar solo · sin conexión")
	_press_menu_button(player, "Reiniciar Mons Mouton Plateau…")
	_press_menu_button(player, "Reiniciar base")
	_check(
		(
			not player.profile.saved_bases(true).has(base_id)
			and player.profile.saved_bases(false).has(base_id)
		),
		"solo reset only removes the solo slot"
	)
	_check(
		player.profile.data.balance == 175 * LunarProfile.SCALE, "reset preserves the shared wallet"
	)
	DirAccess.remove_absolute(player.profile_path)
	player.get_parent().queue_free()


func _recovery() -> void:
	_cases += 1
	var player := _endpoint("Recovery")
	player._start_solo("mons_mouton_plateau")
	player.sim.finish_tutorial()
	player.sim.water = 0.0
	player.sim.pilots[0].air = 0.001
	player.sim.store_checkpoint()
	var outside := CrestWorld.STATIONS[&"training"]
	player.positions_at_dawn = [outside, Vector3.ZERO]
	player._set_positions([outside, Vector3.ZERO])
	for frame in range(4):
		await get_tree().physics_frame
	_check(player.world.sheltered(player.pilots[0].position), "dry checkpoint rescues to shelter")
	_check(player.sim.pilots[0].air >= 30.0, "dry checkpoint leaves usable emergency air")
	_check(player.sim.water == 0.0 and player.profile.data.balance == 0, "rescue preserves economy")
	_check(player.sim.phase == &"active", "solo can continue after rescue")
	player.sim.water = 0.000001
	player.sim.pilots[0].air = 0.001
	player.sim.store_checkpoint()
	player.positions_at_dawn = [CrestWorld.STATIONS[&"life"], Vector3.ZERO]
	player._set_positions([outside, Vector3.ZERO])
	for frame in range(4):
		await get_tree().physics_frame
	_check(player.sim.pilots[0].air >= 30.0, "trace water does not suppress the emergency reserve")
	DirAccess.remove_absolute(player.profile_path)
	player.get_parent().queue_free()
	await get_tree().process_frame


func _item_controls() -> void:
	_cases += 1
	var game := _endpoint("ItemControls")
	game._start_solo("mons_mouton_plateau")
	game.sim.finish_tutorial()
	_check(
		not CrestWorld.campaign_stations.has(&"solar"),
		"unfinished upgrade is outside interaction map"
	)
	var point := Vector3(11, 1.7, 1)
	game._set_positions([point, Vector3.ZERO])
	await _until(func() -> bool: return game.streamer.is_ready_at(point))
	game.sim._create_cargo(0, &"food")
	await get_tree().physics_frame
	game.ui.release_button.pressed.emit()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var id: int = game.sim.crates.keys()[0]
	var drop: Vector3 = game.sim.crates[id].point
	_check(drop.y < 0.25 and game.sim.crates[id].owner == -1, "airborne release settles on support")
	game._set_positions([drop + Vector3(3, 0.1, 0), Vector3.ZERO])
	game.ui.action_button.pressed.emit()
	_check(game.sim.cargo_kind(0) == &"", "out-of-reach input cannot pick up a loose crate")
	game._set_positions([drop + Vector3.UP * 0.02, Vector3.ZERO])
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(
		game.ui._zone_panel.visible and game.ui.action_button.text == "Recoger ración",
		"loose food has context away from stations"
	)
	_check(not game.ui.release_button.visible, "empty hands hide the release action")
	game.ui.action_button.pressed.emit()
	game.ui.action_button.pressed.emit()
	_check(
		game.sim.pilots[0].cargo == id and game.sim.crates.size() == 1,
		"double pickup keeps one owner and one crate"
	)
	game.sim._consume_cargo(0)

	var refine: Vector3 = CrestWorld.STATIONS[&"refinery"]
	game._set_positions([refine, Vector3.ZERO])
	game.sim._create_cargo(0, &"ice")
	game.ui.release_button.pressed.emit()
	game.ui.release_button.pressed.emit()
	await get_tree().physics_frame
	await get_tree().physics_frame
	if game.sim.refining.is_empty():
		_check(false, "refinery begins with one job")
	else:
		var left: float = game.sim.refining[0]
		_check(
			game.ui.action_button.disabled and "0:05" in game.ui._zone_detail.text,
			"timer reads the actual refinery job"
		)
		_check(game.world._water_machine_empty.visible, "working refinery shows empty model")
		game.ui.selected.emit("menu", "")
		for frame in range(5):
			await get_tree().physics_frame
		game.ui.action_button.pressed.emit()
		_check(game.sim.refining[0] == left, "pause freezes processing")
		_press_menu_button(game, "Guardar y salir")
		game.profile = LunarProfile.new(game.sim.rules, game.profile_path)
		game._start_solo("mons_mouton_plateau")
		_check(game.sim.refining[0] == left, "resume preserves processing time")
		var before: float = game.sim.water
		await _until(func() -> bool: return game.sim.refining.is_empty())
		_check(
			game.sim.water > before + 0.8 and game.sim.crates.is_empty(),
			"refined water credited once"
		)
		await get_tree().physics_frame
		_check(game.world._water_machine_full.visible, "completed refinery shows loaded model")
		_check(game.world._water_tank_full.visible, "water tank fills with the refined water")
	DirAccess.remove_absolute(game.profile_path)
	game.get_parent().queue_free()
	await get_tree().process_frame


func _item_limits() -> void:
	_cases += 1
	var sim := _mission()
	for part in range(3):
		sim._create_cargo(0, &"fuel")
		sim.release(0, Vector3(part, 0, 0), false)
	var water := sim.water
	sim.use_station(0, &"fuel")
	_check(
		sim.fuel_quota_met() and sim.jobs[&"fuel"] == 0.0 and sim.water == water,
		"loose lots count toward fuel quota"
	)
	for part in range(sim.crates.size(), LunarMission.CARGO_LIMIT):
		sim._create_cargo(0, &"ore")
		sim.release(0, Vector3(part, 0, 0), false)
	sim.food = 1
	sim.use_station(0, &"crop")
	_check(sim.food == 1 and sim.cargo_kind(0) == &"", "full cargo preserves a ready ration")
	var crop := LunarItemContext.at(sim, 0, &"crop", &"")
	_check(crop[2] and crop[0] == "Recoger ración", "ready stock reports blocked collection")
	var key := LunarMission.deposit_key(Vector2i.ZERO, 77)
	sim.register_deposit(key, &"ice", 2, true)
	sim.crates.clear()
	sim.use_station(0, key)
	sim._tick_mining(sim.drill_seconds(), [key, &""])
	_check(sim.deposit_left(key) == 1, "mine removes one charge")
	sim.register_deposit(key, &"ice", 2, true)
	_check(sim.deposit_left(key) == 1, "streaming cannot refill a partially used deposit")
	sim.release(0, Vector3.ZERO, false)
	sim.use_station(0, key)
	sim._tick_mining(sim.drill_seconds(), [key, &""])
	sim.release(0, Vector3.ZERO, false)
	var empty := LunarItemContext.at(sim, 0, key, &"")
	_check(
		sim.deposit_left(key) == 0 and "4 amaneceres" in empty[1] and empty[2],
		"depleted deposit shows true refill"
	)
	sim.events = [["outage", 0, 60]]
	sim.jobs[&"fuel"] = 3.2
	var paused := LunarItemContext.at(sim, 0, &"fuel", &"")
	_check(
		"En pausa" in paused[1] and "0:04" in paused[1], "outage reports pause and remaining time"
	)


func _press_menu_button(player: Node, caption: String) -> void:
	for item: Control in player.ui._list.get_children():
		if item is Button and item.text == caption:
			item.pressed.emit()
			return
	_check(false, "menu button %s" % caption)


func _network() -> void:
	_cases += 1
	var host := _endpoint("Host")
	var guest := _endpoint("Guest")
	var port := 46200 + randi_range(0, 150)
	host.host("mons_mouton_plateau", port)
	guest.join("127.0.0.1", port)
	for index in range(160):
		if host.guest_peer != 0 and guest.net == &"guest":
			break
		OS.delay_msec(2)
		await get_tree().physics_frame
	_check(
		host.guest_peer != 0 and guest.net == &"guest", "ENet connection through two peer instances"
	)
	if guest.net != &"guest":
		return
	for index in range(15):
		await get_tree().physics_frame
	await _until(func() -> bool: return host.streamer.is_ready_at(host.pilots[0].position))
	var frame_position: Vector3 = host.pilots[0].position
	_touch_joystick(host)
	for index in range(33):
		await get_tree().physics_frame
	host.ui.joystick.clear()
	_check(frame_position.distance_to(host.pilots[0].position) > 0.9, "joystick drives host")
	var desk: Vector3 = CrestWorld.STATIONS[&"training"]
	host._set_positions([desk + Vector3(-0.68, 0.1, 0), desk + Vector3(0.68, 0.1, 0)])
	await get_tree().physics_frame
	await get_tree().physics_frame
	host.ui.selected.emit("action", "")
	host.ui.selected.emit("release", "")
	guest.ui.selected.emit("release", "")
	for index in range(55):
		if host.sim.tutorial_step == 3:
			break
		OS.delay_msec(2)
		await get_tree().physics_frame
	_check(host.sim.tutorial_step == 3, "guest deposits the same sample over network")
	host.ui.selected.emit("action", "")
	await get_tree().physics_frame
	_check(host.sim.phase == &"active", "two-player tutorial starts the cycle")
	host._set_destination(0, Vector3(-10.5, 0, -0.3))
	for index in range(230):
		await get_tree().physics_frame
	_check(
		host.pilots[0].position.distance_to(Vector3(-10.5, 0, -0.3)) < 1.3,
		"tap destination routes around obstacles"
	)
	if _capture:
		_capture_image(host)
	var host_path: String = host.profile.path
	var guest_path: String = guest.profile.path
	host.profile.path = host_path + "/missing/profile"
	guest.profile.path = guest_path + "/missing/profile"
	host.sim.elapsed = 899.98
	host._coins_by_guest[host.guest_id] = 18.75 * 899.98 / 900.0
	for index in range(6):
		await get_tree().physics_frame
	_check(
		host.profile.data.balance == 0 and not host._pending_reward.is_empty(),
		"failed dawn leaves neither wallet nor checkpoint committed"
	)
	_check(host.profile.data.guest_awards.is_empty(), "failed dawn cannot release guest award")
	_check(host.ui._wallet_balance.text == "0.00 monedas", "uncommitted reward is hidden from HUD")
	host.profile.path = host_path
	_check(host._commit_reward(), "dawn saved exactly once on retry")
	_check(
		host.ui._wallet_balance.text == host.profile.balance_text() + " monedas", "host HUD updated"
	)
	_check(host.profile.data.balance == 187500, "75 percent day reward for host")
	for index in range(6):
		OS.delay_msec(2)
		await get_tree().physics_frame
	_check(guest.profile.data.balance == 0, "failed guest write rolls back receipt and credit")
	_check(host.profile.data.guest_awards.has(host.guest_id), "unconfirmed award kept by host")
	guest.profile.path = guest_path
	host._send_awards()
	for index in range(40):
		if guest.profile.data.balance == 187500:
			break
		OS.delay_msec(2)
		await get_tree().physics_frame
	_check(guest.profile.data.balance == 187500, "guest receives the same 75 percent at dawn")
	_check(
		guest.ui._wallet_balance.text == guest.profile.balance_text() + " monedas",
		"guest HUD updated"
	)
	var reloaded := LunarProfile.new(guest.sim.rules, guest.profile_path)
	_check(reloaded.data.balance == 187500, "guest persisted before acknowledgment")
	for index in range(40):
		if not host.profile.data.guest_awards.has(host.guest_id):
			break
		OS.delay_msec(2)
		await get_tree().physics_frame
	_check(not host.profile.data.guest_awards.has(host.guest_id), "confirmed award dequeued")
	var duplicate: String = (
		"%s/%s/%d/%d" % [host.profile.data.id, host.sim.base_id, host.saved_run, host.sim.days]
	)
	guest._award({duplicate: 187500, "lunar/mission/boo": 1, 42: 500})
	_check(guest.profile.data.balance == 187500, "wire replay and malformed awards ignored")
	guest._leave()
	for index in range(100):
		if host.guest_peer == 0:
			break
		OS.delay_msec(2)
		await get_tree().physics_frame
	_check(host.guest_peer == 0 and host.play_started, "host continues after disconnect")
	guest.join("127.0.0.1", port)
	for index in range(100):
		if guest.net == &"guest":
			break
		OS.delay_msec(2)
		await get_tree().physics_frame
	_check(guest.net == &"guest", "guest reconnects to the same base")
	for index in range(12):
		await get_tree().physics_frame
	_check(guest.profile.data.balance == 187500, "receipt replay cannot duplicate guest coins")
	var many := {}
	var count := LunarProfile.AWARD_BATCH * 2 + 1
	for day in range(1, count + 1):
		var id := "%s/%s/99999/%d" % [host.profile.data.id, host.sim.base_id, day]
		many[id] = 100
	host.profile.data.guest_awards[host.guest_id] = many
	_check(host.profile.save(), "backlog persisted")
	host._send_awards()
	for index in range(90):
		if not host.profile.data.guest_awards.has(host.guest_id):
			break
		OS.delay_msec(2)
		await get_tree().physics_frame
	var final_balance := 187500 + count * 100
	_check(guest.profile.data.balance == final_balance, "backlog paid in bounded batches")
	_check(not host.profile.data.guest_awards.has(host.guest_id), "every batch acknowledged")
	var when: float = host.sim.elapsed
	host._leave()
	var save: Dictionary = host.profile.data.bases.mons_mouton_plateau
	_check(is_equal_approx(float(save.active.elapsed), when), "save and exit preserves exact cycle")
	_check(float(save.checkpoint.elapsed) < 0.1, "last dawn survives exact save")
	for index in range(100):
		if guest.net == &"lobby":
			break
		OS.delay_msec(2)
		await get_tree().physics_frame
	_check(
		guest.net == &"lobby" and guest.profile.data.balance == final_balance,
		"guest keeps confirmed coins after host exit"
	)
	DirAccess.remove_absolute(host.profile_path)
	DirAccess.remove_absolute(guest.profile_path)
	host.get_parent().queue_free()
	guest.get_parent().queue_free()
	await get_tree().process_frame


## La carga del terreno es asíncrona: espera con reloj real (20 s como máximo).
func _until(done: Callable) -> void:
	var deadline := Time.get_ticks_msec() + 20000
	while not done.call() and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame


func _endpoint(label: String) -> Node:
	var scope := SubViewport.new()
	scope.name = label
	scope.size = (
		Vector2i(1280, 720)
		if "--capture-720" in OS.get_cmdline_user_args()
		else Vector2i(1152, 648)
	)
	scope.own_world_3d = true
	scope.render_target_update_mode = (
		SubViewport.UPDATE_ALWAYS if _capture else SubViewport.UPDATE_DISABLED
	)
	add_child(scope)
	get_tree().set_multiplayer(SceneMultiplayer.new(), scope.get_path())
	var endpoint := GAME.instantiate()
	endpoint.profile_path = _temp_profile(label)
	scope.add_child(endpoint)
	return endpoint


func _capture_image(host: Node, filename: String = "mons-mouton-crateres.png") -> void:
	var image := host.get_viewport().get_texture().get_image()
	if image != null and not image.is_empty():
		image.save_png("user://" + filename)


func _touch_joystick(host: Node) -> void:
	var joystick: Control = host.ui.joystick
	var event := InputEventScreenTouch.new()
	event.pressed = true
	event.position = joystick.get_global_rect().get_center() + Vector2(0, -30)
	joystick._input(event)


func _temp_profile(tag: String) -> String:
	return "user://artemis-test-%s-%d.dat" % [tag, randi()]


func _check(ok: bool, reason: String) -> void:
	_checks += 1
	if not ok:
		_failed += 1
		push_error(reason)
