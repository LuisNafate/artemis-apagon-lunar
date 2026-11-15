extends Node

const REGISTRY := "res://context_core/state_registry.json"

var _checks := 0
var _failed := 0
var _cases := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_generation()
	_regions()
	_ice_and_ids()
	_base_exits()
	print("OPEN SUITE: %d cases, %d assertions, %d failed" % [_cases, _checks, _failed])
	get_tree().quit(int(_failed > 0))


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
	var exclusion := Rect2(-23.45, -16.7, 46.9, 33.4)
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
	var exclusion := Rect2(-23.45, -16.7, 46.9, 33.4)
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


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failed += 1
		push_error("FAIL: %s" % label)
		print("FAIL: %s" % label)
