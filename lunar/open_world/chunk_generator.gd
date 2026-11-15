class_name ChunkGenerator
extends RefCounted

## Generador determinista del mundo abierto. Funciones estaticas sin estado
## compartido ni acceso al arbol de escena: seguro para WorkerThreadPool.


static func world_seed(base_id: String, run: int) -> int:
	return hash([base_id, run])


static func coord_of(point: Vector3, chunk_size: float) -> Vector2i:
	return Vector2i(floori(point.x / chunk_size), floori(point.z / chunk_size))


static func height(
	world_seed: int, region: Dictionary, settings: Dictionary, x: float, z: float
) -> float:
	var noise := _noise(world_seed, settings)
	var area := Rect2(x, z, 0.0, 0.0)
	var craters := _craters(world_seed, region, settings, area)
	return _height(noise, craters, region, settings, x, z)


static func capacity_at(settings: Dictionary, distance: float) -> int:
	var curve: Dictionary = settings.deposit_distance_curve
	var t := clampf(distance / float(curve.full_distance), 0.0, 1.0)
	t = pow(t, float(curve.exponent))
	var low := int(curve.min_capacity)
	var high := int(curve.max_capacity)
	return low + floori(float(high - low) * t)


static func starter_deposits(world_seed: int, settings: Dictionary) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world_seed, "starter"])
	var exclusion := _rect(settings.base_exclusion_rect)
	var range_m: Array = settings.starter_deposit_range
	var ids: Array = settings.starter_deposit_ids
	var kinds: Array[StringName] = [&"ice", &"ore"]
	var result: Array[Dictionary] = []
	for i in range(kinds.size()):
		var point := Vector2.ZERO
		for attempt in range(64):
			var angle := rng.randf() * TAU
			var radius := rng.randf_range(float(range_m[0]), float(range_m[1]))
			point = Vector2.from_angle(angle) * radius
			if not exclusion.has_point(point):
				break
		(
			result
			. append(
				{
					id = int(ids[i]),
					kind = kinds[i],
					point = Vector3(point.x, 0.0, point.y),
					capacity = int(settings.deposit_distance_curve.min_capacity),
					near_base = true,
					shadow = false,
				}
			)
		)
	return result


static func generate(
	world_seed: int, region: Dictionary, settings: Dictionary, coord: Vector2i
) -> ChunkData:
	var size := float(settings.chunk_size)
	var data := ChunkData.new()
	data.coord = coord
	data.size = size
	data.samples = roundi(size / float(settings.height_step)) + 1
	var origin := Vector2(coord) * size
	var noise := _noise(world_seed, settings)
	var craters := _craters(world_seed, region, settings, Rect2(origin, Vector2(size, size)))
	_fill_heights(data, noise, craters, region, settings, origin)
	_fill_walkable(data, noise, craters, region, settings, origin)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world_seed, coord.x, coord.y])
	_place_deposits(data, rng, world_seed, region, settings, craters, origin)
	_place_rocks(data, rng, settings, origin)
	return data


static func _noise(world_seed: int, settings: Dictionary) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = world_seed
	noise.frequency = float(settings.noise_frequency)
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = int(settings.noise_octaves)
	return noise


static func _rect(values: Array) -> Rect2:
	return Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))


static func _rect_distance(rect: Rect2, point: Vector2) -> float:
	var dx := maxf(maxf(rect.position.x - point.x, point.x - rect.end.x), 0.0)
	var dz := maxf(maxf(rect.position.y - point.y, point.y - rect.end.y), 0.0)
	return Vector2(dx, dz).length()


static func _craters(
	world_seed: int, region: Dictionary, settings: Dictionary, area: Rect2
) -> Array[Dictionary]:
	var cell := float(settings.crater_cell)
	var radii: Array = settings.crater_radius
	var low := Vector2i((area.position / cell).floor()) - Vector2i.ONE
	var high := Vector2i((area.end / cell).floor()) + Vector2i.ONE
	var result: Array[Dictionary] = []
	for cx in range(low.x, high.x + 1):
		for cz in range(low.y, high.y + 1):
			var rng := RandomNumberGenerator.new()
			rng.seed = hash([world_seed, cx, cz, "crater"])
			if rng.randf() >= float(region.crater_density):
				continue
			var radius := rng.randf_range(float(radii[0]), float(radii[1]))
			var jitter := Vector2(rng.randf_range(0.2, 0.8), rng.randf_range(0.2, 0.8))
			(
				result
				. append(
					{
						center = (Vector2(cx, cz) + jitter) * cell,
						radius = radius,
						depth = radius * float(settings.crater_depth_ratio),
					}
				)
			)
	return result


static func _crater_offset(craters: Array[Dictionary], settings: Dictionary, p: Vector2) -> float:
	var total := 0.0
	for crater in craters:
		var u: float = p.distance_to(crater.center) / crater.radius
		if u >= 2.0:
			continue
		var depth: float = crater.depth
		if u < 1.0:
			var bowl := 1.0 - u * u
			total -= depth * bowl * bowl
		var rim := depth * float(settings.crater_rim_ratio)
		total += rim * exp(-pow((u - 1.0) / 0.3, 2.0))
	return total


static func _in_crater(craters: Array[Dictionary], p: Vector2) -> bool:
	for crater in craters:
		if p.distance_to(crater.center) < crater.radius * 0.7:
			return true
	return false


static func _height(
	noise: FastNoiseLite,
	craters: Array[Dictionary],
	region: Dictionary,
	settings: Dictionary,
	x: float,
	z: float
) -> float:
	var p := Vector2(x, z)
	var flat := _rect(settings.base_flat_rect)
	var blend := smoothstep(0.0, float(settings.base_flat_transition), _rect_distance(flat, p))
	var relief := noise.get_noise_2d(x, z) * float(region.relief) * float(settings.relief_amplitude)
	var terrain := (relief + _crater_offset(craters, settings, p)) * blend
	var band := float(settings.edge_band)
	var to_edge := float(settings.world_size) * 0.5 - maxf(absf(x), absf(z))
	var t := clampf((band - to_edge) / band, 0.0, 1.0)
	return terrain + float(settings.edge_ridge_height) * t * t


static func _fill_heights(
	data: ChunkData,
	noise: FastNoiseLite,
	craters: Array[Dictionary],
	region: Dictionary,
	settings: Dictionary,
	origin: Vector2
) -> void:
	var step := data.size / float(data.samples - 1)
	data.heights.resize(data.samples * data.samples)
	for row in range(data.samples):
		for col in range(data.samples):
			var x := origin.x + float(col) * step
			var z := origin.y + float(row) * step
			data.heights[row * data.samples + col] = _height(noise, craters, region, settings, x, z)


static func _fill_walkable(
	data: ChunkData,
	noise: FastNoiseLite,
	craters: Array[Dictionary],
	region: Dictionary,
	settings: Dictionary,
	origin: Vector2
) -> void:
	var cell := float(settings.walk_cell)
	var cells := roundi(data.size / cell)
	var corners := cells + 1
	var corner_heights := PackedFloat32Array()
	corner_heights.resize(corners * corners)
	for row in range(corners):
		for col in range(corners):
			var x := origin.x + float(col) * cell
			var z := origin.y + float(row) * cell
			corner_heights[row * corners + col] = _height(noise, craters, region, settings, x, z)
	var max_slope := float(settings.max_walk_slope)
	data.walkable.resize(cells * cells)
	for row in range(cells):
		for col in range(cells):
			var h00 := corner_heights[row * corners + col]
			var h10 := corner_heights[row * corners + col + 1]
			var h01 := corner_heights[(row + 1) * corners + col]
			var h11 := corner_heights[(row + 1) * corners + col + 1]
			var gx := ((h10 + h11) - (h00 + h01)) / (2.0 * cell)
			var gz := ((h01 + h11) - (h00 + h10)) / (2.0 * cell)
			data.walkable[row * cells + col] = 1 if Vector2(gx, gz).length() <= max_slope else 0


## Punto aleatorio del chunk fuera de la exclusion de la base, o NAN si no hay.
static func _free_point(
	rng: RandomNumberGenerator, origin: Vector2, size: float, exclusion: Rect2
) -> Vector2:
	for attempt in range(8):
		var point := (
			origin + Vector2(rng.randf_range(1.0, size - 1.0), rng.randf_range(1.0, size - 1.0))
		)
		if not exclusion.has_point(point):
			return point
	return Vector2(NAN, NAN)


static func _place_deposits(
	data: ChunkData,
	rng: RandomNumberGenerator,
	world_seed: int,
	region: Dictionary,
	settings: Dictionary,
	craters: Array[Dictionary],
	origin: Vector2
) -> void:
	var size := data.size
	var chunk_rect := Rect2(origin, Vector2(size, size))
	var exclusion := _rect(settings.base_exclusion_rect)
	var per_chunk := int(settings.deposits_per_chunk_max)
	var span := roundi(float(settings.world_size) / size) + 1
	var half := span >> 1
	var chunk_index := (data.coord.x + half) * span + (data.coord.y + half)
	var inside: Array[Dictionary] = []
	for crater in craters:
		if chunk_rect.has_point(crater.center):
			inside.append(crater)
	for slot in range(per_chunk):
		var wanted := rng.randf() < float(region.deposit_density)
		var in_crater := rng.randf() < float(settings.crater_deposit_bias)
		var point := _free_point(rng, origin, size, exclusion)
		var pick := rng.randi()
		if in_crater and not inside.is_empty():
			var crater: Dictionary = inside[pick % inside.size()]
			var offset := Vector2.from_angle(rng.randf() * TAU) * float(crater.radius) * 0.4
			var candidate: Vector2 = crater.center + offset
			if chunk_rect.has_point(candidate) and not exclusion.has_point(candidate):
				point = candidate
		var shadow := not is_nan(point.x) and _in_crater(craters, point)
		var ice_chance := float(settings.ice_shadow_chance) if shadow else float(region.ice_ratio)
		var is_ice := rng.randf() < ice_chance
		if not wanted or is_nan(point.x):
			continue
		var distance := point.length()
		(
			data
			. deposits
			. append(
				{
					id =
					int(settings.deposit_id_base) + chunk_index * per_chunk + data.deposits.size(),
					kind = &"ice" if is_ice else &"ore",
					point = Vector3(point.x, data.height_at(point - origin), point.y),
					capacity = capacity_at(settings, distance),
					near_base = distance < float(settings.deposit_near_radius),
					shadow = shadow,
				}
			)
		)
	for starter in starter_deposits(world_seed, settings):
		var spot := Vector2(starter.point.x, starter.point.z)
		if chunk_rect.has_point(spot):
			starter.point = Vector3(spot.x, data.height_at(spot - origin), spot.y)
			data.deposits.append(starter)


static func _place_rocks(
	data: ChunkData, rng: RandomNumberGenerator, settings: Dictionary, origin: Vector2
) -> void:
	var counts: Array = settings.rocks_per_chunk
	var scales: Array = settings.rock_scale
	var exclusion := _rect(settings.base_exclusion_rect)
	var cell := float(settings.walk_cell)
	var cells := roundi(data.size / cell)
	for i in range(rng.randi_range(int(counts[0]), int(counts[1]))):
		var point := _free_point(rng, origin, data.size, exclusion)
		var rock_scale := rng.randf_range(float(scales[0]), float(scales[1]))
		var rock_seed := rng.randi()
		if is_nan(point.x) or _near_deposit(data, point):
			continue
		(
			data
			. rocks
			. append(
				{
					point = Vector3(point.x, data.height_at(point - origin), point.y),
					scale = rock_scale,
					seed = rock_seed,
				}
			)
		)
		var radius := float(settings.rock_radius) * rock_scale
		var local := point - origin
		for row in range(
			maxi(0, floori((local.y - radius) / cell)),
			mini(cells, ceili((local.y + radius) / cell))
		):
			for col in range(
				maxi(0, floori((local.x - radius) / cell)),
				mini(cells, ceili((local.x + radius) / cell))
			):
				var center := Vector2((float(col) + 0.5) * cell, (float(row) + 0.5) * cell)
				if center.distance_to(local) <= radius + cell * 0.5:
					data.walkable[row * cells + col] = 0


static func _near_deposit(data: ChunkData, point: Vector2) -> bool:
	for deposit in data.deposits:
		if Vector2(deposit.point.x, deposit.point.z).distance_to(point) < 2.0:
			return true
	return false
