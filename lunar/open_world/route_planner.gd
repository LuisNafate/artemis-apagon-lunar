class_name RoutePlanner
extends RefCounted

## Decide como llega el piloto a un punto tocado.
## - Origen y destino dentro del rectangulo plano de la base: LunarRoutes (rejilla sondeada).
## - Un extremo en la base y el otro fuera: la ruta cruza el muro por la puerta. LunarRoutes
##   dentro hasta la puerta; fuera, OpenRoutes desde la puerta si el punto esta a
##   <= `tap_route_radius` y dentro de la ventana cargada, y si no, linea recta.
## - Los dos fuera, a <= `tap_route_radius` y dentro de la ventana cargada: OpenRoutes.
## - Los dos fuera y mas lejos (o sin ruta): linea recta, un unico punto.

var open := OpenRoutes.new()
var _streamer: ChunkStreamer
var _loaded_hash := 0
var _dirty := true


## Solo anota que cambiaron los chunks cargados; la rejilla se reconstruye al tocar (`plan`),
## nunca mientras se camina.
func update(streamer: ChunkStreamer) -> void:
	_streamer = streamer
	var coords := streamer.loaded_coords()
	coords.sort()
	var loaded_hash := coords.hash()
	if loaded_hash != _loaded_hash:
		_loaded_hash = loaded_hash
		_dirty = true


func plan(
	base: LunarRoutes, start: Vector3, end: Vector3, settings: Dictionary
) -> PackedVector2Array:
	var flat := BaseEnclosure.flat_rect(settings)
	var start_in := flat.has_point(Vector2(start.x, start.z))
	var end_in := flat.has_point(Vector2(end.x, end.z))
	if start_in and end_in:
		return base.path(start, end)
	if start_in or end_in:
		return _through_door(base, start, end, start_in, settings)
	return _outside(start, end, settings)


## Entra o sale por la puerta: dentro, LunarRoutes hasta un punto antes de ella; fuera, la
## ruta abierta desde otro punto despues de ella.
func _through_door(
	base: LunarRoutes, start: Vector3, end: Vector3, start_in: bool, settings: Dictionary
) -> PackedVector2Array:
	var door := BaseEnclosure.door_at(settings)
	var gate := Vector3(float(settings.base_wall.gate_distance), 0.0, 0.0)
	var door2 := Vector2(door.x, door.z)
	var result := PackedVector2Array()
	if start_in:
		result = base.path(start, door - gate)
		result.append(door2)
		result.append_array(_outer_leg(door + gate, end, settings))
	else:
		result = _outer_leg(start, door + gate, settings)
		result.append(door2)
		result.append_array(base.path(door - gate, end))
	return result


## Tramo de fuera entre un punto y la puerta (en cualquier sentido, `a` -> `b`): ruta abierta
## si es corto y esta cargado; si no, linea recta al extremo.
func _outer_leg(a: Vector3, b: Vector3, settings: Dictionary) -> PackedVector2Array:
	var straight := PackedVector2Array([Vector2(b.x, b.z)])
	var path := _open_path(a, b, settings)
	return path if not path.is_empty() else straight


func _outside(start: Vector3, end: Vector3, settings: Dictionary) -> PackedVector2Array:
	var path := _open_path(start, end, settings)
	return path if not path.is_empty() else PackedVector2Array([Vector2(end.x, end.z)])


## Ruta de OpenRoutes entre dos puntos de fuera; vacia si estan lejos, sin chunks o sin camino.
func _open_path(a: Vector3, b: Vector3, settings: Dictionary) -> PackedVector2Array:
	var radius := float(settings.tap_route_radius)
	if _streamer == null or Vector2(b.x - a.x, b.z - a.z).length() > radius:
		return PackedVector2Array()
	open.prepare(_streamer, a, radius, float(settings.chunk_size), _dirty)
	_dirty = false
	if not (open.covers(a) and open.covers(b)):
		return PackedVector2Array()
	return open.path(a, b)
