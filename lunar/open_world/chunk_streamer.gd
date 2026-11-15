class_name ChunkStreamer
extends Node3D

## Carga y descarga chunks alrededor de uno o varios puntos de foco. Los datos se
## generan en WorkerThreadPool; los nodos solo se crean en `update`, en el hilo principal.

const CACHE_LIMIT := 32
const WALL_THICKNESS := 2.0
const WALL_HEIGHT := 80.0

var _sim: LunarMission
var _settings: Dictionary = {}
var _region: Dictionary = {}
var _soil := Color.WHITE
var _world_seed := 0
var _chunk_size := 16.0
var _half_chunks := 32
var _views: Dictionary[Vector2i, ChunkView] = {}
var _jobs: Dictionary[Vector2i, Job] = {}
var _done: Dictionary[Vector2i, Job] = {}
var _cache: Dictionary[Vector2i, ChunkData] = {}
var _deposit_index: Dictionary[StringName, Dictionary] = {}
var _wall: StaticBody3D


func configure(sim: LunarMission, settings: Dictionary, region: Dictionary, soil: Color) -> void:
	clear()
	if _sim != null and _sim.deposit_changed.is_connected(_on_deposit_changed):
		_sim.deposit_changed.disconnect(_on_deposit_changed)
	_sim = sim
	_settings = settings.duplicate(true)
	_region = region.duplicate(true)
	_soil = soil
	_world_seed = sim.world_seed
	_chunk_size = float(_settings.chunk_size)
	_half_chunks = roundi(float(_settings.world_size) / _chunk_size) >> 1
	_sim.deposit_changed.connect(_on_deposit_changed)
	_build_wall()


## Coordenadas dentro de `load_radius` de algun foco y dentro del mundo, las mas cercanas antes.
func needed_coords(focus_points: Array[Vector3]) -> Array[Vector2i]:
	var radius := int(_settings.load_radius)
	var found: Dictionary[Vector2i, int] = {}
	for point in focus_points:
		var center := ChunkGenerator.coord_of(point, _chunk_size)
		for cx in range(center.x - radius, center.x + radius + 1):
			for cz in range(center.y - radius, center.y + radius + 1):
				var coord := Vector2i(cx, cz)
				if _in_world(coord):
					found[coord] = 0
	var result: Array[Vector2i] = []
	result.assign(found.keys())
	var foci := _focus_coords(focus_points)
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _gap(a, foci) < _gap(b, foci))
	return result


func loaded_coords() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	result.assign(_views.keys())
	return result


func is_ready_at(point: Vector3) -> bool:
	var view: ChunkView = _views.get(ChunkGenerator.coord_of(point, _chunk_size))
	return view != null and view.body != null and view.body.is_inside_tree()


func nearest_deposit(point: Vector3, reach: float) -> StringName:
	var best := &""
	var best_distance := reach
	for view: ChunkView in _views.values():
		for deposit in view.data.deposits:
			var distance := Vector2(deposit.point.x - point.x, deposit.point.z - point.z).length()
			if distance <= best_distance:
				best_distance = distance
				best = LunarMission.deposit_key(view.data.coord, int(deposit.id))
	return best


## Datos de cualquier chunk cargado; para los recien descargados, la cache LRU.
func data_at(coord: Vector2i) -> ChunkData:
	var view: ChunkView = _views.get(coord)
	if view != null:
		return view.data
	return _cache.get(coord)


func update(focus_points: Array[Vector3]) -> void:
	if _sim == null:
		return
	_collect()
	var needed := needed_coords(focus_points)
	for coord in needed:
		if not (_views.has(coord) or _jobs.has(coord) or _done.has(coord)):
			_start(coord)
	_unload(_focus_coords(focus_points))
	var budget := int(_settings.chunks_per_frame)
	while budget > 0 and not _done.is_empty():
		var job: Job = _done[_done.keys()[0]]
		_done.erase(job.coord)
		if needed.has(job.coord) and not _views.has(job.coord):
			_attach(job)
			budget -= 1


func clear() -> void:
	_wait_all()
	for view in _views.values():
		remove_child(view)
		view.queue_free()
	_views.clear()
	_done.clear()
	_cache.clear()
	_deposit_index.clear()


func _exit_tree() -> void:
	_wait_all()


func _in_world(coord: Vector2i) -> bool:
	return (
		coord.x >= -_half_chunks
		and coord.x < _half_chunks
		and coord.y >= -_half_chunks
		and coord.y < _half_chunks
	)


func _focus_coords(focus_points: Array[Vector3]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for point in focus_points:
		result.append(ChunkGenerator.coord_of(point, _chunk_size))
	return result


func _gap(coord: Vector2i, foci: Array[Vector2i]) -> int:
	var best := 1 << 30
	for focus in foci:
		best = mini(best, maxi(absi(coord.x - focus.x), absi(coord.y - focus.y)))
	return best


func _start(coord: Vector2i) -> void:
	var job := Job.new()
	job.coord = coord
	job.task = WorkerThreadPool.add_task(_generate.bind(job))
	_jobs[coord] = job


## Se ejecuta en un hilo: solo datos puros, nunca el arbol de escena.
func _generate(job: Job) -> void:
	job.data = ChunkGenerator.generate(_world_seed, _region, _settings, job.coord)
	job.arrays = ChunkView.mesh_arrays(job.data)


func _collect() -> void:
	for coord in _jobs.keys():
		var job: Job = _jobs[coord]
		if WorkerThreadPool.is_task_completed(job.task):
			WorkerThreadPool.wait_for_task_completion(job.task)
			_jobs.erase(coord)
			_done[coord] = job


func _wait_all() -> void:
	for job: Job in _jobs.values():
		WorkerThreadPool.wait_for_task_completion(job.task)
	_jobs.clear()


func _attach(job: Job) -> void:
	var view := ChunkView.new()
	view.name = "Chunk_%d_%d" % [job.coord.x, job.coord.y]
	view.rock_radius = float(_settings.rock_radius)
	view.build(job.data, _soil, job.arrays)
	add_child(view)
	_views[job.coord] = view
	for deposit in job.data.deposits:
		var key := LunarMission.deposit_key(job.coord, int(deposit.id))
		_sim.register_deposit(key, deposit.kind, int(deposit.capacity), bool(deposit.near_base))
		_deposit_index[key] = {"coord": job.coord, "id": int(deposit.id)}
		view.set_deposit(int(deposit.id), _sim.deposit_left(key))


func _unload(foci: Array[Vector2i]) -> void:
	var limit := int(_settings.unload_radius)
	for coord in _views.keys():
		if _gap(coord, foci) <= limit:
			continue
		var view: ChunkView = _views[coord]
		_views.erase(coord)
		for deposit in view.data.deposits:
			_deposit_index.erase(LunarMission.deposit_key(coord, int(deposit.id)))
		_cache.erase(coord)
		_cache[coord] = view.data
		while _cache.size() > CACHE_LIMIT:
			_cache.erase(_cache.keys()[0])
		remove_child(view)
		view.queue_free()


func _on_deposit_changed(key: StringName, left: int) -> void:
	var entry: Dictionary = _deposit_index.get(key, {})
	var view: ChunkView = _views.get(entry.get("coord", Vector2i.ZERO))
	if view != null and not entry.is_empty():
		view.set_deposit(int(entry.id), left)


## Pared invisible a 1 m del borde: cuatro cajas en la capa 1.
func _build_wall() -> void:
	if _wall != null:
		_wall.queue_free()
	_wall = StaticBody3D.new()
	_wall.name = "ParedDelMundo"
	_wall.collision_layer = 1
	var reach := float(_settings.world_size) * 0.5 + 1.0
	var length := float(_settings.world_size) + 2.0 * (1.0 + WALL_THICKNESS)
	var middle := reach + WALL_THICKNESS * 0.5
	var sides := [
		[Vector3(middle, 0.0, 0.0), Vector3(WALL_THICKNESS, WALL_HEIGHT, length)],
		[Vector3(-middle, 0.0, 0.0), Vector3(WALL_THICKNESS, WALL_HEIGHT, length)],
		[Vector3(0.0, 0.0, middle), Vector3(length, WALL_HEIGHT, WALL_THICKNESS)],
		[Vector3(0.0, 0.0, -middle), Vector3(length, WALL_HEIGHT, WALL_THICKNESS)],
	]
	for side in sides:
		var shape := BoxShape3D.new()
		shape.size = side[1]
		var owner_id := _wall.create_shape_owner(_wall)
		_wall.shape_owner_add_shape(owner_id, shape)
		_wall.shape_owner_set_transform(owner_id, Transform3D(Basis.IDENTITY, side[0]))
	add_child(_wall)


class Job:
	extends RefCounted
	var coord := Vector2i.ZERO
	var task := -1
	var data: ChunkData
	var arrays: Array = []
