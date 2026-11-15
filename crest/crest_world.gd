class_name CrestWorld
extends Node3D

const MONO := preload("res://assets/ui/fonts/IBMPlexMono-Medium.ttf")
const TRANSPORT := preload("res://assets/props_luna/nasa/apollo_descenso.glb")
const NOBILE_RELIEF := preload("res://assets/props_luna/nasa/relieve_nobile_lola.glb")
const LRO_MODEL := preload("res://assets/props_luna/nasa/lro_miniatura.glb")
const GUIDE_MODEL := preload("res://assets/pilotos/astrocat_guia.glb")
const TRANSPORT_PARK := Vector3(-11.9, 0.04, 7.45)
const ANTENNA := preload("res://assets/props_luna/kenney/antena.glb")
const RECEIVER := preload("res://assets/props_luna/kenney/consola.glb")
const RADIO_PIVOT_CORRECTION := Vector3(2.0, 0.0, 1.5)
const BLUE := Color("#82ddff")
const LIME := Color("#acd891")
const AMBER := Color("#ffbc76")
const PURPLE := Color("#c4acf7")
const WHITE := Color("#e4e8f3")
const FRAME := Color("#273345")
const DECK := Color("#4d5970")
const SOIL := Color("#5c586c")
const STATIONS := {
	&"supply": Vector3(-3.7, 0, 6.55),
	&"training": Vector3(0, 0, 5.3),
	&"ice": Vector3(-11.1, 0, -0.5),
	&"ore": Vector3(-11.1, 0, 4.2),
	&"refinery": Vector3(-5.1, 0, -3.4),
	&"drill": Vector3(-5.5, 0, 5.8),
	&"battery": Vector3(4.7, 0, 6.3),
	&"life": Vector3(0, 0, 2.9),
	&"power": Vector3(0, 0, -5.1),
	&"crop": Vector3(3.1, 0, -2.2),
	&"fuel": Vector3(6.7, 0, -2.4),
	&"radio": Vector3(6.3, 0, 3.9),
	&"pad": Vector3(11.2, 0, 0.7),
}
const SPAWNS := [Vector3(-1.0, 0.1, 6.1), Vector3(1.0, 0.1, 6.1)]
const BOARDING := [Vector3(10.45, 0.04, 0.5), Vector3(11.95, 0.04, 0.5)]
const SHELTER := Rect2(-2.9, 1.55, 5.8, 5.75)
const NAMES := {
	&"supply": "SUMINISTROS",
	&"training": "PRÁCTICA",
	&"ice": "HIELO",
	&"ore": "MINERAL",
	&"refinery": "REFINADO",
	&"drill": "TALADRO",
	&"battery": "BATERÍA",
	&"life": "REFUGIO",
	&"power": "RED SOLAR",
	&"crop": "CULTIVOS",
	&"fuel": "PROPELENTE",
	&"radio": "RADIO",
	&"pad": "COHETE"
}

var markers: Dictionary = {}
var rocket: Node3D
var plume: Node3D
var booster: Node3D
var sun: DirectionalLight3D
var night_lights: Array[MeshInstance3D] = []
var aux_module: Node3D
var drill_upgrade: Node3D
var training_desk: Node3D
var crops: Node3D
var transport: Node3D
var field_models: Node3D
var guide_animator: AnimationPlayer
var nobile_relief: Node3D
var supply_pallet: Node3D
var shelter_shell: Node3D
var refuge_alert: MeshInstance3D
var _lro_display: Node3D
var _craters: Node3D
var _last_launch := false
var _rocket_home: Vector3
var _floor_color: StandardMaterial3D
var _equipment: Array[Node3D] = []
var _soil := SOIL
var _mission_clock := 0.0


func build() -> void:
	_lighting()
	_terrain()
	nobile_relief = NOBILE_RELIEF.instantiate()
	nobile_relief.position = Vector3(-6.0, 0.015, 8.77)
	nobile_relief.rotation.y = PI
	nobile_relief.scale = Vector3(0.71, 0.58, 1.0)
	add_child(nobile_relief)
	nobile_relief.hide()
	_walkways()
	_stations()
	_build_rocket()
	_rocket_home = rocket.position
	transport = TRANSPORT.instantiate()
	transport.position = Vector3(-4, 0.25, 6.1)
	transport.rotation_degrees.y = 21
	add_child(transport)
	transport.hide()
	_build_field_models()
	supply_pallet = _console(&"supply", LIME)
	for index in range(3):
		var parcel := Vector3(-0.49 + 0.49 * index, 0.22, 0.08)
		FieldWorld.box(supply_pallet, parcel, Vector3(0.42, 0.39, 0.48), LIME)
		FieldWorld.box(
			supply_pallet, parcel + Vector3.UP * 0.211, Vector3(0.09, 0.025, 0.46), FRAME
		)
	supply_pallet.hide()


func build_lunar_workshop() -> void:
	for station: StringName in [&"solar", &"irrigation"]:
		var is_solar := station == &"solar"
		var point := Vector3(4.88, 0, -5.95) if is_solar else Vector3(3.14, 0, 0.65)
		var tint := AMBER if is_solar else LIME
		FieldWorld.box(self, point + Vector3(0, 0.28, -0.56), Vector3(0.9, 0.56, 0.55), FRAME)
		FieldWorld.box(self, point + Vector3(0, 0.59, -0.56), Vector3(0.76, 0.06, 0.49), tint, true)
		var label := Label3D.new()
		label.text = "REFUERZO SOLAR" if is_solar else "RIEGO"
		label.position = point + Vector3.UP * 0.68
		label.font = MONO
		label.pixel_size = 0.016
		label.outline_size = 10
		label.modulate = tint
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(label)
		markers[station] = label
	var ring := TorusMesh.new()
	ring.inner_radius = 1.61
	ring.outer_radius = 1.72
	ring.rings = 24
	ring.ring_segments = 6
	refuge_alert = FieldWorld._mesh(self, Vector3(0, 0.045, 3.88), ring, AMBER, true)
	refuge_alert.scale.z = 1.29
	refuge_alert.hide()


func show_field_models(science_key: String = "F1") -> void:
	var lro_label := field_models.get_node("LroLabel") as Label3D
	lro_label.text = ("LRO · " + science_key) if not science_key.is_empty() else "LRO"
	transport.position = TRANSPORT_PARK
	transport.scale = Vector3.ONE * 0.72
	transport.show()
	field_models.show()
	guide_animator.play(&"Wave")
	guide_animator.queue(&"Idle")


func _build_field_models() -> void:
	field_models = Node3D.new()
	field_models.name = "MissionModels"
	add_child(field_models)
	var guide: Node3D = GUIDE_MODEL.instantiate()
	guide.name = "AstroCat"
	guide.position = Vector3(-3.7, 0.08, 2.45)
	guide.rotation.y = PI
	guide.scale = Vector3.ONE * 0.51
	field_models.add_child(guide)
	guide_animator = guide.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	guide_animator.get_animation(&"Idle").loop_mode = Animation.LOOP_LINEAR
	_model_label("GUÍA", guide.position + Vector3(0, 1.95, 0.25), LIME)
	var display_point := Vector3(-8.75, 0, -4.2)
	FieldWorld.box(field_models, display_point + Vector3.UP * 0.18, Vector3(1.8, 0.36, 1.25), FRAME)
	FieldWorld.box(
		field_models, display_point + Vector3.UP * 0.38, Vector3(1.53, 0.06, 1.03), BLUE, true
	)
	_lro_display = LRO_MODEL.instantiate()
	_lro_display.position = display_point + Vector3.UP * 1.19
	_lro_display.rotation_degrees = Vector3(8, -25, 0)
	_lro_display.scale = Vector3.ONE * 0.64
	field_models.add_child(_lro_display)
	_model_label("LRO · F1", display_point + Vector3(0, 0.35, 0.9), BLUE).name = "LroLabel"
	_model_label("APOLO", TRANSPORT_PARK + Vector3(0, 0.35, 1.25), AMBER)
	field_models.hide()


func _model_label(caption: String, point: Vector3, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = caption
	label.font = MONO
	label.font_size = 27
	label.pixel_size = 0.019
	label.position = point
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = color.lightened(0.30)
	label.outline_size = 11
	label.outline_modulate = FRAME
	field_models.add_child(label)
	return label


func set_base(soil_color: String, base_id: StringName) -> void:
	_soil = Color(soil_color)
	_floor_color.albedo_color = _soil
	nobile_relief.visible = base_id in [&"nobile", &"nobile_rim_1", &"nobile_rim_2"]
	_build_craters(base_id)


func animate_intro(progress: float) -> void:
	transport.scale = Vector3.ONE
	transport.visible = progress < 0.64
	var arrival := smoothstep(0.0, 0.31, progress)
	transport.position = Vector3(lerpf(-12.0, -3.5, arrival), lerpf(4.8, 0.04, arrival), 3.6)
	shelter_shell.scale = Vector3(1.0, maxf(0.01, smoothstep(0.29, 0.52, progress)), 1.0)
	rocket.scale = Vector3.ONE * maxf(0.01, smoothstep(0.44, 0.68, progress))
	for index in range(_equipment.size()):
		var equipment := _equipment[index]
		var delay := 0.32 + 0.026 * index
		var unfold := smoothstep(delay, delay + 0.17, progress)
		equipment.scale = Vector3.ONE * maxf(0.01, unfold)
	training_desk.visible = progress >= 1.0
	for marker: Node3D in markers.values():
		marker.hide()


func sheltered(point: Vector3) -> bool:
	return SHELTER.has_point(Vector2(point.x, point.z))


func nearest(point: Vector3, tutorial: bool, supply: bool = false) -> StringName:
	var result := &""
	var closest := 2.1 if tutorial else 1.63
	for key: StringName in STATIONS:
		if (key == &"training") != tutorial or (key == &"supply" and not supply):
			continue
		var location: Vector3 = STATIONS[key]
		var distance := point.distance_to(location)
		if distance < closest:
			closest = distance
			result = key
	return result


func reflect(sim: CrestSim, active_spots: Array[StringName], delta: float) -> void:
	_mission_clock += delta
	if field_models.visible:
		_lro_display.rotate_y(delta * 0.55)
	var storm := sim.storm_active()
	var power := 0.22 if sim.shadow_active() else 1.03
	sun.light_energy = lerpf(sun.light_energy, power, minf(1.0, delta * 2.0))
	var light_color := Color("#93b9f5") if sim.shadow_active() else Color("#fff4dc")
	sun.light_color = sun.light_color.lerp(light_color, minf(1.0, delta * 2.0))
	for lamp in night_lights:
		lamp.visible = sim.shadow_active()
	_floor_color.albedo_color = _floor_color.albedo_color.lerp(
		Color("#774756") if storm else _soil, minf(1.0, delta * 3.0)
	)
	for spot: StringName in markers:
		var marker: Node3D = markers[spot]
		marker.visible = (
			(spot == &"training") == (sim.phase == &"tutorial" or sim.phase == &"briefing")
		)
		var target := 1.1 if spot in active_spots else 1.0
		marker.scale = marker.scale.lerp(Vector3.ONE * target, minf(1.0, delta * 10.0))
	training_desk.visible = sim.phase in [&"briefing", &"tutorial"]
	markers[&"supply"].visible = sim.campaign.supply_pending
	supply_pallet.visible = sim.campaign.supply_pending
	aux_module.visible = sim.auxiliary
	drill_upgrade.visible = sim.drill
	var grow := clampf(1.0 - float(sim.jobs[&"crop"]) / float(sim.runtime.crop_seconds), 0.18, 1.0)
	crops.scale.y = grow if sim.jobs[&"crop"] != 0 else (1.0 if sim.food > 0 else 0.28)
	booster.visible = sim.fuel_loaded > 0
	plume.visible = sim.phase in [&"countdown", &"success"]
	if plume.visible:
		plume.scale.y = 0.9 + 0.24 * sin(_mission_clock * 42)
		plume.position.y = -0.15 + sin(_mission_clock * 38) * 0.08
	if sim.phase == &"success":
		rocket.position.y += delta * (3.5 + rocket.position.y * 0.8)


func _lighting() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#101623")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#afb9e1")
	env.ambient_light_energy = 0.61
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-47, -54, 0)
	sun.light_color = Color("#fff4dc")
	sun.light_energy = 1.03
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70
	add_child(sun)


func _terrain() -> void:
	var ground := FieldWorld.box(self, Vector3(0, -0.46, 0), Vector3(44, 0.9, 29), SOIL)
	_floor_color = ground.material_override
	_solid(Vector3(0, -0.55, 0), Vector3(32, 1.1, 18))
	for x in [-15.45, 15.45]:
		_border(Vector3(x, 0.13, 0), Vector3(0.3, 0.26, 17.45))
	for z in [-8.57, 8.57]:
		_border(Vector3(0, 0.13, z), Vector3(30.9, 0.26, 0.32))
	var rng := RandomNumberGenerator.new()
	rng.seed = 91258
	var fleck_material := StandardMaterial3D.new()
	fleck_material.vertex_color_use_as_albedo = true
	fleck_material.roughness = 1.0
	var fleck := CylinderMesh.new()
	fleck.top_radius = 0.5
	fleck.bottom_radius = 0.5
	fleck.height = 1.0
	fleck.radial_segments = 5
	fleck.material = fleck_material
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.mesh = fleck
	batch.instance_count = 185
	for index in range(batch.instance_count):
		var pos := Vector3(rng.randf_range(-22, 22), -0.018, rng.randf_range(-14.4, 14.4))
		var width := rng.randf_range(0.14, 1.08)
		var basis := Basis.from_scale(Vector3(width, 0.035, width))
		batch.set_instance_transform(index, Transform3D(basis, pos))
		batch.set_instance_color(index, SOIL.lightened(rng.randf_range(0.09, 0.27)))
	var speckles := MultiMeshInstance3D.new()
	speckles.multimesh = batch
	speckles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(speckles)
	_build_craters(&"cresta")
	for index in range(14):
		var pos := Vector3(rng.randf_range(-28, 28), -0.15, rng.randf_range(13.8, 21))
		FieldWorld.ball(
			self, pos, Vector3(2.1, 1.3, 2.7) * rng.randf_range(0.6, 1.8), SOIL.darkened(0.16)
		)


func _build_craters(base_id: StringName) -> void:
	if is_instance_valid(_craters):
		remove_child(_craters)
		_craters.queue_free()
	_craters = Node3D.new()
	_craters.name = "CrateresLaterales"
	add_child(_craters)
	var height_scale := 0.8 if base_id in [&"mons_mouton_plateau", &"slater_plain"] else 1.0
	var placements := [
		[Vector3(-15.95, 0.015, -4.6), 2.55, 0.76],
		[Vector3(-11.8, 0.015, -10.65), 1.72, 0.49],
		[Vector3(14.6, 0.015, -9.25), 2.42, 0.85],
		[Vector3(17.1, 0.015, 1.15), 1.73, 0.63],
		[Vector3(9.9, 0.015, 10.57), 2.37, 0.80],
		[Vector3(-13.7, 0.015, 10.2), 1.61, 0.57]
	]
	for index in range(placements.size()):
		var placement: Array = placements[index]
		var crater := LunarCrater.new()
		crater.position = placement[0]
		crater.build(
			placement[1], float(placement[2]) * height_scale, hash([base_id, index]), _soil
		)
		_craters.add_child(crater)


func show_refuge_alert(show_alert: bool) -> void:
	refuge_alert.visible = show_alert


func animate_free_play_launch(active: bool, returned: bool, delta: float) -> void:
	if not returned:
		rocket.position = _rocket_home
		rocket.show()
	elif active:
		plume.show()
		rocket.position.y += delta * (3.5 + rocket.position.y * 0.8)
	elif _last_launch or rocket.visible:
		rocket.hide()
	_last_launch = active


func _walkways() -> void:
	_deck(Vector3(-1.0, 0, -0.1), Vector3(23.8, 0.06, 2.1), AMBER)
	_deck(Vector3(-0.5, 0, 4.9), Vector3(24.0, 0.06, 1.7), BLUE)
	_deck(Vector3(-12, 0, 2.2), Vector3(2.3, 0.06, 6.8), BLUE)
	_deck(Vector3(0, 0, 0.0), Vector3(2.3, 0.06, 13.6), BLUE)
	_deck(Vector3(10.9, 0, 2.9), Vector3(2.0, 0.06, 5.2), AMBER)
	for x in [-9.3, -7.9, -6.5, -5.1]:
		var barrier := Vector3(x, 0.44, 2.25)
		FieldWorld.box(self, barrier, Vector3(1.41, 0.88, 0.56), FRAME)
		FieldWorld.box(self, barrier + Vector3.UP * 0.24, Vector3(1.1, 0.11, 0.58), AMBER)
	_solid(Vector3(-7.2, 0.45, 2.25), Vector3(5.7, 0.9, 0.56))
	for x in [-13.4, 13.4]:
		for z in [-6.2, 6.8]:
			FieldWorld.box(self, Vector3(x, 0.17, z), Vector3(0.36, 0.34, 0.36), FRAME)
			FieldWorld.box(self, Vector3(x, 0.41, z), Vector3(0.23, 0.18, 0.23), AMBER, true)


func _stations() -> void:
	_shelter()
	for point in [
		Vector3(-10, 0.06, 4.25),
		Vector3(-6.7, 0.06, 4.25),
		Vector3(-3.6, 0.06, 4.25),
		Vector3(3.6, 0.06, 4.25),
		Vector3(6.5, 0.06, 4.25),
		Vector3(9.5, 0.06, 4.25)
	]:
		var lamp := FieldWorld.box(self, point, Vector3(0.38, 0.065, 0.12), BLUE, true)
		lamp.hide()
		night_lights.append(lamp)
	_solar()
	_greenhouse()
	_quarry(&"ice", BLUE)
	_quarry(&"ore", AMBER)
	training_desk = _console(&"training", BLUE)
	_equipment.append(_console(&"refinery", BLUE))
	_console(&"drill", AMBER)
	_console(&"battery", AMBER)
	_equipment.append(_console(&"fuel", AMBER))
	_console(&"radio", PURPLE)
	_console(&"pad", AMBER)
	_equipment.append(_console(&"life", BLUE))
	_marker(&"crop", LIME)
	_marker(&"power", AMBER)
	var plant: Vector3 = STATIONS[&"fuel"]
	for x in [-0.53, 0.51]:
		_disc(self, plant + Vector3(x, 0.73, -1.36), 0.42, 1.45, WHITE, 12)
		_disc(self, plant + Vector3(x, 1.17, -1.36), 0.436, 0.16, AMBER, 12)
	_solid(plant + Vector3(0, 0.75, -1.36), Vector3(1.92, 1.5, 0.78))
	var radio: Vector3 = STATIONS[&"radio"]
	_equipment.append(_radio_prop(ANTENNA, radio + Vector3(0.77, 0.06, -1.16), 3.05))
	_equipment.append(_radio_prop(RECEIVER, radio + Vector3(-0.73, 0.055, -0.95), 1.22))
	var refine: Vector3 = STATIONS[&"refinery"]
	FieldWorld.box(self, refine + Vector3(0, 0.69, -1.32), Vector3(2.35, 1.36, 0.82), WHITE)
	FieldWorld.box(self, refine + Vector3(0, 0.77, -0.89), Vector3(1.63, 0.32, 0.07), BLUE, true)
	_solid(refine + Vector3(0, 0.69, -1.32), Vector3(2.35, 1.36, 0.82))
	aux_module = Node3D.new()
	add_child(aux_module)
	aux_module.position = STATIONS[&"battery"] + Vector3(1.04, 0, -0.8)
	FieldWorld.box(aux_module, Vector3.UP * 0.62, Vector3(0.83, 1.24, 0.8), AMBER)
	for y in [0.36, 0.63, 0.9]:
		FieldWorld.box(aux_module, Vector3(0, y, 0.41), Vector3(0.56, 0.1, 0.07), FRAME)
	drill_upgrade = Node3D.new()
	add_child(drill_upgrade)
	drill_upgrade.position = STATIONS[&"drill"] + Vector3(0.83, 0, -0.72)
	_disc(drill_upgrade, Vector3.UP * 0.56, 0.26, 1.12, AMBER, 8)
	_disc(drill_upgrade, Vector3.UP * 1.13, 0.14, 0.4, WHITE, 8)


func _shelter() -> void:
	shelter_shell = Node3D.new()
	add_child(shelter_shell)
	_deck(Vector3(0, 0.005, 4.38), Vector3(5.8, 0.055, 5.73), BLUE)
	for x in [-2.74, 2.74]:
		for z in [1.64, 7.15]:
			FieldWorld.box(shelter_shell, Vector3(x, 0.61, z), Vector3(0.31, 1.22, 0.31), BLUE)
			_solid(Vector3(x, 0.61, z), Vector3(0.31, 1.22, 0.31))
		FieldWorld.box(shelter_shell, Vector3(x, 0.66, 4.4), Vector3(0.2, 0.16, 5.5), BLUE, true)
	for pos in [Vector3(-1.79, 0.34, 3.0), Vector3(1.79, 0.34, 3.0)]:
		FieldWorld.box(shelter_shell, pos, Vector3(0.85, 0.69, 1.5), FRAME)
		FieldWorld.box(shelter_shell, pos + Vector3.UP * 0.4, Vector3(0.78, 0.14, 1.4), BLUE)
		_solid(pos, Vector3(0.85, 0.69, 1.5))
	FieldWorld.box(shelter_shell, Vector3(0, 0.12, 4.24), Vector3(0.23, 0.08, 0.77), BLUE, true)
	FieldWorld.box(shelter_shell, Vector3(0, 0.12, 4.24), Vector3(0.76, 0.08, 0.23), BLUE, true)


func _solar() -> void:
	for offset in [-3.12, 0.0, 3.12]:
		var point := Vector3(offset, 0.0, -6.55)
		FieldWorld.box(self, point + Vector3.UP * 0.59, Vector3(0.3, 1.18, 0.35), FRAME)
		var panel := Node3D.new()
		panel.position = point + Vector3.UP * 1.25
		panel.rotation_degrees.x = -29
		add_child(panel)
		_equipment.append(panel)
		FieldWorld.box(panel, Vector3.ZERO, Vector3(2.9, 0.16, 1.38), WHITE)
		for col in range(6):
			for row in range(3):
				var cell := Vector3(-1.17 + col * 0.47, 0.105, -0.42 + row * 0.42)
				FieldWorld.box(panel, cell, Vector3(0.439, 0.08, 0.38), Color("#315d91"))
		_solid(point + Vector3.UP * 0.49, Vector3(2.59, 0.98, 1.05))


func _greenhouse() -> void:
	var origin: Vector3 = STATIONS[&"crop"]
	crops = Node3D.new()
	crops.position = origin + Vector3(0.0, 0.57, -1.45)
	add_child(crops)
	for col in range(3):
		var point := origin + Vector3(-1.05 + col * 1.05, 0.28, -1.45)
		FieldWorld.box(self, point, Vector3(0.89, 0.57, 1.25), FRAME)
		FieldWorld.box(self, point + Vector3.UP * 0.31, Vector3(0.96, 0.12, 1.26), WHITE)
		FieldWorld.box(self, point + Vector3.UP * 0.39, Vector3(0.8, 0.04, 1.08), SOIL)
		_solid(point, Vector3(0.89, 0.57, 1.25))
		for row in range(3):
			var seedling := Vector3(point.x - origin.x, 0.21, -0.41 + row * 0.4)
			FieldWorld.ball(crops, seedling, Vector3(0.53, 0.43, 0.33), LIME)
			FieldWorld.ball(
				crops,
				seedling + Vector3(0.11, 0.11, -0.02),
				Vector3(0.35, 0.24, 0.25),
				Color("#74a653")
			)


func _quarry(key: StringName, color: Color) -> void:
	var point: Vector3 = STATIONS[key]
	_deck(point, Vector3(2.9, 0.062, 2.6), color)
	var offset := 0
	for pair in [
		Vector2(-1.0, -1.15),
		Vector2(-0.58, -0.92),
		Vector2(0.01, -1.26),
		Vector2(0.74, -1.03),
		Vector2(1.1, -1.32)
	]:
		var item := FieldWorld.box(
			self,
			point + Vector3(pair.x, 0.36, pair.y),
			Vector3(0.46, 0.82 + offset * 0.05, 0.42),
			color.darkened(0.06 * offset)
		)
		item.rotation_degrees = Vector3(12 + offset * 9, offset * 26, -13 + offset * 7)
		offset += 1
	_marker(key, color)


func _radio_prop(scene: PackedScene, point: Vector3, model_scale: float) -> Node3D:
	var stand := Node3D.new()
	add_child(stand)
	stand.position = point
	var prop: Node3D = scene.instantiate()
	prop.scale = Vector3.ONE * model_scale
	prop.position = RADIO_PIVOT_CORRECTION * model_scale
	stand.add_child(prop)
	return stand


func _console(key: StringName, accent: Color) -> Node3D:
	var point: Vector3 = STATIONS[key]
	var root := Node3D.new()
	add_child(root)
	root.position = point
	_deck(point, Vector3(2.05, 0.06, 1.77), accent)
	var machine := Vector3(0, 0.39, -0.55)
	FieldWorld.box(root, machine, Vector3(0.84, 0.78, 0.45), FRAME)
	FieldWorld.box(root, machine + Vector3(0, 0.3, 0.12), Vector3(0.91, 0.25, 0.47), WHITE)
	FieldWorld.box(root, machine + Vector3(0, 0.3, 0.365), Vector3(0.59, 0.12, 0.045), accent, true)
	_marker(key, accent)
	return root


func _marker(key: StringName, accent: Color) -> void:
	var root := Node3D.new()
	add_child(root)
	root.position = STATIONS[key]
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.63
	mesh.outer_radius = 0.685
	mesh.rings = 10
	mesh.ring_segments = 24
	FieldWorld._mesh(root, Vector3(0, 0.08, 0), mesh, accent, true)
	var label := Label3D.new()
	label.text = NAMES[key]
	label.font = MONO
	label.font_size = 30
	label.pixel_size = 0.019
	label.position = Vector3(0, 0.46, 0.9)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = accent.lightened(0.38)
	label.outline_size = 14
	label.outline_modulate = Color("#1a2335")
	root.add_child(label)
	markers[key] = root


func _build_rocket() -> void:
	var pad := Vector3(11.1, 0, -2.65)
	_disc(self, pad, 2.65, 0.1, FRAME, 12)
	_disc(self, pad + Vector3.UP * 0.08, 2.29, 0.08, DECK, 12)
	for index in range(8):
		var angle := TAU * index / 8.0
		var corner := pad + Vector3(cos(angle) * 2.36, 0.18, sin(angle) * 2.36)
		_disc(self, corner, 0.13, 0.19, AMBER, 8, true)
	_solid(pad + Vector3.UP * 0.8, Vector3(1.9, 1.6, 1.9))
	rocket = Node3D.new()
	add_child(rocket)
	rocket.position = pad
	_disc(rocket, Vector3.UP * 1.72, 0.75, 2.85, WHITE, 16)
	_disc(rocket, Vector3.UP * 2.37, 0.765, 0.32, AMBER, 16)
	_disc(rocket, Vector3.UP * 0.55, 0.77, 0.45, FRAME, 16)
	var nose := CylinderMesh.new()
	nose.bottom_radius = 0.75
	nose.top_radius = 0.12
	nose.height = 1.08
	nose.radial_segments = 16
	FieldWorld._mesh(rocket, Vector3.UP * 3.68, nose, WHITE, false)
	FieldWorld.ball(rocket, Vector3(0, 2.82, 0.72), Vector3(0.66, 0.45, 0.17), Color("#45688d"))
	for side in [-1.0, 1.0]:
		FieldWorld.box(rocket, Vector3(side * 0.8, 0.6, 0.0), Vector3(0.44, 0.91, 0.5), AMBER)
	booster = Node3D.new()
	rocket.add_child(booster)
	for side in [-1.0, 1.0]:
		_disc(booster, Vector3(side * 0.97, 1.06, 0), 0.24, 1.37, DECK, 10)
		_disc(booster, Vector3(side * 0.97, 1.75, 0), 0.24, 0.19, AMBER, 10)
	plume = Node3D.new()
	rocket.add_child(plume)
	FieldWorld.ball(plume, Vector3(0, -0.24, 0), Vector3(0.74, 1.78, 0.74), AMBER, true)
	FieldWorld.ball(plume, Vector3(0, 0.05, 0), Vector3(0.43, 1.2, 0.43), WHITE, true)


func _deck(point: Vector3, dimensions: Vector3, accent: Color) -> void:
	FieldWorld.box(self, point, dimensions, DECK)
	var along_x := dimensions.x >= dimensions.z
	var length := dimensions.x if along_x else dimensions.z
	var across := dimensions.z if along_x else dimensions.x
	for edge in [-1.0, 1.0]:
		var offset := across * 0.5 - 0.08
		var trim := (
			Vector3(0, 0.065, edge * offset) if along_x else Vector3(edge * offset, 0.065, 0)
		)
		var trim_size := Vector3(length, 0.027, 0.09) if along_x else Vector3(0.09, 0.027, length)
		FieldWorld.box(self, point + trim, trim_size, accent.darkened(0.34))
	for idx in range(1, ceili(length / 1.25)):
		var offset := idx * 1.25 - length / 2.0
		var line := Vector3(offset, 0.061, 0) if along_x else Vector3(0, 0.061, offset)
		var line_size := (
			Vector3(0.026, 0.019, across - 0.18)
			if along_x
			else Vector3(across - 0.18, 0.019, 0.026)
		)
		FieldWorld.box(self, point + line, line_size, FRAME)


func _border(point: Vector3, dimensions: Vector3) -> void:
	FieldWorld.box(self, point, dimensions, FRAME)
	_solid(point + Vector3.UP * 0.4, dimensions + Vector3.UP * 0.87)


func _solid(point: Vector3, dimensions: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = point
	var shape := BoxShape3D.new()
	shape.size = dimensions
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)


func _disc(
	parent: Node3D,
	point: Vector3,
	radius: float,
	height: float,
	color: Color,
	facets: int,
	glow: bool = false
) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = facets
	return FieldWorld._mesh(parent, point, mesh, color, glow)
