extends Node

const REGISTRY := "res://context_core/state_registry.json"
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
