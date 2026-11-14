extends Node3D

const INTERACT_REACH := 2.5
const SPAWN := Vector3(0, 0.1, 11)
const CAMERA_OFFSET := Vector3(0, 8.0, 12.9)

var sim := FieldSim.new()
var world: FieldWorld
var pilot: FieldPilot
var hud: FieldHUD
var camera: Camera3D
var checkpoint := SPAWN
var _jump := false
var _dash := false
var _interact := false
var _last_storm := false
var _previous_harvest := 0
var _feedback_left := 0.0
var _tone: AudioStreamPlayer
var _trail: Array[MeshInstance3D] = []
var _trail_clock := 0.0


func _ready() -> void:
	world = FieldWorld.new()
	add_child(world)
	world.build()
	pilot = FieldPilot.new()
	add_child(pilot)
	pilot.position = SPAWN
	pilot.build()
	camera = Camera3D.new()
	camera.fov = 58
	camera.far = 390
	add_child(camera)
	camera.position = pilot.position + CAMERA_OFFSET
	camera.look_at(pilot.position + Vector3(0, 0.3, -3.2))
	camera.make_current()
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = FieldHUD.new()
	layer.add_child(hud)
	hud.build()
	hud.restart_requested.connect(restart)
	_tone = AudioStreamPlayer.new()
	_tone.volume_db = -13
	add_child(_tone)
	for index in range(9):
		var speck := FieldWorld.box(world, Vector3.ZERO, Vector3.ONE * 0.15, FieldWorld.CYAN, true)
		speck.hide()
		_trail.append(speck)
	_refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_SPACE:
			_jump = true
		KEY_SHIFT:
			_dash = true
		KEY_E:
			_interact = true
		KEY_R:
			restart()
		_:
			return
	get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	var axis := (
		Vector2(
			(
				float(
					Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)
				)
				- float(
					Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)
				)
			),
			(
				float(
					Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)
				)
				- float(
					Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)
				)
			)
		)
		. limit_length()
	)
	step(delta, axis, _jump, _dash, _interact)
	_jump = false
	_dash = false
	_interact = false


func step(delta: float, axis: Vector2, jump: bool, dash: bool, use: bool) -> void:
	if sim.finished():
		return
	var turbo_started := dash and pilot.dash_cooldown <= 0.0
	pilot.drive(delta, axis, jump, dash)
	if turbo_started:
		_chime([265.0, 465.0, 825.0])
	_update_trail(delta)
	if pilot.is_on_floor() and pilot.position.y >= -0.05:
		var point := pilot.position
		if absf(point.x) > 12.65 or point.z < -1.65 or point.z > 3.65:
			checkpoint = Vector3(point.x, 0.1, point.z)
	if pilot.position.y < -2.8:
		_fall()
	if use and not sim.finished():
		try_interact()
	sim.advance(delta, sheltered())
	if sim.storm_active() and not _last_storm:
		_notice("Alerta solar", FieldHUD.RED, [540.0, 412.0, 540.0])
	if sim.harvested > _previous_harvest:
		_notice("¡Cosecha lista!", FieldHUD.MINT, [460.0, 620.0, 840.0])
	_previous_harvest = sim.harvested
	_last_storm = sim.storm_active()
	_feedback_left = maxf(0.0, _feedback_left - delta)
	if _feedback_left == 0.0:
		hud.feedback.text = ""
	_follow_camera(delta)
	_refresh()
	if sim.finished():
		var title := "Puesto a salvo" if sim.won else "Misión interrumpida"
		if sim.won and sim.elapsed < 35.0 and sim.dose <= 10.0:
			title = "Oro · Puesto a salvo"
		var report := "2 cosechas · %0.1f s · %d%% exposición" % [sim.elapsed, roundi(sim.dose)]
		hud.finish(title, report if sim.won else sim.failure, sim.won)
		_chime([480.0, 640.0, 890.0] if sim.won else [360.0, 250.0])


func try_interact() -> bool:
	var candidate := _near_action()
	if candidate.is_empty():
		return false
	var key: StringName = candidate.key
	if candidate.item and sim.pickup(key):
		world.set_item_visible(key, false)
		_notice(
			"Batería recogida" if key == FieldSim.BATTERY else "Cápsula recogida",
			FieldHUD.GOLD if key == FieldSim.BATTERY else FieldHUD.MINT,
			[460.0, 620.0]
		)
		_refresh()
		return true
	var message := sim.use_station(key)
	if message.is_empty():
		return false
	_notice(message, FieldHUD.MINT, [440.0, 550.0, 730.0])
	_refresh()
	return true


func sheltered() -> bool:
	var point: Vector3 = pilot.position - FieldWorld.STATIONS.shelter
	return absf(point.x) < 2.0 and point.z > -1.9 and point.z < 1.36 and point.y < 2.1


func restart() -> void:
	get_tree().reload_current_scene()


func _fall() -> void:
	var item := sim.fall()
	pilot.position = checkpoint
	pilot.velocity = Vector3.ZERO
	pilot.dash_left = 0.0
	if not item.is_empty():
		world.drop(item, checkpoint)
	var notice := "Caída · aire −14" if sim.online else "Salta la grieta. Usa Shift en el aire."
	_notice(notice, FieldHUD.RED, [240.0, 170.0])


func _near_action() -> Dictionary:
	if sim.finished():
		return {}
	var target := _target()
	if target in FieldWorld.ITEMS and not target.is_empty():
		var prop: Node3D = world.props[target]
		if pilot.position.distance_to(prop.position) <= INTERACT_REACH:
			return {
				"key": target,
				"item": true,
				"label": "Recoger batería" if target == FieldSim.BATTERY else "Recoger cápsula"
			}
	for key: StringName in FieldWorld.STATIONS:
		var point: Vector3 = FieldWorld.STATIONS[key]
		if pilot.position.distance_to(point) > INTERACT_REACH:
			continue
		var label := _station_action(key)
		if not label.is_empty():
			return {"key": key, "item": false, "label": label}
	return {}


func _station_action(key: StringName) -> String:
	match key:
		&"generator":
			if sim.cargo == FieldSim.BATTERY:
				return "Encajar batería"
			if sim.online and sim.elapsed >= sim.next_recharge and sim.charge < 90.0:
				return "Recargar red +35"
		&"farm":
			if sim.cargo in FieldSim.SEEDS:
				return "Plantar cápsula"
		&"shelter":
			if sheltered() and sim.harvested == 2:
				return "Cerrar misión"
	return ""


func _target() -> StringName:
	if not sim.online:
		return &"generator" if sim.cargo == FieldSim.BATTERY else FieldSim.BATTERY
	if sim.storm_active() or sim.harvested == 2:
		return &"shelter"
	if sim.charge < 18.0 and sim.elapsed >= sim.next_recharge:
		return &"generator"
	if sim.cargo in FieldSim.SEEDS:
		return &"farm"
	var nearest: StringName = &"farm"
	var distance := INF
	for seed: StringName in FieldSim.SEEDS:
		if sim.delivered.has(seed):
			continue
		var prop: Node3D = world.props[seed]
		var range_to := pilot.position.distance_squared_to(prop.position)
		if range_to < distance:
			distance = range_to
			nearest = seed
	return nearest


func _refresh() -> void:
	var target := _target()
	world.highlight(target)
	world.update_power(sim.online, sim.charge, sim.harvested)
	pilot.carrying.visible = not sim.cargo.is_empty()
	var block: MeshInstance3D = pilot.carrying.get_child(0)
	var tint := FieldWorld.AMBER if sim.cargo == FieldSim.BATTERY else FieldWorld.MINT
	block.material_override.albedo_color = tint
	block.material_override.emission = tint
	hud.update_telemetry(sim, sheltered())
	_set_objective(target)
	var prompt := _near_action()
	hud.action.text = "[E]  " + String(prompt.label) if not prompt.is_empty() else ""
	_follow_marker(target)


func _set_objective(target: StringName) -> void:
	var title := ""
	var hint := ""
	match target:
		&"battery":
			title = "Recoge la batería"
			hint = "Avanza con W. Recoge la batería con E."
		&"generator":
			title = "Dale energía al puesto" if not sim.online else "Recarga la red"
			hint = (
				"Salta en el borde. Pulsa Shift en el aire."
				if not sim.online
				else "Usa el generador para recuperar 35."
			)
		&"farm":
			title = "Planta la cápsula" if not sim.cargo.is_empty() else "Espera la cosecha"
			hint = (
				"Busca la baliza verde."
				if not sim.cargo.is_empty()
				else "Mantén la red activa para que crezcan."
			)
		&"shelter":
			title = "Cúbrete de la tormenta" if sim.storm_active() else "Vuelve al refugio"
			hint = "El techo bloquea la exposición y repone aire."
		_:
			title = "Busca una cápsula"
			hint = "Sigue la baliza verde. Solo puedes llevar una."
	hud.objective.text = title
	hud.detail.text = hint


func _follow_camera(delta: float) -> void:
	var base := pilot.position
	base.y = maxf(0.0, base.y * 0.56)
	var goal := base + CAMERA_OFFSET
	camera.position = camera.position.lerp(goal, minf(delta * 7.0, 1.0))
	camera.look_at(camera.position - CAMERA_OFFSET + Vector3(0, 0.3, -3.2))


func _update_trail(delta: float) -> void:
	_trail_clock -= delta
	if pilot.dash_left > 0.0 and _trail_clock <= 0.0:
		_trail_clock = 0.027
		var speck: MeshInstance3D = _trail.pop_front()
		_trail.append(speck)
		speck.position = pilot.position - pilot.direction * 0.65 + Vector3.UP * 0.76
		speck.scale = Vector3.ONE * 1.7
		speck.show()
	for speck in _trail:
		if speck.visible:
			speck.scale *= maxf(0.0, 1.0 - delta * 8.0)
			if speck.scale.x < 0.13:
				speck.hide()


func _follow_marker(target: StringName) -> void:
	var labels := {
		&"battery": "BATERÍA",
		&"generator": "GENERADOR",
		&"farm": "INVERNADERO",
		&"shelter": "REFUGIO",
		&"seed_a": "CÁPSULA",
		&"seed_b": "CÁPSULA"
	}
	var point: Vector3
	if FieldWorld.ITEMS.has(target):
		point = world.props[target].global_position
	else:
		point = FieldWorld.STATIONS[target]
	var projected := Vector2(640, 622)
	var mode := ""
	if not camera.is_position_behind(point + Vector3.UP * 1.7):
		projected = camera.unproject_position(point + Vector3.UP * 1.7)
		var edge := clampf(projected.x, 113, 1167)
		if projected.x != edge:
			mode = "‹ " if projected.x < edge else "› "
	else:
		mode = "↓ "
	projected.x = clampf(projected.x, 113, 1167)
	projected.y = clampf(projected.y, 169, 623)
	var range_to := roundi(pilot.position.distance_to(point))
	var color := FieldHUD.MINT if target in FieldSim.SEEDS or target == &"farm" else FieldHUD.GOLD
	hud.mark("%s%s · %dm" % [mode, labels[target], range_to], projected, color)


func _notice(message: String, tint: Color, notes: Array) -> void:
	_feedback_left = 2.4
	hud.feedback.text = message
	hud.pulse(tint)
	_chime(notes)


func _chime(notes: Array) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var rate := 16000
	var count := 1120
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	var data := PackedByteArray()
	data.resize(2 * count * notes.size())
	for index in range(notes.size()):
		for sample in range(count):
			var envelope := sin(PI * float(sample) / count)
			var tone := sin(TAU * float(notes[index]) * sample / rate) * envelope
			data.encode_s16((index * count + sample) * 2, roundi(tone * 12500))
	stream.data = data
	_tone.stream = stream
	_tone.play()
