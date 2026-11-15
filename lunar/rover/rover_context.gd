class_name RoverContext
extends RefCounted

## Textos y reglas de los botones del panel junto al rover: [titulo, detalle, desactivado].


static func at(mission: LunarMission, player: int, spot: StringName) -> Array:
	if mission.driving(player):
		return driving(mission, &"")
	if spot == &"rover":
		return _unlocked(mission, player)
	if not mission.radio_available():
		return ["Radio sin rover", "Trae el rover a su sitio para usar la radio.", true]
	return radio(mission)


## Radio con el estado del desbloqueo mientras el rover sigue bloqueado.
static func radio(mission: LunarMission) -> Array:
	var context := LunarItemContext.radio(mission)
	if not mission.rover.unlocked:
		context[1] = "%s\n%s" % [context[1], RoverState.progress(mission)]
	return context


## Quien tiene una caja de ese tipo en la mano la entrega al rover bloqueado.
static func delivers(mission: LunarMission, player: int) -> bool:
	return RoverState.accepts(mission, mission.cargo_kind(player))


static func deliver_caption(cargo_name: String) -> String:
	return "Entregar %s al rover" % cargo_name


## Boton aparte para la radio cuando el rover esta desbloqueado y aparcado junto al astronauta.
static func radio_button(mission: LunarMission, player: int, spot: StringName) -> Array:
	var shown: bool = (
		spot == &"rover"
		and mission.rover.unlocked
		and mission.radio_available()
		and not mission.driving(player)
	)
	if not shown:
		return ["", "", true]
	return LunarItemContext.radio(mission)


static func _unlocked(mission: LunarMission, player: int) -> Array:
	var driver := int(mission.rover.driver)
	if driver != -1:
		return ["Subir al rover", "Tu compañero conduce.", true]
	if mission.cargo_kind(player) != &"":
		var tray := RoverTray.status(mission)
		if RoverTray.full(mission):
			return ["Subir al rover", "%s llena. Suelta la caja antes de subir." % tray, true]
		return ["Cargar en el rover", "Pon la caja en la bandeja · %s." % tray, false]
	var speed := float(RoverSpec.data.speed)
	return ["Subir al rover", "Conduce a unos %.0f m/s para explorar más lejos." % speed, false]


## Al volante: Cargar caja junto a una caja suelta si cabe; si no, Bajar con la bandeja.
static func driving(mission: LunarMission, pickup: StringName) -> Array:
	var tray := RoverTray.status(mission)
	if pickup != &"" and not RoverTray.full(mission):
		return ["Cargar caja", "Súbela a la bandeja · %s." % tray, false]
	var air := "El aire del traje sigue bajando: el rover no tiene presión."
	if RoverTray.full(mission):
		return ["Bajar del rover", "%s llena. %s" % [tray, air], false]
	return ["Bajar del rover", "%s. %s" % [tray, air], false]


## Boton de Soltar / Entregar del conductor: descargar en el refinado o soltar junto al rover.
static func unload_caption(mission: LunarMission, player: int, spot: StringName) -> String:
	if LunarItemContext.delivers(mission, player, spot):
		return "Descargar en Refinado"
	return "Soltar caja"
