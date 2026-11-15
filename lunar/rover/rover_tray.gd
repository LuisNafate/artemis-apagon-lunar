class_name RoverTray
extends RefCounted

## Bandeja de carga del rover: tipos de caja guardados en `LunarMission.rover.tray`. Cargar
## consume la caja suelta o la de la mano; descargar entrega en el refinado (misma ruta que el
## astronauta) o deja una caja en el suelo.

const DELIVERABLE: Array[StringName] = [&"ice", &"ore"]


static func capacity() -> int:
	return int(RoverSpec.data.tray_capacity)


static func kinds(mission: LunarMission) -> Array:
	return mission.rover.tray


static func count(mission: LunarMission) -> int:
	return kinds(mission).size()


static func full(mission: LunarMission) -> bool:
	return count(mission) >= capacity()


static func status(mission: LunarMission) -> String:
	return "Bandeja %d/%d" % [count(mission), capacity()]


## Hay una caja que el refinado acepta (hielo o mineral).
static func deliverable(mission: LunarMission) -> bool:
	return kinds(mission).any(func(kind: Variant) -> bool: return StringName(kind) in DELIVERABLE)


## Una caja suelta al alcance del rover pasa a la bandeja.
static func load_ground(mission: LunarMission, id: int) -> String:
	if not mission.crates.has(id) or mission.crates[id].owner != -1:
		return ""
	if full(mission):
		return "La bandeja está llena"
	var kind: StringName = mission.crates[id].kind
	mission.crates.erase(id)
	kinds(mission).append(kind)
	return "Caja en la bandeja · %s" % status(mission)


## La caja en la mano del astronauta pasa a la bandeja.
static func load_hand(mission: LunarMission, player: int) -> String:
	if full(mission):
		return "La bandeja está llena"
	kinds(mission).append(mission.cargo_kind(player))
	mission._consume_cargo(player)
	return "Caja en la bandeja · %s" % status(mission)


## Descarga en el refinado: cada caja entra como si la entregara el astronauta. Si el refinado
## la rechaza (ocupado, sin energía) se queda en la bandeja y se dice por qué.
static func unload_refinery(mission: LunarMission, player: int) -> String:
	var message := "Nada que descargar aquí"
	var tried: Array[StringName] = []
	for kind: Variant in kinds(mission).duplicate():
		var name := StringName(kind)
		if name not in DELIVERABLE or name in tried:
			continue
		tried.append(name)
		mission._create_cargo(player, name)
		message = mission._refine(player)
		if mission.cargo_kind(player) == &"":
			kinds(mission).erase(kind)
			return message
		mission._consume_cargo(player)
	return message


## Deja la caja de arriba de la bandeja en el suelo.
static func drop(mission: LunarMission, point: Vector3) -> String:
	if kinds(mission).is_empty():
		return "La bandeja está vacía"
	mission.spawn_crate(StringName(kinds(mission).pop_back()), point)
	return "Caja en el suelo"
