extends Node

const REGISTRY := "res://context_core/state_registry.json"

var _checks := 0
var _failed := 0
var _cases := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_generation()
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
	for coord in [Vector2i(-1, -1), Vector2i(0, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
		var c := ChunkGenerator.generate(world, region, s, coord)
		for d in c.deposits:
			var inside := Rect2(-23.45, -16.7, 46.9, 33.4).has_point(Vector2(d.point.x, d.point.z))
			_check(not inside, "no deposit in base")
	for base_id: String in rules.bases:
		var w := ChunkGenerator.world_seed(base_id, 7)
		var starters := ChunkGenerator.starter_deposits(w, s)
		_check(starters.size() == 2, "%s two starters" % base_id)
		for d in starters:
			var r := Vector2(d.point.x, d.point.z).length()
			_check(r >= 25.0 and r <= 40.0, "%s starter within 25-40 m" % base_id)
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


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failed += 1
		push_error("FAIL: %s" % label)
		print("FAIL: %s" % label)
