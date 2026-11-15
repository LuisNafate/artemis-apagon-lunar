# gdlint: disable=max-returns
class_name CrestHUD
extends Control

signal selected(action: StringName)

const LRO := preload("res://assets/props_luna/nasa/lro_miniatura.glb")
const DISPLAY := preload("res://assets/ui/fonts/BarlowCondensed-Bold.ttf")
const MONO := CrestWorld.MONO
const BODY := preload("res://assets/ui/fonts/Barlow-SemiBold.ttf")
const WHITE := Color("#f2f1ec")
const SOFT := Color("#b8c0ce")
const DIM := Color("#8996ab")
const AMBER := CrestWorld.AMBER
const BLUE := CrestWorld.BLUE
const LIME := CrestWorld.LIME
const RED := Color("#ff927e")
const PANEL := Color("#131b29")
const EDGE := Color("#39465d")

var base_title: Label
var cycle: Label
var clock: Label
var weather: Label
var headline: Label
var task: Label
var inventories: Label
var checklist: Label
var signal_state: Label
var feedback: Label
var countdown_label: Label
var _air: Array[ProgressBar] = []
var _charge: ProgressBar
var _players: Array[Label] = []
var _key_captions: Array[Label] = []
var _shade: ColorRect
var _dialog: Panel
var _dialog_title: Label
var _dialog_kicker: Label
var _dialog_body: Label
var _dialog_note: Label
var _buttons: Array[Button] = []
var _science_preview: SubViewportContainer
var _science_viewport: SubViewport
var _science_model: Node3D
var _mode := &""


func build() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := _panel(self, Rect2(24, 20, 1232, 85), PANEL)
	_panel(top, Rect2(0, 0, 5, 85), AMBER, AMBER)
	_label(top, "ARTEMIS / ENTRENADOR LUNAR", Rect2(17, 8, 280, 21), 12, MONO, AMBER)
	base_title = _label(top, "ESTACIÓN CRESTA", Rect2(17, 25, 295, 47), 32, DISPLAY, WHITE)
	_panel(top, Rect2(319, 13, 1, 60), EDGE)
	cycle = _label(top, "TIEMPO DE MISIÓN", Rect2(339, 8, 215, 21), 12, MONO, DIM)
	clock = _label(top, "", Rect2(339, 26, 145, 45), 31, MONO, WHITE)
	_panel(top, Rect2(513, 13, 1, 60), EDGE)
	_label(top, "ESTADO DE SUPERFICIE", Rect2(532, 8, 304, 21), 12, MONO, DIM)
	weather = _label(top, "", Rect2(532, 30, 315, 38), 21, DISPLAY, AMBER)
	_panel(top, Rect2(865, 13, 1, 60), EDGE)
	_label(top, "LISTA DE VUELO", Rect2(885, 8, 312, 20), 12, MONO, DIM)
	checklist = _label(top, "", Rect2(885, 27, 327, 25), 15, MONO, WHITE)
	signal_state = _label(top, "", Rect2(885, 53, 323, 21), 13, BODY, SOFT)

	var strip := _panel(self, Rect2(24, 112, 1232, 39), Color("#192435"))
	var captions := ["AIRE J1", "AIRE J2", "BATERÍA"]
	var colors := [BLUE, AMBER, LIME]
	for index in range(captions.size()):
		var x := 16 + index * 188
		_label(strip, captions[index], Rect2(x, 4, 76, 31), 12, MONO, colors[index])
		var bar := _meter(strip, Rect2(x + 76, 16, 87, 7), colors[index])
		if index < 2:
			_air.append(bar)
		else:
			_charge = bar
	_panel(strip, Rect2(601, 8, 1, 23), EDGE)
	inventories = _label(strip, "", Rect2(620, 2, 594, 34), 13, MONO, WHITE)

	countdown_label = _label(self, "", Rect2(450, 172, 380, 66), 48, DISPLAY, AMBER)
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.add_theme_constant_override("outline_size", 12)
	feedback = _label(self, "", Rect2(305, 562, 670, 40), 19, BODY, WHITE)
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback.add_theme_constant_override("outline_size", 10)
	var footer := _panel(self, Rect2(24, 613, 1232, 83), PANEL)
	_panel(footer, Rect2(437, 10, 1, 62), EDGE)
	_panel(footer, Rect2(849, 10, 1, 62), EDGE)
	headline = _label(footer, "", Rect2(15, 5, 411, 29), 22, DISPLAY, WHITE)
	task = _label(footer, "", Rect2(15, 35, 409, 39), 15, BODY, SOFT)
	task.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for index in range(2):
		var x := 453 + index * 413
		var tint := BLUE if index == 0 else AMBER
		var keys := (
			"J1   WASD   E actuar   Q pasar"
			if index == 0
			else "J2   Flechas   Intro actuar   Mayús der. pasar"
		)
		_key_captions.append(_label(footer, keys, Rect2(x, 5, 365, 27), 12, MONO, tint))
		var player := _label(footer, "", Rect2(x, 35, 370, 35), 16, BODY, WHITE)
		player.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_players.append(player)
	_build_dialog()


func _process(delta: float) -> void:
	if is_instance_valid(_science_model) and _science_preview.is_visible_in_tree():
		_science_model.rotation.y += minf(delta, 0.1) * 0.45


func update_status(
	sim: CrestSim, spots: Array[StringName], feedback_message: String, active_pilot: int
) -> void:
	var seconds := maxi(0, ceili(sim.duration() - sim.elapsed))
	if not sim.campaign.base.is_empty():
		base_title.text = String(sim.campaign.base.name).to_upper()
		var day := sim.campaign.day(sim.elapsed)
		cycle.text = "%s %d  /  RESTANTE" % ["NOCHE" if sim.shadow_active() else "DÍA", day]
	clock.text = "%02d:%02d" % [seconds / 60, seconds % 60]
	weather.text = _weather(sim)
	weather.modulate = RED if sim.storm_active() or sim.energy_cut() else WHITE
	checklist.text = (
		"PROP. %d/%d   COMIDA %d/%d   J %d/2"
		% [
			sim.fuel_loaded,
			int(sim.config.launch_requirements.propellant_batches),
			sim.food_loaded,
			int(sim.config.launch_requirements.rations),
			sim.crew_seated()
		]
	)
	signal_state.text = "Tierra confirmó la lista" if sim.earth_ok else "Radio · por confirmar"
	if sim.radio_cut() and not sim.earth_ok:
		signal_state.text = "Radio · sin señal por ahora"
	if sim.radio_left > 0.0:
		signal_state.text = (
			"Radio · espera el regreso de la señal"
			if sim.radio_cut()
			else "Radio · respuesta en %.1f s" % sim.radio_left
		)
	inventories.text = (
		"AGUA %02d    MINERAL %02d    RACIONES %02d    PROPELENTE LISTO %d"
		% [sim.water, sim.ore, sim.food, sim.fuel_ready]
	)
	_charge.value = sim.charge / sim.battery_capacity()
	for player in range(2):
		if sim.solo:
			_key_captions[player].text = (
				"J%d ACTIVO · WASD · E / Q" % (player + 1)
				if player == active_pilot
				else "J%d EN ESPERA · TAB cambia" % (player + 1)
			)
		else:
			_key_captions[player].text = (
				"J1   WASD   E actuar   Q pasar"
				if player == 0
				else "J2   Flechas   Intro actuar   Mayús der. pasar"
			)
		_air[player].value = float(sim.pilots[player].air) / float(sim.runtime.air_capacity)
		_players[player].text = _player_info(sim, player, spots[player])
	feedback.text = feedback_message
	countdown_label.text = (
		"DESPEGUE EN %d" % ceili(sim.countdown) if sim.phase == &"countdown" else ""
	)
	_objective(sim)


func menu(mode: StringName, sim: CrestSim, science_index: int = 0) -> void:
	_mode = mode
	_shade.visible = mode != &""
	_show_science_model(false)
	if mode == &"":
		return
	var options: Array[String] = []
	match mode:
		&"bases":
			_dialog_kicker.text = "BASES LUNARES   /   ELIGE TU MISIÓN"
			_dialog_title.text = "¿Dónde aterrizamos?"
			_dialog_body.text = (
				"Cresta · Iniciación: guarda energía para la noche.\n"
				+ "Nobile · Intermedia: prepárate para cortes de radio.\n"
				+ "Taurus-Littrow · Avanzada: resiste averías de energía."
			)
			_dialog_note.text = "Esc vuelve al selector de jugadores"
			options = ["1  Estación Cresta", "2  Puesto Nobile", "3  Taurus-Littrow"]
		&"lobby":
			_dialog_kicker.text = "ESTACIÓN CRESTA   /   ENTRENADOR LUNAR"
			_dialog_title.text = "Última ventana"
			_dialog_body.text = "Mantén la base con vida y lleva a ambos astronautas a órbita lunar."
			_dialog_note.text = "Misión 2.5D · Teclado compartido · Sin conexión"
			options = ["1  Un jugador", "2  Dos jugadores", "Archivo científico"]
		&"briefing":
			_dialog_kicker.text = (
				String(sim.campaign.base.tag)
				+ "   /   "
				+ String(sim.campaign.base.region).to_upper()
			)
			_dialog_title.text = sim.campaign.base.name
			_dialog_body.text = (
				(
					"Alterna entre los dos astronautas con Tab y prepara el despegue."
					if sim.solo
					else "Dos astronautas. Un cohete. Repartan el trabajo y despeguen juntos."
				)
				+ "\n"
				+ String(sim.campaign.base.hint)
			)
			_dialog_note.text = (
				"Tab cambia de astronauta · Esc vuelve · F1 abre ciencia"
				if sim.solo
				else "Dos personas · Esc vuelve · F1 abre ciencia"
			)
			options = ["1  Ver historia y jugar", "2  Modo práctica", "3  Jugar directamente"]
		&"paused":
			_dialog_kicker.text = (
				String(sim.campaign.base.name).to_upper() + "   /   MISIÓN EN PAUSA"
			)
			_dialog_title.text = "Pausa"
			_dialog_body.text = "El reloj, las recetas y los mensajes esperan."
			_dialog_note.text = "Esc reanuda · F1 abre el archivo científico"
			options = ["Reanudar", "Reiniciar misión", "Archivo científico"]
		&"science":
			_dialog_kicker.text = "ARCHIVO CIENTÍFICO   /   DATOS HISTÓRICOS"
			if sim.records.is_empty():
				_dialog_title.text = "Archivo sin datos"
				_dialog_body.text = "La misión continúa con su escenario de entrenamiento."
				_dialog_note.text = "Esc / F1 para cerrar"
				options = ["Cerrar"]
			else:
				var record := sim.records[science_index]
				_dialog_title.text = CrestSim.SCIENCE_TITLES[record.id]
				_dialog_body.text = sim.science_text(record)
				_show_science_model(record.id == "nasa_lro_3d")
				_dialog_note.text = (
					"%02d / %02d    %s    ·    Esc / F1 para cerrar"
					% [science_index + 1, sim.records.size(), record.provider]
				)
				options = ["← Anterior", "Siguiente →", "Abrir fuente"]
		&"result":
			_dialog_kicker.text = (
				String(sim.campaign.base.name).to_upper() + "   /   INFORME DE VUELO"
			)
			var success := sim.phase == &"success"
			_dialog_title.text = "En órbita lunar" if success else "Misión interrumpida"
			_dialog_body.text = sim.result + "\n" + _debrief(sim)
			_dialog_note.text = (
				"%d entregas · %d cosechas · Exposición J1 %.0f / J2 %.0f"
				% [
					sim.deliveries,
					sim.crops_harvested,
					sim.pilots[0].exposure,
					sim.pilots[1].exposure
				]
			)
			options = ["Volver a jugar", "Archivo científico", "Controles"]
		&"controls":
			_dialog_kicker.text = "ARTEMIS   /   TECLADO COMPARTIDO"
			_dialog_title.text = "Controles"
			_dialog_body.text = (
				"WASD mueve · E actúa · Q pasa o suelta\nTab cambia de astronauta"
				if sim.solo
				else "J1   WASD · E actúa · Q pasa\nJ2   Flechas · Intro actúa · Mayús derecha o / pasa"
			)
			_dialog_note.text = "Cerca de tu compañero, pasar entrega la caja directamente."
			options = ["Volver"]
	for index in range(_buttons.size()):
		_buttons[index].visible = index < options.size()
		if index < options.size():
			_buttons[index].text = options[index]


func _weather(sim: CrestSim) -> String:
	if sim.phase == &"tutorial":
		return "PRÁCTICA · RELOJ DETENIDO"
	if sim.phase == &"briefing":
		return "PREPARANDO EL TURNO"
	if sim.phase == &"success":
		return "ASCENSO COMPLETADO"
	if sim.storm_active():
		return "¡PARTÍCULAS SOLARES! · REFUGIO"
	if sim.shadow_active():
		return "NOCHE · RED EN BATERÍA"
	if sim.energy_cut():
		return "AVERÍA · RED EN BATERÍA"
	if sim.radio_cut():
		return "RELÉ SIN SEÑAL"
	var until_storm := sim.storm_warning()
	if until_storm > 0.0 and until_storm <= float(sim.targets.storm_warning_seconds):
		return "ALERTA SOLAR EN %d s" % ceili(until_storm)
	var until_shadow := float(sim.runtime.shadow_start) - sim.elapsed
	if not sim.campaign.base.is_empty():
		until_shadow = sim.campaign.next_night(sim.elapsed)
	if until_shadow > 0.0 and until_shadow <= 12.0:
		return "NOCHE EN %d s" % ceili(until_shadow)
	return "LUZ SOLAR · RED ACTIVA"


func _objective(sim: CrestSim) -> void:
	if sim.phase == &"tutorial":
		var titles := [
			"1 / 4   Toma la muestra",
			"2 / 4   Pasa la caja",
			"3 / 4   Entrega en la mesa",
			"4 / 4   Inicia el turno"
		]
		var hints := [
			"J1 pulsa E en la mesa azul.",
			"J1 se acerca a J2 y pulsa Q.",
			"J2 pulsa Intro en la mesa.",
			"J1 pulsa E o J2 pulsa Intro en la mesa."
		]
		if sim.solo:
			hints[2] = "Pulsa Tab para controlar a J2. E entrega la muestra en la mesa."
			hints[3] = "Pulsa E en la mesa para iniciar."
		headline.text = titles[sim.tutorial_step]
		task.text = hints[sim.tutorial_step]
	elif sim.storm_active():
		headline.text = "Busquen el refugio azul"
		task.text = "El blindaje reduce la exposición. La base puede seguir produciendo."
	elif sim.phase == &"active" and sim.deliveries == 0 and sim.fuel_prepared == 0:
		headline.text = "Extraigan hielo"
		task.text = "Cantera azul → Refinado → Propelente. El agua también mantiene la base."
	elif sim.hungry:
		headline.text = "Coman una ración"
		task.text = "Usen el refugio con una ración propia o del depósito del cultivo."
	elif sim.phase == &"countdown":
		headline.text = "Ambos a bordo"
		task.text = "Quédense en los asientos hasta despegar."
	elif (
		sim.water < 2 and sim.fuel_prepared < int(sim.config.launch_requirements.propellant_batches)
	):
		headline.text = "Consigan agua"
		task.text = "Extraigan hielo y llévenlo al refinado azul."
	elif (
		sim.fuel_loaded < int(sim.config.launch_requirements.propellant_batches)
		or sim.food_loaded < int(sim.config.launch_requirements.rations)
	):
		headline.text = "Abastezcan el cohete"
		task.text = "Preparen combustible para el cohete (propelente) y llévenle comida."
	elif not sim.earth_ok:
		headline.text = "Contacten con Tierra"
		task.text = "Envíen la lista desde Radio. Pueden moverse mientras esperan."
	elif not sim.window_open() and not sim.campaign.base.is_empty():
		var release_day := maxi(
			int(sim.campaign.base.last_day),
			sim.campaign.day(sim.elapsed) + int(sim.shadow_active())
		)
		headline.text = "Esperen la luz del día %d" % release_day
		task.text = "Recarguen aire en el refugio hasta que la ventana esté abierta."
	else:
		headline.text = "Embarquen juntos"
		task.text = "Ambos actúan en el cohete con las manos libres. F1 abre ciencia."


func _player_info(sim: CrestSim, player: int, spot: StringName) -> String:
	var pilot := sim.pilots[player]
	if pilot.seated:
		return "A bordo · actuar libera el asiento"
	if pilot.mine != &"":
		return "Extrayendo · %.1f s" % maxf(0.0, float(pilot.mine_left))
	var cargo := sim.cargo_kind(player)
	var prefix := "" if cargo == &"" else "%s · " % CrestSim.CARGO_NAMES[cargo]
	var dose := " · EXP %.0f" % pilot.exposure if pilot.exposure > 0 else ""
	return prefix + _station_hint(sim, player, spot) + dose


func _station_hint(sim: CrestSim, player: int, station: StringName) -> String:
	match station:
		&"training":
			return "Mesa de práctica"
		&"supply":
			return "Recoger agua y una ración"
		&"ice", &"ore":
			return (
				"Extraer %s · %.0f s"
				% [CrestSim.CARGO_NAMES[station].to_lower(), sim.drill_seconds()]
			)
		&"refinery":
			return "Depositar hielo o mineral"
		&"drill":
			return "Taladro Mk2 instalado" if sim.drill else "Taladro Mk2 · cuesta 2 mineral"
		&"battery":
			return (
				"Batería auxiliar conectada"
				if sim.auxiliary
				else "Batería auxiliar · cuesta 2 mineral"
			)
		&"life":
			return (
				"Comer ración"
				if sim.hungry or sim.meals_clock < 18.0
				else (
					"Refugio · recupera aire"
					if sim.life_powered and (sim.water > 0 or sim.filter_clock > 0.0)
					else "Refugio · falta agua o energía"
				)
			)
		&"power":
			return (
				"Prioridad: %s · actuar cambia"
				% ("cultivo" if sim.priority == &"crop" else "propelente")
			)
		&"crop", &"fuel":
			var remaining := float(sim.jobs[station])
			if remaining > 0.0:
				return (
					"%s · %.0f s"
					% [
						"En proceso" if sim.powered[station] else "Pausado por energía",
						ceilf(remaining)
					]
				)
			var available := sim.food if station == &"crop" else sim.fuel_ready
			if available > 0 and sim.cargo_kind(player) == &"":
				return "Tomar %s" % ("ración" if station == &"crop" else "propelente")
			return "Sembrar · 1 agua" if station == &"crop" else "Refinar propelente · 2 agua"
		&"radio":
			return "Enviar lista a Tierra"
		&"pad":
			return "Cargar o embarcar"
	return "Busca una estación"


func _debrief(sim: CrestSim) -> String:
	if sim.auxiliary:
		return "La batería auxiliar amplió tu reserva durante la sombra."
	if sim.drill:
		return "El taladro Mk2 redujo dos segundos por extracción."
	if sim.pilots[0].exposure > 0.0 or sim.pilots[1].exposure > 0.0:
		return "La protección del refugio se practicó con un aviso histórico de NASA DONKI."
	return "Repartir el agua entre cultivo, soporte vital y propelente cambia cada turno."


func _build_dialog() -> void:
	_shade = ColorRect.new()
	_shade.color = Color("#0b111de1")
	_shade.position = Vector2.ZERO
	_shade.size = Vector2(1280, 720)
	add_child(_shade)
	_dialog = _panel(_shade, Rect2(291, 218, 698, 288), PANEL)
	_panel(_dialog, Rect2(0, 0, 698, 3), AMBER, AMBER)
	_dialog_kicker = _label(_dialog, "", Rect2(24, 18, 648, 22), 13, MONO, AMBER)
	_dialog_title = _label(_dialog, "", Rect2(23, 43, 648, 55), 48, DISPLAY, WHITE)
	_dialog_body = _label(_dialog, "", Rect2(25, 105, 640, 83), 22, BODY, WHITE)
	_dialog_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialog_note = _label(_dialog, "", Rect2(25, 190, 650, 29), 13, MONO, SOFT)
	for index in range(3):
		var button := Button.new()
		button.position = Vector2(25 + 219 * index, 230)
		button.size = Vector2(210, 39)
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.add_theme_font_override("font", BODY)
		button.add_theme_font_size_override("font_size", 17)
		button.add_theme_color_override("font_color", PANEL if index == 0 else WHITE)
		button.add_theme_color_override("font_hover_color", PANEL)
		button.add_theme_stylebox_override(
			"normal", _style(AMBER if index == 0 else Color("#253449"), EDGE)
		)
		button.add_theme_stylebox_override("hover", _style(WHITE, WHITE))
		button.add_theme_stylebox_override("pressed", _style(BLUE, BLUE))
		_dialog.add_child(button)
		_buttons.append(button)
		button.pressed.connect(func() -> void: selected.emit(StringName("%s_%d" % [_mode, index])))
	_build_science_preview()
	_shade.hide()


func _build_science_preview() -> void:
	_science_preview = SubViewportContainer.new()
	_science_preview.position = Vector2(466, 69)
	_science_preview.size = Vector2(203, 123)
	_science_preview.stretch = true
	_science_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialog.add_child(_science_preview)
	_science_viewport = SubViewport.new()
	_science_viewport.world_3d = World3D.new()
	_science_viewport.transparent_bg = true
	_science_preview.add_child(_science_viewport)
	var camera := Camera3D.new()
	camera.position = Vector3(2.5, 2.3, 4.3)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.1
	_science_viewport.add_child(camera)
	camera.look_at(Vector3.ZERO)
	camera.make_current()
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-45, 30, 0)
	key.light_energy = 1.15
	_science_viewport.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-14, -145, 0)
	fill.light_color = Color("#b2ccfa")
	fill.light_energy = 0.65
	_science_viewport.add_child(fill)
	_show_science_model(false)


func _show_science_model(display: bool) -> void:
	_science_preview.visible = display
	_science_viewport.render_target_update_mode = (
		SubViewport.UPDATE_WHEN_VISIBLE if display else SubViewport.UPDATE_DISABLED
	)
	if display and not is_instance_valid(_science_model):
		_science_model = LRO.instantiate()
		_science_model.rotation_degrees.y = 33
		_science_viewport.add_child(_science_model)
	if is_instance_valid(_science_model):
		_science_model.visible = display
	_dialog_body.size.x = 425.0 if display else 640.0


func _meter(parent: Control, bounds: Rect2, tint: Color) -> ProgressBar:
	var progress := ProgressBar.new()
	progress.max_value = 1.0
	progress.step = 0.0
	progress.show_percentage = false
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress.add_theme_stylebox_override("background", _style(EDGE, EDGE))
	progress.add_theme_stylebox_override("fill", _style(tint, tint))
	parent.add_child(progress)
	progress.position = bounds.position
	progress.size = bounds.size
	return progress


func _panel(parent: Control, bounds: Rect2, fill: Color, edge: Color = EDGE) -> Panel:
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", _style(fill, edge))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	panel.position = bounds.position
	panel.size = bounds.size
	return panel


func _label(
	parent: Control, value: String, bounds: Rect2, size_px: int, font: Font, color: Color
) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = value
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	label.position = bounds.position
	label.size = bounds.size
	return label


func _style(fill: Color, edge: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(1)
	return style
