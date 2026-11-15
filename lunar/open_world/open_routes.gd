class_name OpenRoutes
extends RefCounted

## Rutas A* sobre las celdas transitables (0,5 m) de los chunks cargados. Las celdas de chunks
## no cargados cuentan como solidas, asi que la ruta nunca sale de la ventana cargada.
## Los puntos devueltos son centros de celda (offset de media celda).

const SEARCH := 3

## Cuantas veces se ha reconstruido la rejilla (las pruebas comprueban que caminar no cuesta).
var rebuilds := 0
var _grid := AStarGrid2D.new()
var _cell := 0.5
var _built := false
var _window := Rect2i()


## Reconstruye solo si hace falta: `force` (cambiaron los chunks cargados) o la ventana de
## `around` +- `reach` ya no es la de la rejilla actual.
func prepare(
	streamer: ChunkStreamer, around: Vector3, reach: float, chunk_size: float, force: bool
) -> void:
	if force or _window != _window_of(around, reach, chunk_size):
		rebuild(streamer, around, reach, chunk_size)


## Reconstruye la rejilla con los chunks cargados que solapan `around` +- `reach` (todos los
## cargados si no se da `around`), sin ocupar mas que los chunks que una ruta corta puede usar.
func rebuild(
	streamer: ChunkStreamer, around := Vector3.INF, reach := 0.0, chunk_size := 16.0
) -> void:
	_built = false
	rebuilds += 1
	_window = _window_of(around, reach, chunk_size)
	var coords := streamer.loaded_coords()
	var low := Vector2i(2147483647, 2147483647)
	var high := Vector2i(-2147483648, -2147483648)
	var datas: Array[ChunkData] = []
	for coord in coords:
		if around.is_finite() and not _window.has_point(coord):
			continue
		low = Vector2i(mini(low.x, coord.x), mini(low.y, coord.y))
		high = Vector2i(maxi(high.x, coord.x), maxi(high.y, coord.y))
		var data := streamer.data_at(coord)
		if data != null:
			datas.append(data)
	if datas.is_empty():
		return
	var per_chunk := roundi(sqrt(float(datas[0].walkable.size())))
	_cell = datas[0].size / float(per_chunk)
	var origin := low * per_chunk
	var span := (high - low + Vector2i.ONE) * per_chunk
	_grid.region = Rect2i(origin, span)
	_grid.cell_size = Vector2(_cell, _cell)
	_grid.offset = Vector2(_cell, _cell) * 0.5
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.update()
	# Todo solido salvo las celdas transitables de los chunks que tenemos.
	_grid.fill_solid_region(_grid.region, true)
	for data in datas:
		var base := data.coord * per_chunk
		for index in range(data.walkable.size()):
			if data.walkable[index] == 1:
				_grid.set_point_solid(base + Vector2i(index % per_chunk, index / per_chunk), false)
	_built = true


func cell_size() -> float:
	return _cell


func is_built() -> bool:
	return _built


## Hay una celda transitable cerca de `point` dentro de la ventana construida.
func covers(point: Vector3) -> bool:
	return _built and _near_cell(point) != Vector2i(-2147483648, 0)


func path(start: Vector3, end: Vector3) -> PackedVector2Array:
	if not _built:
		return PackedVector2Array()
	var from := _near_cell(start)
	var to := _near_cell(end)
	if from.x == -2147483648 or to.x == -2147483648:
		return PackedVector2Array()
	return _grid.get_point_path(from, to, true)


## Celda libre mas cercana (hasta SEARCH celdas); x = -2147483648 si no hay.
func _near_cell(point: Vector3) -> Vector2i:
	var cell := Vector2i((Vector2(point.x, point.z) / _cell).floor())
	var best := Vector2i(-2147483648, 0)
	var best_distance := INF
	for dx in range(-SEARCH, SEARCH + 1):
		for dz in range(-SEARCH, SEARCH + 1):
			var candidate := cell + Vector2i(dx, dz)
			if _grid.is_in_boundsv(candidate) and not _grid.is_point_solid(candidate):
				var distance := float(dx * dx + dz * dz)
				if distance < best_distance:
					best_distance = distance
					best = candidate
	return best


## Rectangulo de coordenadas de chunk que cubre `around` +- (`reach` + 2 m); vacio sin `around`.
func _window_of(around: Vector3, reach: float, chunk_size: float) -> Rect2i:
	if not around.is_finite():
		return Rect2i()
	var margin := Vector3(reach + 2.0, 0.0, reach + 2.0)
	var low := ChunkGenerator.coord_of(around - margin, chunk_size)
	var high := ChunkGenerator.coord_of(around + margin, chunk_size)
	return Rect2i(low, high - low + Vector2i.ONE)
