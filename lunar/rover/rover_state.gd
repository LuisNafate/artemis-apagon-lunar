class_name RoverState
extends RefCounted

## Reglas del rover sobre el estado guardado en `LunarMission.rover`. Entregas, desbloqueo,
## conductor y radio; no sabe nada de fisica ni de nodos.

const KINDS: Array[StringName] = [&"ore", &"ice"]


static func fresh() -> Dictionary:
	return {
		"unlocked": false,
		"delivered": {"ore": 0, "ice": 0},
		"position": RoverSpec.park_point(),
		"yaw": RoverSpec.park_yaw(),
		"driver": -1,
		"tray": []
	}


static func need(kind: StringName) -> int:
	return int(RoverSpec.data.unlock[String(kind)])


static func delivered(mission: LunarMission, kind: StringName) -> int:
	return int(mission.rover.delivered[String(kind)])


static func driving(mission: LunarMission, player: int) -> bool:
	return int(mission.rover.driver) == player


## Aparcado: sin conductor y a menos de `park_radius` de su sitio.
static func parked(mission: LunarMission) -> bool:
	if int(mission.rover.driver) != -1:
		return false
	var spot := RoverSpec.park_point()
	var at: Vector3 = mission.rover.position
	return Vector2(at.x - spot.x, at.z - spot.z).length() <= float(RoverSpec.data.park_radius)


## Bloqueado, la radio siempre funciona; desbloqueado, solo con el rover aparcado.
static func radio_available(mission: LunarMission) -> bool:
	return not mission.rover.unlocked or parked(mission)


static func progress(mission: LunarMission) -> String:
	return (
		"Mineral %d/%d · Hielo %d/%d"
		% [delivered(mission, &"ore"), need(&"ore"), delivered(mission, &"ice"), need(&"ice")]
	)


## Una caja de este tipo cuenta para el desbloqueo.
static func accepts(mission: LunarMission, kind: StringName) -> bool:
	return not mission.rover.unlocked and kind in KINDS and delivered(mission, kind) < need(kind)


static func deliver(mission: LunarMission, player: int) -> String:
	var kind := mission.cargo_kind(player)
	if mission.rover.unlocked:
		return "El rover ya está desbloqueado"
	if not accepts(mission, kind):
		return "El rover no necesita esta caja"
	mission._consume_cargo(player)
	mission.rover.delivered[String(kind)] += 1
	if all_delivered(mission):
		mission.rover.unlocked = true
		return "¡Rover desbloqueado! Ya puedes conducirlo."
	return "Entregada al rover · %s" % progress(mission)


static func all_delivered(mission: LunarMission) -> bool:
	return KINDS.all(func(kind: StringName) -> bool: return delivered(mission, kind) >= need(kind))


## Accion sobre el rover: bajar, enviar la lista (bloqueado) o subir (desbloqueado).
static func use(mission: LunarMission, player: int) -> String:
	if driving(mission, player):
		mission.rover.driver = -1
		return "Bajaste del rover"
	if not mission.rover.unlocked:
		return mission.use_station(player, &"radio")
	if int(mission.rover.driver) != -1:
		return "Tu compañero conduce el rover"
	if mission.cargo_kind(player) != &"":
		return "Suelta la caja antes de subir al rover"
	mission.rover.driver = player
	mission.pilots[player].mine = &""
	return "Al volante · el joystick conduce"


## El astronauta se baja si se desconecta o si el estado se restaura (aire agotado).
static func release_driver(mission: LunarMission) -> void:
	mission.rover.driver = -1
