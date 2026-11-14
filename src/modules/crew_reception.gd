class_name CrewReception
extends RefCounted

enum Status { SCHEDULED, WAITING, STAYING, SERVED, MISSED }

var waves: Array[Dictionary] = []
var rules: Dictionary = {}
var guests := 0
var served := 0


func setup(config: Dictionary, practice: bool) -> void:
	rules = config
	var schedule: Array = config.waves
	if practice:
		schedule = [
			{
				"name": "Cadetes",
				"size": 2,
				"arrival": 0,
				"stay": 0,
				"deadline": 1,
				"needs_crop": false
			}
		]
	for wave: Dictionary in schedule:
		var entry := wave.duplicate()
		entry.merge({"status": Status.SCHEDULED, "departure": 0, "assigned": []})
		waves.append(entry)


func tick(minute: int, bay: ConstructionBay) -> void:
	for wave in waves:
		match int(wave.status):
			Status.SCHEDULED:
				if minute >= int(wave.arrival):
					wave.status = Status.WAITING
					EventBus.message_posted.emit(
						"Llegó %s. Revisa camas y reservas." % wave.name, false
					)
			Status.WAITING:
				if minute > int(wave.deadline):
					wave.status = Status.MISSED
					EventBus.message_posted.emit(
						"%s perdió su ventana de recepción." % wave.name, true
					)
			Status.STAYING:
				if minute >= int(wave.departure):
					wave.status = Status.SERVED
					guests -= int(wave.size)
					served += 1
					ResourceManager.adjust(&"water", float(rules.resupply_water))
					bay.materials += int(rules.resupply_materials)
					EventBus.message_posted.emit(
						"%s partió. Dejó agua y materiales." % wave.name, false
					)


func waiting() -> Dictionary:
	for wave in waves:
		if wave.status == Status.WAITING:
			return wave
	return {}


func free_berths(bay: ConstructionBay) -> int:
	return free_beds(bay).size()


func free_beds(bay: ConstructionBay) -> Array[Vector2i]:
	var taken := {}
	for wave in waves:
		if wave.status == Status.STAYING:
			for cell: Vector2i in wave.assigned:
				taken[cell] = int(taken.get(cell, 0)) + 1
	var beds: Array[Vector2i] = []
	for piece in bay.pieces:
		if piece.kind != &"habitat" or not piece.complete:
			continue
		var area: Rect2i = piece.area
		for index in range(int(rules.berths_per_habitat) - int(taken.get(area.position, 0))):
			beds.append(area.position)
	return beds


func status(bay: ConstructionBay, powered: bool, crop_ready: bool) -> String:
	var wave := waiting()
	if wave.is_empty():
		return "No hay tripulaciones en espera."
	if free_berths(bay) < int(wave.size):
		return "Construye un hábitat con %d camas libres." % int(wave.size)
	if not powered:
		return "Restablece el soporte vital y revisa el filtro."
	if wave.needs_crop and not crop_ready:
		return "Completa el cultivo para recibir a %s." % wave.name
	for key: String in rules.minimum_reserves:
		if ResourceManager.amount(StringName(key)) < float(rules.minimum_reserves[key]):
			var names := {"o2": "oxígeno", "water": "agua", "energy": "batería"}
			return "No alcanza la reserva de %s." % names[key]
	return ""


func admit(minute: int, bay: ConstructionBay) -> void:
	var wave := waiting()
	wave.assigned = free_beds(bay).slice(0, int(wave.size))
	wave.status = Status.STAYING
	wave.departure = minute + int(wave.stay)
	guests += int(wave.size)


func report(minute: int) -> String:
	var queued := waiting()
	if not queued.is_empty():
		return "%s espera %d min" % [queued.name, maxi(0, int(queued.deadline) - minute)]
	for wave in waves:
		match int(wave.status):
			Status.SCHEDULED:
				return "%s llega en %d min" % [wave.name, int(wave.arrival) - minute]
			Status.STAYING:
				return "%s sale en %d min" % [wave.name, int(wave.departure) - minute]
	return "%d de %d atendidas" % [served, waves.size()]
