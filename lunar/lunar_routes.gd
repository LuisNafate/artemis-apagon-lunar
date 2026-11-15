class_name LunarRoutes
extends RefCounted

const CELL := 0.5
const LIMITS := Rect2i(-29, -16, 59, 33)

var _grid := AStarGrid2D.new()


func build(space: PhysicsDirectSpaceState3D) -> void:
	_grid.region = LIMITS
	_grid.cell_size = Vector2.ONE * CELL
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.update()
	var probe := PhysicsRayQueryParameters3D.new()
	probe.collision_mask = 1
	for x in range(LIMITS.position.x, LIMITS.end.x):
		for z in range(LIMITS.position.y, LIMITS.end.y):
			var blocked := false
			for offset: Vector2 in [
				Vector2.ZERO,
				Vector2(0.26, 0),
				Vector2(-0.26, 0),
				Vector2(0, 0.26),
				Vector2(0, -0.26)
			]:
				var point := Vector3(x * CELL + offset.x, 0.28, z * CELL + offset.y)
				probe.from = point + Vector3.UP * 0.8
				probe.to = point
				probe.hit_from_inside = true
				if not space.intersect_ray(probe).is_empty():
					blocked = true
					break
			_grid.set_point_solid(Vector2i(x, z), blocked)


func path(start: Vector3, end: Vector3) -> PackedVector2Array:
	return _grid.get_point_path(_near_cell(start), _near_cell(end), true)


func _near_cell(point: Vector3) -> Vector2i:
	var cell := (Vector2(point.x, point.z) / CELL).round()
	var center := Vector2i(cell).clamp(LIMITS.position, LIMITS.end - Vector2i.ONE)
	var best := center
	var best_distance := INF
	for x in range(-2, 3):
		for y in range(-2, 3):
			var candidate := center + Vector2i(x, y)
			if not LIMITS.has_point(candidate) or _grid.is_point_solid(candidate):
				continue
			var distance := Vector2(candidate).distance_squared_to(cell)
			if distance < best_distance:
				best_distance = distance
				best = candidate
	return best
