# gdlint: disable=max-returns
extends Node3D

const MOTION := [[KEY_A, KEY_D, KEY_W, KEY_S], [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]]
const CARGO_COLORS := {
	&"sample": CrestWorld.BLUE,
	&"ice": CrestWorld.BLUE,
	&"ore": CrestWorld.PURPLE,
	&"fuel": CrestWorld.AMBER,
	&"food": CrestWorld.LIME
}
const PASS_RADIUS := 2.35
const PICKUP_RADIUS := 1.12

var sim := CrestSim.new()
var world := CrestWorld.new()
var camera := Camera3D.new()
var hud := CrestHUD.new()
var intro := CrestIntro.new()
var pilots: Array[FieldPilot] = []
var crate_meshes: Dictionary = {}
var _spots: Array[StringName] = [&"", &""]
var _queued: Array[Vector2i] = []
var _pressed: Dictionary = {}
var _menu := &"lobby"
var _active_pilot := 0
var _intro_practice := false
var _bonus_announced := false
var _fault_announced := false
var _relay_announced := false
var _science_return := &""
var _science_index := 0
var _feedback := ""
var _feedback_left := 0.0
var _celebration := 0.0
var _tone := AudioStreamPlayer.new()
var _notes: Dictionary = {}
var _storm_alerted := false
var _shadow_alerted := false


func _ready() -> void:
	add_child(world)
	world.build()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 19.9
	camera.position = Vector3(7.8, 24.5, 22.8)
	add_child(camera)
	camera.look_at(Vector3(0.1, 0, 0.25))
	camera.make_current()
	for player in range(2):
		_add_pilot(player)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	canvas.add_child(hud)
	hud.build()
	hud.selected.connect(_choose)
	canvas.add_child(intro)
	intro.finished.connect(_finish_intro)
	add_child(_tone)
	_build_sounds()
	hud.menu(_menu, sim)
	_refresh(0.0)


func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
	if not event.pressed:
		_pressed.erase(key)
		return
	if event.echo:
		return
	var viewport := get_viewport()
	if _menu == &"intro":
		if key in [KEY_ESCAPE, KEY_SPACE, KEY_ENTER]:
			intro.skip()
		viewport.set_input_as_handled()
		return
	if _menu != &"" and _menu_input(key):
		viewport.set_input_as_handled()
	elif _menu == &"" and _crew_input(key, event.location):
		viewport.set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_pressed.clear()
		_queued.clear()
		if is_node_ready() and _menu == &"" and not sim.terminal():
			_show(&"paused")


func _physics_process(delta: float) -> void:
	if _menu == &"intro":
		world.animate_intro(intro.progress)
		var arrival := smoothstep(0.04, 0.31, intro.progress)
		var release := smoothstep(0.32, 0.59, intro.progress)
		camera.h_offset = -4.0 * arrival * (1.0 - release)
		camera.size = 19.9 - 3.6 * arrival * (1.0 - release)
		for pilot in pilots:
			pilot.visible = intro.progress >= 0.29
		return
	if _menu != &"":
		return
	if sim.terminal():
		_celebration -= delta
		_refresh(delta)
		if _celebration <= 0.0:
			_show(&"result")
		return
	for player in range(2):
		_move_player(player, delta)
		_spots[player] = world.nearest(
			pilots[player].position, sim.phase == &"tutorial", sim.campaign.supply_pending
		)
	for action in _queued:
		_interact(action.x, action.y == 1)
	_queued.clear()
	var protected: Array[bool] = [
		world.sheltered(pilots[0].position), world.sheltered(pilots[1].position)
	]
	sim.tick(delta, protected, _spots)
	if sim.energy_cut() and not _fault_announced:
		_notice("Avería solar · reserva la batería para el aire", &"warning")
	_fault_announced = sim.energy_cut()
	if sim.radio_cut() and not sim.shadow_active() and not _relay_announced:
		_notice("Radio sin señal · sigue preparando la nave", &"warning")
	_relay_announced = sim.radio_cut() and not sim.shadow_active()
	if sim.campaign.supply_pending and not _bonus_announced:
		_bonus_announced = true
		_notice("Llegaron suministros · recógelos junto al refugio", &"move")
	var warning := sim.storm_warning()
	var storm_announced := warning > 0.0 and warning <= float(sim.targets.storm_warning_seconds)
	if storm_announced and not _storm_alerted:
		_notice("Alerta solar · ubiquen el refugio azul", &"warning")
	_storm_alerted = storm_announced
	var night_announced := _night_warning()
	if night_announced and not _shadow_alerted:
		_notice("Se acerca la noche · revisen la batería", &"warning")
	_shadow_alerted = night_announced
	if sim.phase == &"success":
		_celebration = 2.3
		_notice("¡Despegue!", &"launch")
	_refresh(delta)


func _night_warning() -> bool:
	var left := (
		sim.campaign.next_night(sim.elapsed)
		if not sim.campaign.base.is_empty()
		else float(sim.runtime.shadow_start) - sim.elapsed
	)
	return left > 0.0 and left <= 12.0


func _add_pilot(player: int) -> void:
	var pilot := FieldPilot.new()
	pilot.name = "Astronauta%d" % (player + 1)
	pilot.collision_layer = 2
	pilot.collision_mask = 1
	pilot.position = CrestWorld.SPAWNS[player]
	add_child(pilot)
	pilot.build()
	pilot.scale = Vector3.ONE
	var tint := CrestWorld.BLUE if player == 0 else CrestWorld.AMBER
	var crew_badge := FieldWorld.box(
		pilot.rig, Vector3(0, 0.99, -0.223), Vector3(0.36, 0.12, 0.065), tint, true
	)
	crew_badge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pointer := Label3D.new()
	pointer.text = "● J1" if player == 0 else "◆ J2"
	pointer.position = Vector3(0, 1.95, 0)
	pointer.pixel_size = 0.021
	pointer.font = CrestWorld.MONO
	pointer.font_size = 29
	pointer.modulate = tint
	pointer.outline_size = 11
	pointer.no_depth_test = true
	pointer.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pilot.add_child(pointer)
	pilots.append(pilot)


func _move_player(player: int, delta: float) -> void:
	var pilot := pilots[player]
	if sim.pilots[player].seated:
		return
	var keys: Array = MOTION[player]
	if sim.solo:
		keys = MOTION[0] if player == _active_pilot else []
	if keys.is_empty():
		pilot.drive(delta, Vector2.ZERO, false, false)
		return
	var axis := (
		Vector2(
			int(_pressed.has(keys[1])) - int(_pressed.has(keys[0])),
			int(_pressed.has(keys[3])) - int(_pressed.has(keys[2]))
		)
		. limit_length()
	)
	var right := camera.basis.x
	var back := camera.basis.z
	right.y = 0.0
	back.y = 0.0
	var movement := right.normalized() * axis.x + back.normalized() * axis.y
	pilot.drive(delta, Vector2(movement.x, movement.z), false, false)


func _interact(player: int, release: bool) -> void:
	var pilot := pilots[player]
	if release:
		var partner_near := pilot.position.distance_to(pilots[1 - player].position) <= PASS_RADIUS
		var message := sim.release(player, pilot.position, partner_near)
		if not message.is_empty():
			_notice(message, &"move")
		return
	if sim.pilots[player].seated:
		var exit_message := sim.use_station(player, &"pad")
		pilot.position = CrestWorld.BOARDING[player]
		_notice(exit_message, &"move")
		return
	var id := _closest_crate(pilot.position) if sim.cargo_kind(player) == &"" else 0
	if id != 0 and sim.pickup(player, id):
		_notice("Caja recogida", &"move")
		return
	if _spots[player] == &"":
		_notice("Acércate a una estación o a una caja", &"")
		return
	var reply := sim.use_station(player, _spots[player])
	if sim.pilots[player].seated:
		pilot.position = CrestWorld.BOARDING[player]
		pilot.velocity = Vector3.ZERO
	_notice(reply, &"move")


func _closest_crate(point: Vector3) -> int:
	var nearest_id := 0
	var nearest_distance := PICKUP_RADIUS
	for id: int in sim.crates:
		var crate: Dictionary = sim.crates[id]
		if crate.owner != -1:
			continue
		var distance := point.distance_to(crate.point)
		if distance < nearest_distance:
			nearest_id = id
			nearest_distance = distance
	return nearest_id


func _refresh(delta: float) -> void:
	_feedback_left = maxf(0.0, _feedback_left - delta)
	for id: int in crate_meshes.keys():
		if not sim.crates.has(id):
			crate_meshes[id].queue_free()
			crate_meshes.erase(id)
	for id: int in sim.crates:
		var crate: Dictionary = sim.crates[id]
		if not crate_meshes.has(id):
			var tint: Color = CARGO_COLORS[crate.kind]
			var prop := Node3D.new()
			FieldWorld.box(prop, Vector3.ZERO, Vector3(0.53, 0.48, 0.49), tint, true)
			FieldWorld.box(prop, Vector3(0, 0.255, 0), Vector3(0.22, 0.03, 0.4), CrestWorld.FRAME)
			add_child(prop)
			crate_meshes[id] = prop
		var mesh: Node3D = crate_meshes[id]
		if crate.owner == -1:
			mesh.global_position = crate.point + Vector3.UP * 0.29
		else:
			mesh.global_position = pilots[crate.owner].carrying.global_position
	for player in range(2):
		pilots[player].visible = sim.phase != &"success"
	world.reflect(sim, _spots, delta)
	hud.update_status(sim, _spots, _feedback if _feedback_left > 0.0 else "", _active_pilot)


func _crew_input(key: Key, location: KeyLocation) -> bool:
	match key:
		KEY_ESCAPE:
			_queued.clear()
			_show(&"paused")
		KEY_F1:
			_open_science(&"")
		KEY_TAB:
			if not sim.solo:
				return false
			_active_pilot = 1 - _active_pilot
			_notice("Controlas al astronauta %d" % (_active_pilot + 1), &"move")
		KEY_E:
			_queued.append(Vector2i(_active_pilot, 0))
		KEY_ENTER, KEY_KP_ENTER:
			_queued.append(Vector2i(_active_pilot if sim.solo else 1, 0))
		KEY_Q:
			_queued.append(Vector2i(_active_pilot, 1))
		KEY_SHIFT, KEY_SLASH:
			if key == KEY_SLASH or location == KEY_LOCATION_RIGHT:
				_queued.append(Vector2i(_active_pilot if sim.solo else 1, 1))
		_:
			if key not in MOTION[0] and key not in MOTION[1]:
				return false
			_pressed[key] = true
	return true


func _menu_input(key: Key) -> bool:
	match _menu:
		&"bases":
			match key:
				KEY_1:
					_select_base(0)
				KEY_2:
					_select_base(1)
				KEY_3:
					_select_base(2)
				KEY_ESCAPE:
					_show(&"lobby")
				_:
					return false
		&"lobby":
			match key:
				KEY_1:
					_mode_selected(true)
				KEY_2, KEY_ENTER:
					_mode_selected(false)
				KEY_F1:
					_open_science(&"lobby")
				_:
					return false
		&"briefing":
			match key:
				KEY_1, KEY_ENTER:
					_start(false, false)
				KEY_2:
					_start(true, false)
				KEY_3:
					_start(false, true)
				KEY_ESCAPE:
					_show(&"bases")
				KEY_F1:
					_open_science(&"briefing")
				_:
					return false
		&"paused":
			match key:
				KEY_ESCAPE:
					_show(&"")
				KEY_R:
					_restart()
				KEY_F1:
					_open_science(&"paused")
				_:
					return false
		&"science":
			match key:
				KEY_ESCAPE, KEY_F1:
					_show(_science_return)
				KEY_LEFT:
					_page(-1)
				KEY_RIGHT:
					_page(1)
				_:
					return false
		&"result":
			match key:
				KEY_R, KEY_ENTER:
					_restart()
				KEY_F1:
					_open_science(&"result")
				_:
					return false
		&"controls":
			if key != KEY_ESCAPE:
				return false
			_show(&"result")
	return true


func _choose(action: StringName) -> void:
	match action:
		&"bases_0", &"bases_1", &"bases_2":
			_select_base(int(String(action).right(1)))
		&"lobby_0":
			_mode_selected(true)
		&"lobby_1":
			_mode_selected(false)
		&"lobby_2":
			_open_science(&"lobby")
		&"briefing_0":
			_start(false, false)
		&"briefing_1":
			_start(true, false)
		&"briefing_2":
			_start(false, true)
		&"paused_0":
			_show(&"")
		&"paused_1", &"result_0":
			_restart()
		&"paused_2":
			_open_science(&"paused")
		&"result_1":
			_open_science(&"result")
		&"result_2":
			_show(&"controls")
		&"controls_0":
			_show(&"result")
		&"science_0":
			if sim.records.is_empty():
				_show(_science_return)
			else:
				_page(-1)
		&"science_1":
			_page(1)
		&"science_2":
			var url := String(sim.records[_science_index].source_url)
			if url.begins_with("https://"):
				OS.shell_open(url)


func _mode_selected(solo: bool) -> void:
	sim.solo = solo
	_active_pilot = 0
	_show(&"bases")
	_refresh(0.0)


func _select_base(index: int) -> void:
	sim.campaign.select(StringName(sim.campaign.data.order[index]))
	world.set_base(sim.campaign.base.soil, sim.campaign.id)
	_show(&"briefing")
	_refresh(0.0)


func _start(practice: bool, skip: bool) -> void:
	if skip:
		sim.begin(practice, true)
		_show(&"")
		_refresh(0.0)
		return
	_intro_practice = practice
	_show(&"intro")
	hud.hide()
	intro.play(sim.campaign.base.name, float(sim.campaign.data.intro_seconds), sim.campaign.id)
	world.animate_intro(0.0)
	_notice("Transporte en descenso", &"move")


func _finish_intro() -> void:
	world.animate_intro(1.0)
	camera.h_offset = 0.0
	camera.size = 19.9
	hud.show()
	sim.begin(_intro_practice)
	_show(&"")
	_refresh(0.0)


func _show(mode: StringName) -> void:
	_menu = mode
	_pressed.clear()
	_queued.clear()
	hud.menu(mode, sim, _science_index)


func _open_science(return_to: StringName) -> void:
	_science_return = return_to
	_show(&"science")


func _page(direction: int) -> void:
	if not sim.records.is_empty():
		_science_index = posmod(_science_index + direction, sim.records.size())
		hud.menu(&"science", sim, _science_index)


func _restart() -> void:
	get_tree().reload_current_scene()


func _notice(message: String, sound: StringName) -> void:
	if message.is_empty():
		return
	_feedback = message
	_feedback_left = 2.35
	if _notes.has(sound):
		_tone.stream = _notes[sound]
		_tone.play()


func _build_sounds() -> void:
	if DisplayServer.get_name() == "headless":
		return
	for key: StringName in [&"move", &"warning", &"launch"]:
		var pitches := [420.0, 570.0]
		if key == &"warning":
			pitches = [380.0, 280.0, 380.0]
		elif key == &"launch":
			pitches = [262.0, 392.0, 523.0, 659.0, 784.0]
		var samples_per_note := 2000 if key == &"launch" else 1350
		var pcm := PackedByteArray()
		pcm.resize(2 * samples_per_note * pitches.size())
		for note in range(pitches.size()):
			for sample in range(samples_per_note):
				var envelope := sin(PI * float(sample) / samples_per_note)
				var tone := sin(TAU * pitches[note] * sample / 16000.0)
				pcm.encode_s16(
					(note * samples_per_note + sample) * 2, roundi(tone * envelope * 6600)
				)
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = 16000
		stream.data = pcm
		_notes[key] = stream
