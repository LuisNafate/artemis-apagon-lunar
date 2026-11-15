class_name RoverSpec
extends RefCounted

## Valores del rover de la base (`campaign_2026.rover` del registro), leidos una sola vez.

static var data: Dictionary = _load()


static func _load() -> Dictionary:
	var registry: Variant = JSON.parse_string(FileAccess.get_file_as_string(CrestSim.CONFIG_PATH))
	return registry.campaign_2026.rover


## Centro del rover aparcado.
static func park_point() -> Vector3:
	return _vector(data.park_point)


## Giro del rover aparcado (radianes, 0 = mira al norte).
static func park_yaw() -> float:
	return deg_to_rad(float(data.park_yaw_degrees))


## Punto de la estacion de radio: junto al rover aparcado, donde se para el astronauta.
static func stand_point() -> Vector3:
	var offset: Array = data.stand_offset
	return park_point() + Vector3(float(offset[0]), 0.0, float(offset[1]))


static func _vector(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[1]), float(values[2]))
