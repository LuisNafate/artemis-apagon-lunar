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
	return _outer_leg(start, end, settings)


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
		result.append(Vector2(door.x + gate.x, door.z))
		result.append_array(_outer_leg(door + gate, end, settings))
	else:
		result = _outer_leg(start, door + gate, settings)
		result.append(Vector2(door.x + gate.x, door.z))
		result.append(door2)
		result.append_array(base.path(door - gate, end))
	return result


## Tramo de fuera entre dos puntos (`a` -> `b`, sin `a`): ruta abierta si es corto y esta
## cargado; si no, linea recta que rodea el muro.
func _outer_leg(a: Vector3, b: Vector3, settings: Dictionary) -> PackedVector2Array:
	var path := _open_path(a, b, settings)
	return path if not path.is_empty() else _around(a, b, settings)


## Ruta de OpenRoutes entre dos puntos de fuera; vacia si estan lejos, sin chunks o sin camino.
## La rejilla trata la base con su muro como solida: la ruta la rodea.
func _open_path(a: Vector3, b: Vector3, settings: Dictionary) -> PackedVector2Array:
	var radius := float(settings.tap_route_radius)
	if _streamer == null or Vector2(b.x - a.x, b.z - a.z).length() > radius:
		return PackedVector2Array()
	var keep := _keep_out(settings, 0.6)
	if open.blocked.is_empty() or open.blocked[0] != keep:
		open.blocked = [keep]
		_dirty = true
	open.prepare(_streamer, a, radius, float(settings.chunk_size), _dirty)
	_dirty = false
	if not (open.covers(a) and open.covers(b)):
		return PackedVector2Array()
	return open.path(a, b)


## Recta de `a` a `b` (sin `a`); si cruza el muro, pasa por las esquinas de la base, a mas de
## `margin` del muro, por el lado mas corto.
func _around(a: Vector3, b: Vector3, settings: Dictionary) -> PackedVector2Array:
	var from := Vector2(a.x, a.z)
	var to := Vector2(b.x, b.z)
	var wall := _keep_out(settings, -0.01)
	if not _clips(wall, from, to):
		return PackedVector2Array([to])
	var keep := _keep_out(settings, 0.7)
	var corners: Array[Vector2] = [
		keep.position,
		Vector2(keep.end.x, keep.position.y),
		keep.end,
		Vector2(keep.position.x, keep.end.y)
	]
	var best := PackedVector2Array([to])
	var best_length := INF
	for first in range(4):
		for last in range(4):
			var route := PackedVector2Array([corners[first]])
			if last != first:
				route.append(corners[last])
			route.append(to)
			var length := 0.0
			var at := from
			var clear := true
			for point in route:
				clear = clear and not _clips(wall, at, point)
				length += at.distance_to(point)
				at = point
			if clear and length < best_length:
				best = route
				best_length = length
	return best


## Rectangulo del muro (plataforma mas grosor del muro) crecido en `margin`.
func _keep_out(settings: Dictionary, margin: float) -> Rect2:
	return BaseEnclosure.flat_rect(settings).grow(float(settings.base_wall.thickness) + margin)


## El segmento `p`-`q` atraviesa el interior de `rect` (Liang-Barsky).
static func _clips(rect: Rect2, p: Vector2, q: Vector2) -> bool:
	var low := 0.0
	var high := 1.0
	var delta := q - p
	for axis in range(2):
		var start := p[axis]
		var edges: Array[float] = [rect.position[axis], rect.end[axis]]
		if absf(delta[axis]) < 0.000001:
			if start <= edges[0] or start >= edges[1]:
				return false
			continue
		var near := (edges[0] - start) / delta[axis]
		var far := (edges[1] - start) / delta[axis]
		low = maxf(low, minf(near, far))
		high = minf(high, maxf(near, far))
	return high - low > 0.000001
