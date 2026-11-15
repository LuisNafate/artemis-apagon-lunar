class_name RoutePlanner
extends RefCounted

## Decide como llega el piloto a un punto tocado.
## - Origen y destino dentro del rectangulo plano de la base: LunarRoutes (rejilla sondeada).
## - Resto, con el destino a <= `tap_route_radius` y dentro de la ventana cargada: OpenRoutes.
##   Si un extremo esta en la base y el otro fuera, la ruta pasa por el punto del borde plano
##   mas cercano al extremo exterior: LunarRoutes dentro, OpenRoutes fuera.
## - Destino mas lejos (o sin ruta): linea recta, un unico punto; si el destino esta en la base,
##   LunarRoutes como siempre (el piloto cruza en recta hasta la rejilla y sigue la ruta).

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
	var values: Array = settings.base_flat_rect
	var flat := Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))
	var start_in := flat.has_point(Vector2(start.x, start.z))
	var end_in := flat.has_point(Vector2(end.x, end.z))
	if start_in and end_in:
		return base.path(start, end)
	# Sin ruta abierta: dentro de la base sigue valiendo LunarRoutes (como antes); fuera, recta.
	var straight := base.path(start, end) if end_in else PackedVector2Array([Vector2(end.x, end.z)])
	var radius := float(settings.tap_route_radius)
	if Vector2(end.x - start.x, end.z - start.z).length() > radius:
		return straight
	if _streamer == null:
		return straight
	open.prepare(_streamer, start, radius, float(settings.chunk_size), _dirty)
	_dirty = false
	if not (open.covers(start) and open.covers(end)):
		return straight
	var result := PackedVector2Array()
	if start_in or end_in:
		var inner := start if start_in else end
		var outer := end if start_in else start
		var edge2 := _clamp(flat.grow(-open.cell_size()), Vector2(outer.x, outer.z))
		var edge := Vector3(edge2.x, 0.0, edge2.y)
		if start_in:
			result = base.path(inner, edge)
			result.append_array(open.path(edge, outer))
		else:
			result = open.path(outer, edge)
			result.append_array(base.path(edge, inner))
	else:
		result = open.path(start, end)
	return result if not result.is_empty() else straight


static func _clamp(rect: Rect2, point: Vector2) -> Vector2:
	return Vector2(
		clampf(point.x, rect.position.x, rect.end.x), clampf(point.y, rect.position.y, rect.end.y)
	)
