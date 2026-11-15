extends Node

const REGISTRY := "res://context_core/state_registry.json"
const GAME := preload("res://lunar/lunar.tscn")
const SAFE: Array[bool] = [true, true]
const AWAY: Array[StringName] = [&"", &""]

var _checks := 0
var _failed := 0
var _cases := 0
var _max_step := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_generation()
	_regions()
	_ice_and_ids()
	_base_exits()
	_deposits()
	await _streaming()
	await _streaming_limits()
	await _campaign()
	await _camera()
	await _jump()
	await _open_routes()
	await _enclosure()
	print("OPEN SUITE: %d cases, %d assertions, %d failed" % [_cases, _checks, _failed])
	get_tree().quit(int(_failed > 0))


func _rect(values: Array) -> Rect2:
	return Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))


func _rules() -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REGISTRY))
	return data.campaign_2026


func _generation() -> void:
	_cases += 1
	var rules: Dictionary = _rules()
	var s: Dictionary = rules.open_world
	var world := ChunkGenerator.world_seed("mons_mouton_plateau", 12345)
	var region: Dictionary = s.regions.mons_mouton_plateau
	var a := ChunkGenerator.generate(world, region, s, Vector2i(5, -3))
	var b := ChunkGenerator.generate(world, region, s, Vector2i(5, -3))
	_check(a.heights == b.heights and a.walkable == b.walkable, "same seed same terrain")
	_check(str(a.deposits) == str(b.deposits), "same seed same deposits")
	var east := ChunkGenerator.generate(world, region, s, Vector2i(6, -3))
	for row in range(17):
		_check(
			is_equal_approx(a.heights[row * 17 + 16], east.heights[row * 17]), "seam row %d" % row
		)
	var home := ChunkGenerator.generate(world, region, s, Vector2i(0, 0))
	_check(absf(home.height_at(Vector2(3, 3))) < 0.001, "base deck flat at Y=0")
	var exclusion := _rect(s.base_exclusion_rect)
	var border: Array[Vector2i] = []
	for cx in range(-2, 2):
		border.append_array([Vector2i(cx, -2), Vector2i(cx, 1)])
	for cz in range(-1, 1):
		border.append_array([Vector2i(-2, cz), Vector2i(1, cz)])
	var inspected := 0
	for run in range(6):
		for base_id: String in rules.bases:
			var w := ChunkGenerator.world_seed(base_id, run)
			for coord in border:
				var c := ChunkGenerator.generate(w, s.regions[base_id], s, coord)
				for d in c.deposits:
					inspected += 1
					var spot := Vector2(d.point.x, d.point.z)
					_check(not exclusion.has_point(spot), "no deposit in base")
	_check(inspected > 0, "border chunks were inspected with deposits")
	for base_id: String in rules.bases:
		var w := ChunkGenerator.world_seed(base_id, 7)
		var starters := ChunkGenerator.starter_deposits(w, s)
		_check(starters.size() == 2, "%s two starters" % base_id)
		for d in starters:
			var spot := Vector2(d.point.x, d.point.z)
			var r := spot.length()
			_check(r >= 25.0 and r <= 40.0, "%s starter within 25-40 m" % base_id)
			_check(not exclusion.has_point(spot), "%s starter outside base" % base_id)
	var z_plus := ChunkGenerator.generate(world, region, s, Vector2i(5, -2))
	var z_minus := ChunkGenerator.generate(world, region, s, Vector2i(5, -4))
	for col in range(17):
		_check(is_equal_approx(a.heights[16 * 17 + col], z_plus.heights[col]), "z seam +%d" % col)
		_check(is_equal_approx(z_minus.heights[16 * 17 + col], a.heights[col]), "z seam -%d" % col)
	var rich := Vector2i.ZERO
	for cx in range(-8, 9):
		if not ChunkGenerator.generate(world, region, s, Vector2i(cx, 6)).deposits.is_empty():
			rich = Vector2i(cx, 6)
			break
	var r1 := ChunkGenerator.generate(world, region, s, rich)
	var r2 := ChunkGenerator.generate(world, region, s, rich)
	_check(rich != Vector2i.ZERO and not r1.deposits.is_empty(), "found chunk with deposits")
	_check(str(r1.deposits) == str(r2.deposits), "same seed same deposits (non-empty)")
	var other := ChunkGenerator.generate(world + 1, region, s, Vector2i(5, -3))
	_check(other.heights != a.heights, "different world seed changes terrain")
	var edge := ChunkGenerator.generate(world, region, s, Vector2i(31, 0))
	_check(edge.walkable.count(0) > edge.walkable.size() * 0.5, "edge ridge blocks walking")
	var far_cap := 0
	var near_cap := 0
	for cx in range(-28, 29, 4):
		for d in ChunkGenerator.generate(world, region, s, Vector2i(cx, 20)).deposits:
			far_cap = maxi(far_cap, d.capacity)
		for d in ChunkGenerator.generate(world, region, s, Vector2i(cx % 4, 2)).deposits:
			near_cap = maxi(near_cap, d.capacity)
	_check(far_cap > near_cap and far_cap <= 4, "capacity grows with distance, max 4")


func _regions() -> void:
	_cases += 1
	var rules: Dictionary = _rules()
	var regions: Dictionary = rules.open_world.regions
	for base_id: String in rules.bases:
		_check(regions.has(base_id), "%s has a region" % base_id)
		for key in ["relief", "crater_density", "deposit_density", "ice_ratio"]:
			_check(regions.get(base_id, {}).has(key), "%s region has %s" % [base_id, key])


func _ice_and_ids() -> void:
	_cases += 1
	var s: Dictionary = _rules().open_world
	var region: Dictionary = s.regions.mons_mouton
	var world := ChunkGenerator.world_seed("mons_mouton", 3)
	var shadow_ice := 0
	var shadow_all := 0
	var lit_ice := 0
	var lit_all := 0
	var unique_ok := true
	for cx in range(-40, 41, 2):
		for cz in range(-40, 41, 2):
			var ids := {}
			for d in ChunkGenerator.generate(world, region, s, Vector2i(cx, cz)).deposits:
				unique_ok = unique_ok and not ids.has(d.id)
				ids[d.id] = true
				if d.shadow:
					shadow_all += 1
					shadow_ice += int(d.kind == &"ice")
				else:
					lit_all += 1
					lit_ice += int(d.kind == &"ice")
	_check(unique_ok, "deposit ids unique per chunk")
	_check(shadow_all >= 10 and lit_all >= 10, "enough deposits sampled")
	var shadow_share := float(shadow_ice) / maxf(1.0, float(shadow_all))
	var lit_share := float(lit_ice) / maxf(1.0, float(lit_all))
	_check(
		shadow_share > lit_share + 0.2, "ice favours shadow: %f vs %f" % [shadow_share, lit_share]
	)


## Un jugador debe poder salir de la base en las cuatro direcciones en toda region:
## en la franja de 16 m fuera de la exclusion, al menos 80 % de las celdas es transitable
## (las rocas y algun crater pueden bloquear parte, pero no un muro continuo).
func _base_exits() -> void:
	_cases += 1
	var rules: Dictionary = _rules()
	var s: Dictionary = rules.open_world
	var exclusion := _rect(s.base_exclusion_rect)
	var outer := exclusion.grow(16.0)
	for base_id: String in rules.bases:
		var world := ChunkGenerator.world_seed(base_id, 11)
		var good := [0, 0, 0, 0]
		var total := [0, 0, 0, 0]
		for cx in range(-3, 3):
			for cz in range(-3, 3):
				var c := ChunkGenerator.generate(world, s.regions[base_id], s, Vector2i(cx, cz))
				var origin := Vector2(cx, cz) * 16.0
				for row in range(32):
					for col in range(32):
						var p := origin + Vector2(col + 0.5, row + 0.5) * 0.5
						if exclusion.has_point(p) or not outer.has_point(p):
							continue
						var side := _side(exclusion, p)
						if side < 0:
							continue
						total[side] += 1
						good[side] += int(c.walkable[row * 32 + col])
		for side in range(4):
			var share := float(good[side]) / maxf(1.0, float(total[side]))
			_check(total[side] > 0 and share >= 0.8, "%s exit side %d walkable" % [base_id, side])


func _side(rect: Rect2, p: Vector2) -> int:
	var west := p.x < rect.position.x
	var east := p.x > rect.end.x
	var north := p.y < rect.position.y
	var south := p.y > rect.end.y
	if west and not (north or south):
		return 0
	if east and not (north or south):
		return 1
	if north and not (west or east):
		return 2
	if south and not (west or east):
		return 3
	return -1


func _advance_dawns(m: LunarMission, count: int) -> void:
	for _i in range(count):
		m.elapsed = float(m.rules.cycle.period) - 0.1
		m.tick(0.2, SAFE, AWAY)


func _mine(m: LunarMission, key: StringName) -> void:
	var nearby: Array[StringName] = [key, &""]
	m.use_station(0, key)
	m.tick(m.drill_seconds() + 0.1, SAFE, nearby)


func _delta(key: StringName) -> String:
	return String(key).trim_prefix("dep:")


func _deposits() -> void:
	_cases += 1
	var m := LunarMission.new()
	m.prepare("mons_mouton_plateau", 41, true)
	m.finish_tutorial()
	var key := LunarMission.deposit_key(Vector2i(4, 2), 3)
	m.register_deposit(key, &"ice", 2, false)
	_check(m.deposit_left(key) == 2, "fresh deposit full")
	for _trip in range(2):
		_mine(m, key)
		_check(m.cargo_kind(0) == &"ice", "mined ice crate")
		m._consume_cargo(0)
	var delta_key := String(key).trim_prefix("dep:")
	_check(
		m.deposit_left(key) == 0 and m.world_deltas[delta_key].emptied_day == m.days,
		"emptied on day"
	)
	_check(m.use_station(0, key).begins_with("Depósito vacío"), "empty message")
	_advance_dawns(m, 1)
	_check(m.deposit_left(key) == 0, "still empty after 1 dawn")
	_advance_dawns(m, 1)
	_check(m.deposit_left(key) == 2, "refilled after 2 dawns")
	var near := LunarMission.deposit_key(Vector2i(1, 1), 0)
	m.register_deposit(near, &"ore", 1, true)
	_mine(m, near)
	m._consume_cargo(0)
	_advance_dawns(m, 3)
	_check(m.deposit_left(near) == 0, "near base waits 4 dawns")
	_advance_dawns(m, 1)
	_check(m.deposit_left(near) == 1, "near base refilled at 4")
	m.store_checkpoint()
	_mine(m, key)
	m.pilots[0].air = 0.0
	m.tick(0.1, [false, false] as Array[bool], AWAY)
	_check(m.withdrew and m.deposit_left(key) == 2, "air-out reverts mining since dawn")
	var copy := LunarMission.new()
	copy.prepare("mons_mouton_plateau", 41, true)
	copy.restore(m.state())
	copy.register_deposit(key, &"ice", 2, false)
	_check(copy.world_deltas == m.world_deltas, "deltas survive state round trip")
	var legacy := m.state()
	legacy.erase("world_deltas")
	copy.restore(legacy)
	_check(copy.world_deltas is Dictionary, "old save loads")
	_check(
		copy.world_seed == ChunkGenerator.world_seed("mons_mouton_plateau", 41), "world seed set"
	)
	var geo := LunarMission.new()
	geo.prepare("mons_mouton_plateau", 41, true)
	geo.finish_tutorial()
	geo.roles[0] = "geologist"
	var geo_key := LunarMission.deposit_key(Vector2i(2, 2), 1)
	geo.register_deposit(geo_key, &"ice", 12, false)
	var bonus_every := int(geo.rules.roles.geologist.bonus_every)
	for _i in range(bonus_every):
		_mine(geo, geo_key)
		_check(geo.cargo_kind(0) == &"ice", "geologist crate is ice")
		geo._consume_cargo(0)
	_check(geo.pilots[0].pending_extra == &"ice", "geologist bonus earned from deposit")
	_check(geo.deposit_left(geo_key) == 12 - bonus_every, "bonus does not drain deposit")
	geo.use_station(0, geo_key)
	_check(geo.cargo_kind(0) == &"ice" and geo.pilots[0].pending_extra == &"", "extra collected")
	_check(geo.deposit_left(geo_key) == 12 - bonus_every, "extra crate keeps deposit")
	geo._consume_cargo(0)
	var duo := LunarMission.new()
	duo.prepare("mons_mouton_plateau", 41, true)
	duo.finish_tutorial()
	duo.connected[1] = true
	var duo_key := LunarMission.deposit_key(Vector2i(3, 3), 0)
	duo.register_deposit(duo_key, &"ore", 1, false)
	duo.use_station(0, duo_key)
	duo.use_station(1, duo_key)
	var both: Array[StringName] = [duo_key, duo_key]
	duo.tick(duo.drill_seconds() + 0.1, SAFE, both)
	var crates := int(duo.cargo_kind(0) != &"") + int(duo.cargo_kind(1) != &"")
	_check(crates == 1 and duo.deposit_left(duo_key) == 0, "one crate from last unit")
	_check(duo.world_deltas[_delta(duo_key)].left == 0, "left never negative")
	var ghost := LunarMission.new()
	ghost.prepare("mons_mouton_plateau", 41, true)
	ghost.finish_tutorial()
	var ghost_key := LunarMission.deposit_key(Vector2i(9, 9), 9)
	ghost.pilots[0].mine = ghost_key
	ghost.pilots[0].mine_left = 1.0
	var at_ghost: Array[StringName] = [ghost_key, &""]
	ghost.tick(2.0, SAFE, at_ghost)
	_check(ghost.cargo_kind(0) == &"" and ghost.world_deltas.is_empty(), "unregistered key safe")
	_check(ghost.pilots[0].mine == &"", "unregistered mining cancelled")


func _streaming() -> void:
	_cases += 1
	var sim := LunarMission.new()
	sim.prepare("mons_mouton_plateau", 41, true)
	var streamer := ChunkStreamer.new()
	add_child(streamer)
	var s: Dictionary = sim.rules.open_world
	streamer.configure(sim, s, s.regions.mons_mouton_plateau, Color("#6b6678"))
	var focus: Array[Vector3] = [Vector3(100, 0, 100)]
	_check(streamer.needed_coords(focus).size() == 49, "7x7 chunks around one pilot")
	streamer.update(focus)
	_check(streamer.loaded_coords().size() <= 2, "at most 2 chunks per frame")
	await _pump(streamer, focus, func() -> bool: return streamer.loaded_coords().size() == 49)
	_check(
		streamer.loaded_coords().size() == 49 and streamer.is_ready_at(focus[0]), "window loaded"
	)
	_check(_max_step >= 1 and _max_step <= 2, "chunks added per frame stay within the cap")
	var all_data := true
	for coord in streamer.needed_coords(focus):
		all_data = all_data and streamer.data_at(coord) != null
	_check(all_data, "data_at answers for every loaded chunk")
	var key := streamer.nearest_deposit(focus[0], 60.0)
	_check(key != &"" and sim.deposit_left(key) > 0, "deposit registered on load")
	_check(streamer.nearest_deposit(Vector3(100, 0, 100), 0.0) == &"", "no deposit out of reach")
	var parts := String(key).split(":")
	var view: ChunkView = streamer.get_node("Chunk_%d_%d" % [int(parts[1]), int(parts[2])])
	_check(view.body.collision_layer == 1, "terrain collides on layer 1")
	var marker: Node3D = view.get_node("Deposito%d" % int(parts[3]))
	var full_y: float = marker.get_child(0).position.y
	sim.world_deltas[String(key).trim_prefix("dep:")] = {"left": 0, "emptied_day": 0}
	sim.deposit_changed.emit(key, 0)
	_check(marker.get_child(0).position.y < full_y, "empty marker sinks")
	sim.deposit_changed.emit(key, 2)
	_check(is_equal_approx(marker.get_child(0).position.y, full_y), "full marker restored")
	var far: Array[Vector3] = [Vector3(-300, 0, -300)]
	await _pump(streamer, far, func() -> bool: return not streamer.is_ready_at(focus[0]))
	_check(not streamer.is_ready_at(focus[0]), "unloaded beyond radius 4")
	await _pump(streamer, focus, func() -> bool: return streamer.loaded_coords().size() == 49)
	_check(sim.deposit_left(key) == 0, "reloaded chunk keeps empty deposit")
	var edge: Array[Vector3] = [Vector3(510, 0, 0)]
	_check(
		streamer.needed_coords(edge).all(func(c: Vector2i) -> bool: return c.x < 32),
		"no chunks past the world edge"
	)
	var wall: StaticBody3D = streamer.get_node("ParedDelMundo")
	_check(wall.collision_layer == 1 and wall.shape_owner_get_shape_count(0) == 1, "edge wall")
	var elsewhere: Array[Vector3] = [Vector3(300, 0, 300)]
	streamer.update(elsewhere)
	streamer.queue_free()
	await get_tree().process_frame


## `clear()` con una ventana entera en cola no debe esperar a generarla; y la colision
## del chunk debe coincidir con las alturas del terreno.
func _streaming_limits() -> void:
	_cases += 1
	var sim := LunarMission.new()
	sim.prepare("mons_mouton_plateau", 41, true)
	var s: Dictionary = sim.rules.open_world
	var region: Dictionary = s.regions.mons_mouton_plateau
	var started := Time.get_ticks_usec()
	ChunkGenerator.generate(sim.world_seed, region, s, Vector2i(9, 9))
	var one_chunk := Time.get_ticks_usec() - started
	var streamer := ChunkStreamer.new()
	add_child(streamer)
	streamer.configure(sim, s, region, Color("#6b6678"))
	var apart: Array[Vector3] = [Vector3(-300, 0, -300), Vector3(300, 0, 300)]
	streamer.update(apart)
	started = Time.get_ticks_usec()
	streamer.clear()
	var elapsed := Time.get_ticks_usec() - started
	_check(elapsed < one_chunk * 8, "clear cancels queued chunks (%d us)" % elapsed)
	_check(streamer.loaded_coords().is_empty(), "clear leaves nothing loaded")
	var focus: Array[Vector3] = [Vector3(100, 0, 100)]
	await _pump(streamer, focus, func() -> bool: return streamer.loaded_coords().size() == 49)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := streamer.get_world_3d().direct_space_state
	var spots: Array[Vector2] = [
		Vector2(96, 96),
		Vector2(112, 96),
		Vector2(96, 112),
		Vector2(112, 112),
		Vector2(100, 104),
		Vector2(111, 97),
		Vector2(97, 111),
		Vector2(103, 100),
	]
	for spot in spots:
		var top := Vector3(spot.x, 80.0, spot.y)
		var query := PhysicsRayQueryParameters3D.create(top, top + Vector3.DOWN * 160.0, 1)
		var hit := space.intersect_ray(query)
		var expected := ChunkGenerator.height(sim.world_seed, region, s, spot.x, spot.y)
		_check(
			not hit.is_empty() and absf(hit.position.y - expected) < 0.05,
			"collision matches terrain at %s" % spot
		)
	var mid := Vector3(100.5, 80.0, 104.0)
	var mid_hit := space.intersect_ray(
		PhysicsRayQueryParameters3D.create(mid, mid + Vector3.DOWN * 160.0, 1)
	)
	var west := ChunkGenerator.height(sim.world_seed, region, s, 100.0, 104.0)
	var east := ChunkGenerator.height(sim.world_seed, region, s, 101.0, 104.0)
	_check(
		not mid_hit.is_empty() and absf(mid_hit.position.y - (west + east) * 0.5) < 0.05,
		"collision matches along a cell edge"
	)
	streamer.queue_free()
	await get_tree().process_frame


## La campaña real: base en el centro, hielo y mineral fuera, pilotos que nunca caen.
func _campaign() -> void:
	_cases += 1
	var game := await _game_solo("mons_mouton_plateau")
	_check(not CrestWorld.campaign_stations.has(&"ice"), "no fixed ice station")
	_check(not CrestWorld.campaign_stations.has(&"ore"), "no fixed ore station")
	_check(not game.world.has_node("CrateresLaterales"), "chunks replace the side craters")
	var starters := ChunkGenerator.starter_deposits(game.sim.world_seed, game.sim.rules.open_world)
	var ice: Vector3 = starters[0].point
	game._set_positions([ice + Vector3(0.8, 0.3, 0), Vector3.ZERO])
	await _until(func() -> bool: return game.streamer.is_ready_at(ice))
	await _frames(30)
	_check(game._spots[0].begins_with("dep:"), "starter deposit in reach")
	_check(game.ui.action_button.text == "Extraer hielo", "action names the ice deposit")
	game._interact(0, false)
	await _frames(int(game.sim.drill_seconds() * 60) + 10)
	_check(game.sim.cargo_kind(0) == &"ice", "mined starter ice")
	game._interact(0, true)
	await _frames(2)
	_check(game.ui.action_button.text == "Depósito vacío", "emptied starter deposit")
	var crate_id: int = game.sim.crates.keys()[0]
	var far := Vector3(300, 2, 300)
	game._set_positions([far, Vector3.ZERO])
	_check(not game.streamer.is_ready_at(far), "teleport target starts unloaded")
	game._move_pilot(0, 1.0 / 60.0)
	_check(game.pilots[0].position == far, "pilot waits while its chunk loads")
	await _until(func() -> bool: return game.streamer.is_ready_at(far))
	await _frames(240)
	_check(_on_ground(game), "pilot never falls into unloaded chunk")
	_check(
		not game.crate_visible(crate_id) and game.sim.crates.has(crate_id),
		"far crate hidden not lost"
	)
	var start: Vector3 = game.pilots[0].position
	game.ui.joystick.axis = Vector2(1, 0)
	await _frames(120)
	game.ui.joystick.axis = Vector2.ZERO
	var walked: float = start.distance_to(game.pilots[0].position)
	_check(
		walked > 3.0 and _on_ground(game),
		"dash toward new chunks stays on ground (%.1f m)" % walked
	)
	game._save_base(true)
	var again := await _game_continue(game)
	_check(
		again.streamer.is_ready_at(again.pilots[0].position) and _on_ground(again),
		"continue far from base without falling"
	)
	again.sim.pilots[0].air = 0.0
	await _frames(5)
	_check(
		(
			again.world.sheltered(again.pilots[0].position)
			or again.pilots[0].position.distance_to(CrestWorld.SPAWNS[0]) < 1.0
		),
		"air-out returns to dawn spot"
	)
	DirAccess.remove_absolute(again.profile_path)
	again.get_parent().queue_free()
	await get_tree().process_frame


## Ortográfica de equipo en la base; fuera, perspectiva que sigue al piloto sin girar.
func _camera() -> void:
	_cases += 1
	var game := await _game_solo("mons_mouton_plateau")
	await _frames(240)
	_check(not is_instance_valid(game.opening), "opening a base closes the intro")
	_check(game.camera.projection == Camera3D.PROJECTION_ORTHOGONAL, "orthographic inside base")
	_check(absf(game.camera.size - LunarGame.PLAY_SIZE) < 0.05, "team follow zoom kept in base")
	var basis_home: Basis = game.camera.global_basis
	var far := Vector3(60, 1, 40)
	game._set_positions([far, Vector3.ZERO])
	await _until(func() -> bool: return game.streamer.is_ready_at(far))
	await _frames(180)
	_check(game.camera.projection == Camera3D.PROJECTION_PERSPECTIVE, "perspective outside")
	_check(is_equal_approx(game.camera.fov, 45.0), "45 degree field of view")
	var screen: Vector2 = (
		game.camera.unproject_position(game.pilots[0].position) / Vector2(game.get_viewport().size)
	)
	_check(screen.distance_to(Vector2(0.5, 0.55)) < 0.2, "pilot near screen centre (%s)" % screen)
	_check(
		game.camera.global_basis.z.angle_to(basis_home.z) < deg_to_rad(12), "camera keeps heading"
	)
	_check(absf(game.sky.pan) > 0.01, "horizon ridges follow the camera")
	var home := Vector3(2, 0.1, 2)
	game._set_positions([home, Vector3.ZERO])
	await _frames(240)
	var in_base: Vector2 = (
		game.camera.unproject_position(game.pilots[0].position) / Vector2(game.get_viewport().size)
	)
	_check(absf(in_base.x - 0.5) < 0.1, "solo team camera centres the only pilot (%s)" % in_base)
	for edge_z in [10.5, -10.5, 11.9, -11.9]:
		game._set_positions([Vector3(2, 0.1, edge_z), Vector3.ZERO])
		await _frames(240)
		var framed: Vector2 = (
			game.camera.unproject_position(game.pilots[0].position)
			/ Vector2(game.get_viewport().size)
		)
		_check(
			(
				game.camera.projection == Camera3D.PROJECTION_ORTHOGONAL
				and framed.y > 0.1
				and framed.y < 0.9
				and framed.x > 0.1
				and framed.x < 0.9
			),
			"team camera keeps the pilot framed at z %.1f (%s)" % [edge_z, framed]
		)
	_check(
		(
			game.camera.projection == Camera3D.PROJECTION_ORTHOGONAL
			and absf(game.camera.size - LunarGame.PLAY_SIZE) < 0.05
		),
		"back to the team camera in base"
	)
	game._leave()
	_check(game.camera.projection == Camera3D.PROJECTION_ORTHOGONAL, "lobby uses the base view")
	DirAccess.remove_absolute(game.profile_path)
	game.get_parent().queue_free()
	await get_tree().process_frame


## Salto lunar: gravedad y velocidad del registro, ~2 s en el aire y ~1,6 m de altura.
func _jump() -> void:
	_cases += 1
	var game := await _game_solo("mons_mouton_plateau")
	var pilot: CrestPilot = game.pilots[0]
	var s: Dictionary = game.sim.rules.open_world
	_check(
		(
			is_equal_approx(pilot.gravity, float(s.gravity))
			and is_equal_approx(pilot.jump_speed, float(s.jump_speed))
			and is_equal_approx(pilot.air_acceleration, float(s.air_control))
		),
		"lunar jump from registry"
	)
	# Punto abierto y sin techo (el arranque está dentro del refugio).
	var open_point := Vector3(60, 1, 40)
	game._set_positions([open_point, Vector3.ZERO])
	await _until(func() -> bool: return game.streamer.is_ready_at(open_point))
	await _until(func() -> bool: return pilot.is_on_floor())
	await _frames(30)
	var above := PhysicsRayQueryParameters3D.create(
		pilot.global_position + Vector3.UP, pilot.global_position + Vector3.UP * 5.0
	)
	above.collision_mask = 1
	_check(game.get_world_3d().direct_space_state.intersect_ray(above).is_empty(), "no ceiling")
	_check(pilot.is_on_floor(), "standing before the jump")
	var ground := pilot.position.y
	game._jump[0] = true
	await _frames(2)
	var airborne := 2
	var apex := 0.0
	while not pilot.is_on_floor() and airborne < 400:
		airborne += 1
		apex = maxf(apex, pilot.position.y - ground)
		await get_tree().physics_frame
	_check(absf(airborne / 60.0 - 2.0) < 0.15, "about 2 s airborne (%.2f)" % (airborne / 60.0))
	_check(absf(apex - 1.6) < 0.12, "about 1.6 m apex (%.2f)" % apex)
	_check(not game._jump[0], "jump press consumed")
	game.sim._create_cargo(0, &"ice")
	await _frames(2)
	_check(is_equal_approx(pilot.jump_scale, float(s.jump_with_box)), "box scales the jump")
	game.sim.crates.erase(game.sim.pilots[0].cargo)
	game.sim.pilots[0].cargo = 0
	# Sin chunk listo no hay salto ni gravedad.
	var unloaded := Vector3(400, 5, 400)
	game._set_positions([unloaded, Vector3.ZERO])
	_check(not game.streamer.is_ready_at(unloaded), "test chunk has no collision yet")
	game._jump[0] = true
	# Run the movement guard before the async streamer can install the chunk.
	game._move_pilot(0, 1.0 / 60.0)
	_check(pilot.position == unloaded and not game._jump[0], "no jump while the chunk loads")
	var plain := FieldPilot.new()
	_check(
		plain.gravity == 16.0 and plain.jump_speed == FieldPilot.JUMP_SPEED,
		"legacy pilot unchanged"
	)
	plain.free()
	DirAccess.remove_absolute(game.profile_path)
	game.get_parent().queue_free()
	await get_tree().process_frame


## Rutas al tocar: A* sobre chunks cargados fuera de la base, recta si es lejos, mixta en el borde.
func _open_routes() -> void:
	_cases += 1
	var game := await _game_solo("mons_mouton_plateau")
	game._set_positions([Vector3(80, 1, 60), Vector3.ZERO])
	await _until(func() -> bool: return game.streamer.loaded_coords().size() == 49)
	await _frames(240)
	_check(game._planner.open.rebuilds == 0, "streaming without taps never rebuilds the route grid")
	game._set_positions([Vector3(200, 1, 60), Vector3.ZERO])
	await _until(func() -> bool: return game.streamer.is_ready_at(Vector3(200, 1, 60)))
	await _frames(120)
	game._set_positions([Vector3(80, 1, 60), Vector3.ZERO])
	await _until(func() -> bool: return game.streamer.loaded_coords().size() == 49)
	await _frames(120)
	_check(game._planner.open.rebuilds == 0, "moving across chunks never rebuilds the route grid")
	var routes := OpenRoutes.new()
	var began := Time.get_ticks_usec()
	routes.rebuild(game.streamer)
	print("OPEN ROUTES rebuild 49 chunks: %.1f ms" % [(Time.get_ticks_usec() - began) / 1000.0])
	var start: Vector3 = game.pilots[0].position
	var path := routes.path(start, start + Vector3(12, 0, 6))
	_check(path.size() >= 2, "short open route exists")
	for p in path:
		var c := ChunkGenerator.coord_of(Vector3(p.x, 0, p.y), 16.0)
		var data: ChunkData = game.streamer.data_at(c)
		var cell := Vector2i(((Vector2(p.x, p.y) - Vector2(c) * 16.0) / 0.5).floor())
		_check(data.walkable[cell.y * 32 + cell.x] == 1, "route only on walkable cells")
	var tap := start + Vector3(12, 0, 6)
	var tapped := Time.get_ticks_usec()
	game._set_destination(0, tap)
	print(
		(
			"OPEN ROUTES on-demand rebuild + path: %.1f ms"
			% [(Time.get_ticks_usec() - tapped) / 1000.0]
		)
	)
	_check(game._planner.open.rebuilds == 1, "the first tap rebuilds once")
	game._set_destination(0, tap)
	_check(game._planner.open.rebuilds == 1, "a second tap in the same window reuses the grid")
	_check(game._route[0].size() >= 2, "tap within radius follows the open route")
	game._set_destination(0, start + Vector3(35, 0, 0))
	_check(game._route[0].size() == 1, "far tap walks straight")
	# Cruzar el borde plano: un extremo dentro y otro fuera dan una ruta continua.
	var flat := _rect(game.sim.rules.open_world.base_flat_rect)
	var inside := Vector3(flat.end.x - 3.0, 0.0, 0.0)
	var outside := Vector3(flat.end.x + 8.0, 0.0, 0.0)
	game._set_positions([inside, Vector3.ZERO])
	await _frames(30)
	game._set_destination(0, outside)
	var out_route: PackedVector2Array = game._route[0]
	_check(out_route.size() >= 2, "base to outside has a route")
	_check(
		out_route[out_route.size() - 1].distance_to(Vector2(outside.x, outside.z)) < 1.0,
		"outbound ends at the tap"
	)
	game._set_positions([outside, Vector3.ZERO])
	await _frames(30)
	game._set_destination(0, inside)
	var in_route: PackedVector2Array = game._route[0]
	_check(in_route.size() >= 2, "outside to base has a route")
	_check(
		in_route[in_route.size() - 1].distance_to(Vector2(inside.x, inside.z)) < 1.0,
		"inbound ends at the tap"
	)
	_obstacle_detour(game)
	DirAccess.remove_absolute(game.profile_path)
	game.get_parent().queue_free()
	await get_tree().process_frame


## Una celda de 0,5 m (indice global) es transitable en los chunks cargados.
func _walkable_cell(streamer: ChunkStreamer, cell: Vector2i) -> bool:
	var chunk := Vector2i((Vector2(cell) / 32.0).floor())
	var data: ChunkData = streamer.data_at(chunk)
	if data == null:
		return false
	var local := cell - chunk * 32
	return data.walkable[local.y * 32 + local.x] == 1


## Con un obstaculo entre origen y destino, la ruta lo rodea; sin chunk cargado, recta.
func _obstacle_detour(game: Node) -> void:
	var streamer: ChunkStreamer = game.streamer
	var block := Vector2i.ZERO
	var found := false
	for chunk in streamer.loaded_coords():
		for index in range(1024):
			var cell := chunk * 32 + Vector2i(index % 32, index / 32)
			if found or _walkable_cell(streamer, cell):
				continue
			found = true
			for k in range(-6, 7):
				found = found and (k == 0 or _walkable_cell(streamer, cell + Vector2i(k, 0)))
			block = cell
	_check(found, "loaded terrain has an isolated blocked cell in a walkable row")
	if not found:
		return
	var from := Vector3((block.x - 6 + 0.5) * 0.5, 0.0, (block.y + 0.5) * 0.5)
	var to := Vector3((block.x + 6 + 0.5) * 0.5, 0.0, (block.y + 0.5) * 0.5)
	var routes := OpenRoutes.new()
	routes.rebuild(streamer)
	var path := routes.path(from, to)
	var length := 0.0
	for index in range(path.size()):
		var p := path[index]
		_check(
			_walkable_cell(streamer, Vector2i((p / 0.5).floor())),
			"detour waypoint %d is on a walkable cell" % index
		)
		if index > 0:
			length += path[index].distance_to(path[index - 1])
	_check(path.size() >= 3, "obstacle forces intermediate waypoints")
	_check(length > 6.0 + 0.1, "route is longer than the blocked straight line")
	# Sin chunks cargados el destino queda fuera de la rejilla: recta de un punto.
	var planner := RoutePlanner.new()
	streamer.clear()
	planner.update(streamer)
	var rules: Dictionary = game.sim.rules.open_world
	var plan := planner.plan(game._routes, from, from + Vector3(10, 0, 0), rules)
	_check(plan.size() == 1, "target in an unloaded chunk walks straight")


## El piloto 0 no está por debajo del relieve (el terreno lejano puede estar bajo Y = 0).
func _on_ground(game: Node) -> bool:
	var point: Vector3 = game.pilots[0].position
	var s: Dictionary = game.sim.rules.open_world
	var region: Dictionary = s.regions[game.sim.base_id]
	var ground := ChunkGenerator.height(game.sim.world_seed, region, s, point.x, point.z)
	return point.y > ground - 0.5


func _enclosure() -> void:
	_cases += 1
	var game := await _game_solo("mons_mouton_plateau")
	var s: Dictionary = game.sim.rules.open_world
	var flat := _rect(s.base_flat_rect)
	var enclosure: BaseEnclosure = game.world.enclosure
	var arrow: BaseArrow = game.world.base_arrow
	_check(enclosure != null and arrow != null, "the campaign base builds wall and arrow")
	var door := enclosure.door_point()
	_check(
		is_equal_approx(door.x, flat.end.x + float(s.base_wall.thickness) * 0.5),
		"door sits in the east wall"
	)
	_check(
		is_equal_approx(enclosure.outside_point().x - door.x, float(s.base_wall.outside_distance)),
		"outside point is beyond the door"
	)
	# Ningun lado se puede cruzar, ni caminando ni saltando contra el.
	var trials: Array = []
	for x in [-14.0, 0.0, 12.0]:
		trials.append([Vector3(x, 0.1, -9.5), Vector2(x, -30.0)])
		trials.append([Vector3(x, 0.1, 9.5), Vector2(x, 30.0)])
	for z in [-8.0, -2.0, 8.0]:
		trials.append([Vector3(-18.5, 0.1, z), Vector2(-40.0, z)])
	for z in [-8.0, -5.0, 8.0, 10.0]:
		trials.append([Vector3(18.5, 0.1, z), Vector2(40.0, z)])
	var trial := 0
	for item: Array in trials:
		for jumping in [false, true]:
			trial += 1
			game._set_positions([item[0], Vector3.ZERO])
			var escaped := false
			var nearest := INF
			for frame in range(100):
				game._route[0] = PackedVector2Array([item[1]])
				game._jump[0] = jumping and frame % 20 == 0
				await _frames(1)
				var at: Vector3 = game.pilots[0].position
				escaped = escaped or not flat.has_point(Vector2(at.x, at.z))
				nearest = minf(nearest, _wall_gap(flat, at))
			_check(not escaped, "trial %d (%s, jump %s) stays inside" % [trial, item[0], jumping])
			_check(nearest < 0.7, "trial %d pushed against the wall (%.2f m)" % [trial, nearest])
	game._route[0].clear()
	# La puerta se abre sola con un piloto cerca y se cierra al alejarse.
	game._set_positions([Vector3(door.x - 2.0, 0.1, door.z), Vector3.ZERO])
	await _frames(60)
	_check(enclosure.is_open() and enclosure.openness > 0.99, "door opens with a pilot at 2 m")
	game._set_positions([Vector3(door.x - 3.5, 0.1, door.z), Vector3.ZERO])
	await _frames(60)
	_check(not enclosure.is_open() and enclosure.openness < 0.01, "door closes at 3.5 m")
	# Sin el juego de por medio: la puerta solo depende de las posiciones que recibe, las
	# mismas en el anfitrion y en el invitado.
	var shared := BaseEnclosure.new(s)
	add_child(shared)
	shared.build()
	var unseen: Array[Vector3] = [Vector3(door.x - 8.0, 0.0, door.z)]
	shared.update_door(unseen)
	await _frames(40)
	_check(shared.openness < 0.01, "a distant pilot leaves the door closed")
	var near: Array[Vector3] = [Vector3(door.x - 8.0, 0.0, door.z), door + Vector3(2.9, 0, 0)]
	shared.update_door(near)
	await _frames(40)
	_check(shared.openness > 0.99, "either pilot opens it")
	shared.update_door(unseen)
	await _frames(40)
	_check(shared.openness < 0.01, "it closes again when both walk away")
	shared.queue_free()
	# Se sale y se vuelve a entrar por la puerta siguiendo la ruta.
	game._set_positions([CrestWorld.SPAWNS[0], Vector3.ZERO])
	await _frames(30)
	game._set_destination(0, enclosure.outside_point())
	var frames := 0
	while game.pilots[0].position.x < flat.end.x + 0.8 and frames < 900:
		frames += 1
		await _frames(1)
	_check(game.pilots[0].position.x >= flat.end.x + 0.8, "the route leads out through the door")
	game._set_destination(0, CrestWorld.SPAWNS[0])
	frames = 0
	while game.pilots[0].position.x > flat.end.x - 1.0 and frames < 900:
		frames += 1
		await _frames(1)
	_check(game.pilots[0].position.x <= flat.end.x - 1.0, "from outside the route returns inside")
	_check(
		flat.has_point(Vector2(game.pilots[0].position.x, game.pilots[0].position.z)),
		"pilot is back inside"
	)
	# Ninguna ruta cruza el muro: entra y sale por la puerta.
	var tap_out := door + Vector3(10.0, 0.0, 0.0)
	for start: Vector3 in [Vector3(5, 0.1, -8), Vector3(-12, 0.1, 7), CrestWorld.SPAWNS[1]]:
		game._set_positions([start, Vector3.ZERO])
		await _frames(30)
		var outbound: PackedVector2Array = game._planner.plan(game._routes, start, tap_out, s)
		var inbound: PackedVector2Array = game._planner.plan(game._routes, tap_out, start, s)
		for route: PackedVector2Array in [outbound, inbound]:
			var origin := start if route == outbound else tap_out
			_check(route.size() >= 2, "route across the door exists from %s" % start)
			_check(
				not _route_hits_wall(enclosure, origin, route),
				"route from %s avoids the wall" % origin
			)
	# La flecha: solo fuera, hacia la puerta, con los metros.
	var spots: Array[Vector3] = [
		Vector3(-60, 1, 40),
		Vector3(45, 1, -70),
		Vector3(30, 1, 3),
		Vector3(250, 1, -30),
		Vector3(-10, 1, -45)
	]
	for spot in spots:
		game._set_positions([spot, Vector3.ZERO])
		await _until(func() -> bool: return game.streamer.is_ready_at(spot))
		await _frames(20)
		var at: Vector3 = game.pilots[0].position
		var to_door := Vector2(door.x - at.x, door.z - at.z)
		var heading := Vector2(arrow.global_basis.z.x, arrow.global_basis.z.z)
		_check(arrow.visible, "arrow is visible at %s" % spot)
		_check(
			(
				rad_to_deg(heading.angle_to(to_door)) < 3.0
				and rad_to_deg(heading.angle_to(to_door)) > -3.0
			),
			"arrow points at the door from %s" % spot
		)
		_check(
			arrow.label.text == "%d m" % roundi(to_door.length()),
			"arrow label shows %d m (%s)" % [roundi(to_door.length()), arrow.label.text]
		)
	game._set_positions([Vector3(2, 0.1, 2), Vector3.ZERO])
	await _frames(30)
	_check(not arrow.visible, "no arrow inside the base")
	DirAccess.remove_absolute(game.profile_path)
	game.get_parent().queue_free()
	await get_tree().process_frame


## Distancia del piloto al muro mas cercano (en XZ, desde el borde plano).
func _wall_gap(flat: Rect2, at: Vector3) -> float:
	return minf(
		minf(at.x - flat.position.x, flat.end.x - at.x),
		minf(at.z - flat.position.y, flat.end.y - at.z)
	)


## Algun punto de la ruta (muestreada cada 5 cm) cae dentro de una pieza solida del muro.
func _route_hits_wall(enclosure: BaseEnclosure, origin: Vector3, route: PackedVector2Array) -> bool:
	var previous := Vector2(origin.x, origin.z)
	for point in route:
		var length := previous.distance_to(point)
		for step in range(int(length / 0.05) + 1):
			var sample := previous.lerp(point, float(step) * 0.05 / maxf(length, 0.001))
			for rect in enclosure.wall_rects():
				if rect.has_point(sample):
					return true
		previous = point
	return false


## Una celda de 0,5 m (indice global) es transitable en los chunks cargados.


func _frames(n: int) -> void:
	for _i in range(n):
		await get_tree().physics_frame


## Espera fotogramas de física hasta que `done` sea cierto o pasen 20 s de reloj.
func _until(done: Callable) -> void:
	var deadline := Time.get_ticks_msec() + 20000
	while not done.call() and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame


## `lunar.tscn` en su propio mundo y con un perfil temporal, como `_endpoint` en lunar_suite.
func _new_game(profile_path: String) -> Node:
	var scope := SubViewport.new()
	scope.size = Vector2i(1152, 648)
	scope.own_world_3d = true
	scope.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(scope)
	get_tree().set_multiplayer(SceneMultiplayer.new(), scope.get_path())
	var game := GAME.instantiate()
	game.profile_path = profile_path
	scope.add_child(game)
	return game


func _game_solo(base_id: String) -> Node:
	var game := _new_game("user://artemis-open-world-%d.dat" % randi())
	await _frames(2)
	game._start_solo(base_id)
	game.sim.finish_tutorial()
	await _until(func() -> bool: return game.streamer.is_ready_at(CrestWorld.SPAWNS[0]))
	return game


## Libera `game` y abre otro con el mismo perfil continuando desde el selector.
func _game_continue(game: Node) -> Node:
	var path: String = game.profile_path
	game.get_parent().queue_free()
	await get_tree().process_frame
	var again := _new_game(path)
	await _frames(2)
	again._choose("title_enter", "")
	var pressed := false
	for item: Control in again.ui._list.get_children():
		if item is Button and item.text == "Jugar solo · sin conexión":
			item.pressed.emit()
			pressed = true
	_check(pressed, "menu offers Jugar solo")
	var base_id := String(again.profile.data.recent)
	_check(again.ui.globe.enter_base(base_id), "selector continues the saved base")
	await _until(func() -> bool: return not again._loading)
	return again


## Llama a `update` cada frame hasta que `done` sea cierto o pasen 20 s de reloj.
func _pump(streamer: ChunkStreamer, focus: Array[Vector3], done: Callable) -> void:
	var deadline := Time.get_ticks_msec() + 20000
	while not done.call() and Time.get_ticks_msec() < deadline:
		var before := streamer.loaded_coords().size()
		streamer.update(focus)
		_max_step = maxi(_max_step, streamer.loaded_coords().size() - before)
		await get_tree().process_frame


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failed += 1
		push_error("FAIL: %s" % label)
		print("FAIL: %s" % label)
