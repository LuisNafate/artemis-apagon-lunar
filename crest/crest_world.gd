class_name CrestWorld
extends Node3D

const MONO := preload("res://assets/ui/fonts/IBMPlexMono-Medium.ttf")
const TRANSPORT := preload("res://assets/props_luna/nasa/apollo_descenso.glb")
const APOLLO_BASE := preload("res://assets/props_luna/nasa/apollo_base_lunar.glb")
const APOLLO_ASCENT := preload("res://assets/props_luna/nasa/apollo_etapa_ascenso.glb")
const NOBILE_RELIEF := preload("res://assets/props_luna/nasa/relieve_nobile_lola.glb")
const LRO_MODEL := preload("res://assets/props_luna/nasa/lro_miniatura.glb")
const WATER_MACHINE_EMPTY := preload(
	"res://assets/props_luna/agua_hielo/maquina_agua_hielo_vacio.glb"
)
const WATER_MACHINE_FULL := preload(
	"res://assets/props_luna/agua_hielo/maquina_agua_hielo_lleno.glb"
)
const WATER_MACHINE_SCALE := 2.3
const MODEL_BATTERY := preload("res://assets/props_luna/estaciones/bateria.glb")
const MODEL_DRILL := preload("res://assets/props_luna/estaciones/pico.glb")
const MODEL_ICE_DEPOT := preload("res://assets/props_luna/estaciones/deposito_hielo.glb")
const MODEL_GREENHOUSE := preload("res://assets/props_luna/estaciones/invernadero.glb")
const MODEL_SOLAR := preload("res://assets/props_luna/estaciones/paneles.glb")
const MODEL_ROVER_ANTENNA := preload("res://assets/props_luna/estaciones/antena_rover.glb")
const MODEL_WATER_TANK := preload("res://assets/props_luna/estaciones/tanque_agua.glb")
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
const SOIL := Color("#6d6888")
const LAVENDER := Color("#756f8e")
const HALF_X := 20.0
const HALF_Z := 11.0
const STATIONS := {
	&"supply": Vector3(10.4, 0, 7.2),
	&"training": Vector3(10.6, 0, 3.4),
	&"ice": Vector3(14.75, 0, -2.6),
	&"ore": Vector3(-10.0, 0, 5.4),
	&"refinery": Vector3(-6.4, 0, 4.7),
	&"drill": Vector3(-14.1, 0, 4.4),
	&"battery": Vector3(-3.0, 0, -3.9),
	&"life": Vector3(15.25, 0, 0.2),
	&"power": Vector3(-13.2, 0, -4.4),
	&"crop": Vector3(-9.4, 0, 0.3),
	&"fuel": Vector3(-0.8, 0, 0.8),
	&"radio": Vector3(7.8, 0, -3.5),
	&"pad": Vector3(5.6, 0, 6.2)
}
const WORKSHOP := {&"solar": Vector3(-8.2, 0, -4.6), &"irrigation": Vector3(-2.8, 0, 4.9)}
const LANDER_PAD := Vector3(5.5, 0.04, 2.6)
const SPAWNS := [Vector3(14.2, 0.1, 1.9), Vector3(16.3, 0.1, 1.9)]
const BOARDING := [Vector3(4.85, 0.04, 5.9), Vector3(6.35, 0.04, 5.9)]
const SHELTER := Rect2(12.5, -2.6, 5.5, 9.1)
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

## En la campaña el hielo y el mineral se extraen de los depósitos del mundo abierto.
static var campaign_stations := _without_quarries(STATIONS.merged(WORKSHOP))

var campaign_layout := false
var deck_index := 0
var descent_stage: Node3D
var ascent_stage: Node3D
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
var nobile_relief: Node3D
var supply_pallet: Node3D
var shelter_shell: Node3D
var refuge_alert: MeshInstance3D
var _water_machine_empty: Node3D
var _water_machine_full: Node3D
var _craters: Node3D
var _detail: Node3D
var _floor_color: PaperMaterial
var _equipment: Array[Node3D] = []
var _soil := SOIL
var _mission_clock := 0.0


static func _without_quarries(stations: Dictionary) -> Dictionary:
	stations.erase(&"ice")
	stations.erase(&"ore")
	return stations


func build() -> void:
	_lighting()
	_terrain()
	nobile_relief = NOBILE_RELIEF.instantiate()
	nobile_relief.position = (
		Vector3(-10.0, 0.015, -14.6) if campaign_layout else Vector3(-6.0, 0.015, 8.77)
	)
	nobile_relief.rotation.y = PI
	nobile_relief.scale = Vector3(0.71, 0.58, 1.0)
	PaperMaterial.restyle(nobile_relief)
	add_child(nobile_relief)
	nobile_relief.hide()
	_walkways()
	_stations()
	if campaign_layout:
		_build_lander()
	else:
		_build_rocket()
	transport = TRANSPORT.instantiate()
	PaperMaterial.restyle(transport)
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
		var point: Vector3 = WORKSHOP[station]
		var tint := AMBER if is_solar else LIME
		if is_solar:
			pass
		else:
			_equipment.append(
				station_prop(self, MODEL_WATER_TANK, point + Vector3(0, 0.0, 1.8), 1.5, 0.5)
			)
			_solid(point + Vector3(0, 0.55, 1.8), Vector3(1.1, 1.1, 1.5))
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
	var shelter_center := SHELTER.get_center()
	refuge_alert = FieldWorld._mesh(
		self, Vector3(shelter_center.x, 0.045, shelter_center.y), ring, AMBER, true
	)
	refuge_alert.scale = Vector3(1.6, 1.0, 2.6)
	refuge_alert.hide()


func show_field_models(_science_key: String = "F1") -> void:
	transport.position = TRANSPORT_PARK
	transport.scale = Vector3.ONE * 0.72
	transport.visible = not campaign_layout
	field_models.show()


func _build_field_models() -> void:
	field_models = Node3D.new()
	field_models.name = "MissionModels"
	add_child(field_models)
	if not campaign_layout:
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
	_soil = Color(soil_color).lerp(LAVENDER, 0.5)
	_floor_color.albedo_color = _soil
	if campaign_layout:
		return
	nobile_relief.visible = base_id in [&"nobile", &"nobile_rim_1", &"nobile_rim_2"]
	_build_craters(base_id)


## Color del suelo de la base actual, para teñir el terreno del mundo abierto.
func soil_color() -> Color:
	return _soil


## Material del suelo que `reflect` tiñe (tormenta); la campaña lo comparte con los chunks.
func ground_material() -> PaperMaterial:
	return _floor_color


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
	var stations := STATIONS
	if campaign_layout and not tutorial:
		stations = campaign_stations
	for key: StringName in stations:
		if (key == &"training") != tutorial or (key == &"supply" and not supply):
			continue
		var location: Vector3 = stations[key]
		var distance := point.distance_to(location)
		if distance < closest:
			closest = distance
			result = key
	return result


func reflect(sim: CrestSim, active_spots: Array[StringName], delta: float) -> void:
	_mission_clock += delta
	var storm := sim.storm_active()
	var power := 0.22 if sim.shadow_active() else 1.3
	sun.light_energy = lerpf(sun.light_energy, power, minf(1.0, delta * 2.0))
	var light_color := Color("#93b9f5") if sim.shadow_active() else Color("#fff4dc")
	sun.light_color = sun.light_color.lerp(light_color, minf(1.0, delta * 2.0))
	var refining: Variant = sim.get("refining")
	var machine_full := refining is Array and not (refining as Array).is_empty()
	_water_machine_empty.visible = not machine_full
	_water_machine_full.visible = machine_full
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
	if not campaign_layout:
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
	if campaign_layout:
		env.background_mode = Environment.BG_CANVAS
		env.background_canvas_max_layer = -1
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#c9bfd6")
	env.ambient_light_energy = 0.52
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 2.2
	env.ssao_power = 1.6
	env.ssao_detail = 0.6
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -95, 0)
	sun.light_color = Color("#fff0d8")
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.shadow_blur = 2.2
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.4
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 60
	add_child(sun)


func _terrain() -> void:
	_solid(Vector3(0, -0.55, 0), Vector3(HALF_X * 2.0 + 2.0, 1.1, HALF_Z * 2.0 + 2.0))
	if campaign_layout:
		# Los chunks del mundo abierto son el suelo y el exterior; la plataforma queda abierta.
		_floor_color = PaperMaterial.new(SOIL)
		return
	var slab := FieldWorld.box(self, Vector3(0, -0.46, 0), Vector3(44, 0.9, 29), SOIL)
	_floor_color = slab.material_override
	for x in [-HALF_X - 0.2, HALF_X + 0.2]:
		_border(Vector3(x, 0.13, 0), Vector3(0.3, 0.26, HALF_Z * 2.0 + 0.45))
	for z in [-HALF_Z - 0.22, HALF_Z + 0.22]:
		_border(Vector3(0, 0.13, z), Vector3(HALF_X * 2.0 + 0.4, 0.26, 0.32))
	var rng := RandomNumberGenerator.new()
	rng.seed = 91258
	var fleck_material := PaperMaterial.new()
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


func _ground_back_edge(x: float) -> float:
	return -16.1 - 0.23 * x + sin((x + 54.0) / 4.5 * 1.43) * 0.63


func _build_ground_sheet() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(24):
		var x0 := -54.0 + 4.5 * index
		var x1 := x0 + 4.5
		var first := Vector3(x0, 0, _ground_back_edge(x0))
		var next := Vector3(x1, 0, _ground_back_edge(x1))
		var front := Vector3(x0, 0, 42)
		var far_front := Vector3(x1, 0, 42)
		for point in [first, next, front, next, far_front, front]:
			surface.set_normal(Vector3.UP)
			surface.add_vertex(point)
	var ground := MeshInstance3D.new()
	ground.mesh = surface.commit()
	_floor_color = PaperMaterial.new(SOIL)
	_floor_color.set_shader_parameter("facet_variation", 0.035)
	ground.material_override = _floor_color
	add_child(ground)


func _build_craters(base_id: StringName) -> void:
	if is_instance_valid(_craters):
		remove_child(_craters)
		_craters.queue_free()
	if is_instance_valid(_detail):
		remove_child(_detail)
		_detail.queue_free()
	_detail = Node3D.new()
	_detail.name = "DetalleSuperficie"
	add_child(_detail)
	_craters = Node3D.new()
	_craters.name = "CrateresLaterales"
	add_child(_craters)
	var height_scale := 0.8 if base_id in [&"mons_mouton_plateau", &"slater_plain"] else 1.0
	var placements := [
		[
			Vector3(-25.5, 0.015, -3.5) if campaign_layout else Vector3(-15.95, 0.015, -4.6),
			2.55,
			0.76
		],
		[
			Vector3(-9.0, 0.015, -14.0) if campaign_layout else Vector3(-11.8, 0.015, -10.65),
			1.72,
			0.49
		],
		[
			Vector3(17.0, 0.015, -14.8) if campaign_layout else Vector3(14.6, 0.015, -9.25),
			2.42,
			0.85
		],
		[Vector3(24.8, 0.015, 1.5) if campaign_layout else Vector3(17.1, 0.015, 1.15), 1.73, 0.63],
		[Vector3(9.9, 0.015, 14.8) if campaign_layout else Vector3(9.9, 0.015, 10.57), 2.37, 0.80],
		[
			Vector3(-13.7, 0.015, 14.0) if campaign_layout else Vector3(-13.7, 0.015, 10.2),
			1.61,
			0.57
		]
	]
	for index in range(placements.size()):
		var placement: Array = placements[index]
		var crater := LunarCrater.new()
		crater.position = placement[0]
		crater.build(
			placement[1], float(placement[2]) * height_scale, hash([base_id, index]), _soil
		)
		_craters.add_child(crater)
	if not campaign_layout:
		_scatter_surface_detail(base_id, placements)


func _scatter_surface_detail(base_id: StringName, placements: Array) -> void:
	# Crateres menores y rocas fuera de la cubierta transitable.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([base_id, "detalle"])
	var walkable := Rect2(-HALF_X, -HALF_Z, HALF_X * 2.0, HALF_Z * 2.0)
	var minor := Node3D.new()
	minor.name = "CrateresMenores"
	_detail.add_child(minor)
	var placed := 0
	var attempts := 0
	while placed < 16 and attempts < 400:
		attempts += 1
		var radius := rng.randf_range(0.45, 1.05)
		var spot := Vector3(rng.randf_range(-31, 31), 0.015, rng.randf_range(-12.5, 24.0))
		var reach := radius * 1.3 + 0.4
		if walkable.grow(reach).has_point(Vector2(spot.x, spot.z)):
			continue
		var crowded := false
		for placement: Array in placements:
			var other: Vector3 = placement[0]
			if spot.distance_to(other) < reach + float(placement[1]) * 1.4:
				crowded = true
		for other_minor: LunarCrater in minor.get_children():
			if spot.distance_to(other_minor.position) < reach + other_minor.get_meta("reach"):
				crowded = true
		if crowded:
			continue
		var small := LunarCrater.new()
		small.position = spot
		small.set_meta("reach", reach)
		small.build(radius, radius * rng.randf_range(0.14, 0.24), rng.randi(), _soil)
		minor.add_child(small)
		placed += 1
	var rocks := MultiMesh.new()
	rocks.transform_format = MultiMesh.TRANSFORM_3D
	rocks.use_colors = true
	rocks.mesh = LunarCrater.rock_mesh(11)
	rocks.instance_count = 70
	for index in range(rocks.instance_count):
		var pos := Vector3(rng.randf_range(-30, 30), 0.0, rng.randf_range(-12.0, 23.0))
		while walkable.grow(1.2).has_point(Vector2(pos.x, pos.z)):
			pos = Vector3(rng.randf_range(-30, 30), 0.0, rng.randf_range(-12.0, 23.0))
		var size := rng.randf_range(0.16, 0.55)
		var basis := Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(
			Vector3(size, size * rng.randf_range(0.7, 1.3), size)
		)
		rocks.set_instance_transform(index, Transform3D(basis, pos))
		rocks.set_instance_color(index, _soil.lightened(rng.randf_range(0.06, 0.26)))
	var rock_field := MultiMeshInstance3D.new()
	rock_field.name = "Rocas"
	rock_field.multimesh = rocks
	rock_field.material_override = PaperMaterial.new()
	_detail.add_child(rock_field)


func show_refuge_alert(show_alert: bool) -> void:
	refuge_alert.visible = show_alert


func present_lander(flight_phase: int, progress: float, returned: bool) -> void:
	ascent_stage.visible = not returned and flight_phase <= 0
	ascent_stage.position.y = (
		LANDER_PAD.y + (8.9 * progress * progress if flight_phase == 0 else 0.0)
	)
	plume.visible = flight_phase == 0
	plume.scale.y = 1.05 + sin(_mission_clock * 40.0) * 0.21


static func station_prop(
	parent: Node3D, scene: PackedScene, point: Vector3, size: float, half_height: float, yaw := 0.0
) -> Node3D:
	# Los GLB de estaciones vienen normalizados a ~1 unidad y centrados en el origen:
	# `size` los escala y `half_height` (mitad de su alto) los apoya sobre el suelo.
	var root := Node3D.new()
	root.position = point
	root.rotation_degrees.y = yaw
	parent.add_child(root)
	var model: Node3D = scene.instantiate()
	PaperMaterial.restyle(model, false)
	model.scale = Vector3.ONE * size
	model.position.y = half_height * size
	root.add_child(model)
	return root


func _water_machine(point: Vector3) -> Node3D:
	# Maquina agua-hielo: vacia en reposo, llena mientras la refinadora trabaja.
	var root := Node3D.new()
	root.position = point
	add_child(root)
	_water_machine_empty = WATER_MACHINE_EMPTY.instantiate()
	_water_machine_full = WATER_MACHINE_FULL.instantiate()
	for model: Node3D in [_water_machine_empty, _water_machine_full]:
		PaperMaterial.restyle(model, false)
		model.scale = Vector3.ONE * WATER_MACHINE_SCALE
		model.position.y = 0.73
		root.add_child(model)
	_water_machine_full.hide()
	return root


func _walkways() -> void:
	for x in [-HALF_X + 0.8, HALF_X - 0.8]:
		for z in [-HALF_Z + 0.8, HALF_Z - 0.8]:
			FieldWorld.box(self, Vector3(x, 0.17, z), Vector3(0.36, 0.34, 0.36), FRAME)
			FieldWorld.box(self, Vector3(x, 0.41, z), Vector3(0.23, 0.18, 0.23), AMBER, true)


func _stations() -> void:
	_shelter()
	_solar()
	_greenhouse()
	if not campaign_layout:
		_quarry(&"ice", BLUE)
		_quarry(&"ore", AMBER)
	training_desk = _console(&"training", BLUE)
	_equipment.append(_console(&"refinery", BLUE, false))
	var drill_root := _console(&"drill", AMBER, false)
	_equipment.append(station_prop(drill_root, MODEL_DRILL, Vector3(0, 0, 1.6), 1.5, 0.5))
	_solid(STATIONS[&"drill"] + Vector3(0, 0.55, 1.6), Vector3(0.8, 1.1, 1.3))
	var battery_root := _console(&"battery", AMBER, false)
	_equipment.append(
		station_prop(battery_root, MODEL_BATTERY, Vector3(0, 0, -2.1), 3.0, 0.18, 90.0)
	)
	_solid(STATIONS[&"battery"] + Vector3(0, 0.3, -2.1), Vector3(3.0, 0.6, 1.5))
	_equipment.append(_console(&"fuel", AMBER, false))
	_console(&"radio", PURPLE, false)
	if campaign_layout:
		_marker(&"pad", AMBER)
	else:
		_console(&"pad", AMBER)
	_equipment.append(_console(&"life", BLUE, false))
	_marker(&"crop", LIME)
	_marker(&"power", AMBER)
	var radio: Vector3 = STATIONS[&"radio"]
	_equipment.append(
		station_prop(self, MODEL_ROVER_ANTENNA, radio + Vector3(0, 0.05, -1.6), 2.7, 0.33, 90.0)
	)
	_solid(radio + Vector3(0, 0.45, -1.6), Vector3(2.6, 0.9, 1.5))
	var refine: Vector3 = STATIONS[&"refinery"]
	_equipment.append(_water_machine(refine + Vector3(0, 0, 2.0)))
	_solid(refine + Vector3(0, 0.75, 2.0), Vector3(2.5, 1.5, 2.5))
	aux_module = Node3D.new()
	add_child(aux_module)
	aux_module.position = STATIONS[&"battery"] + Vector3(2.4, 0, -1.2)
	FieldWorld.box(aux_module, Vector3.UP * 0.62, Vector3(0.83, 1.24, 0.8), AMBER)
	for y in [0.36, 0.63, 0.9]:
		FieldWorld.box(aux_module, Vector3(0, y, 0.41), Vector3(0.56, 0.1, 0.07), FRAME)
	drill_upgrade = Node3D.new()
	add_child(drill_upgrade)
	drill_upgrade.position = STATIONS[&"drill"] + Vector3(1.3, 0, 1.2)
	_disc(drill_upgrade, Vector3.UP * 0.56, 0.26, 1.12, AMBER, 8)
	_disc(drill_upgrade, Vector3.UP * 1.13, 0.14, 0.4, WHITE, 8)


func _shelter() -> void:
	shelter_shell = Node3D.new()
	add_child(shelter_shell)
	var center := SHELTER.get_center()
	var half := SHELTER.size * 0.5
	_deck(Vector3(center.x, 0.005, center.y), Vector3(SHELTER.size.x, 0.055, SHELTER.size.y), BLUE)
	for side in [-1.0, 1.0]:
		var x: float = center.x + side * (half.x - 0.16)
		for end in [-1.0, 1.0]:
			var post := Vector3(x, 0.61, center.y + end * (half.y - 0.12))
			FieldWorld.box(shelter_shell, post, Vector3(0.31, 1.22, 0.31), BLUE)
			_solid(post, Vector3(0.31, 1.22, 0.31))
		FieldWorld.box(
			shelter_shell,
			Vector3(x, 0.66, center.y),
			Vector3(0.2, 0.16, SHELTER.size.y - 0.3),
			BLUE,
			true
		)
	for side in [-1.0, 1.0]:
		var pos := Vector3(center.x + side * 1.6, 0.34, center.y - half.y + 1.3)
		FieldWorld.box(shelter_shell, pos, Vector3(0.85, 0.69, 1.5), FRAME)
		FieldWorld.box(shelter_shell, pos + Vector3.UP * 0.4, Vector3(0.78, 0.14, 1.4), BLUE)
		_solid(pos, Vector3(0.85, 0.69, 1.5))
	var cross := Vector3(center.x, 0.12, center.y + 0.5)
	FieldWorld.box(shelter_shell, cross, Vector3(0.23, 0.08, 0.77), BLUE, true)
	FieldWorld.box(shelter_shell, cross, Vector3(0.76, 0.08, 0.23), BLUE, true)


func _solar() -> void:
	for offset in [-15.8, -14.1, -12.4, -10.7]:
		var point := Vector3(offset, 0.0, -6.8)
		_equipment.append(station_prop(self, MODEL_SOLAR, point, 2.5, 0.49))
		_solid(point + Vector3.UP * 0.49, Vector3(1.3, 0.98, 1.05))


func _greenhouse() -> void:
	var origin: Vector3 = STATIONS[&"crop"]
	var dome := Vector3(-14.3, 0.0, -0.1)
	_equipment.append(station_prop(self, MODEL_GREENHOUSE, dome, 6.0, 0.34))
	_solid(dome + Vector3(0.0, 0.8, 0.0), Vector3(5.4, 1.6, 5.0))
	crops = Node3D.new()
	crops.position = origin + Vector3(0.0, 0.0, 0.42)
	add_child(crops)
	for col in range(3):
		for row in range(2):
			var seedling := Vector3(-1.05 + col * 1.05, 0.21, -0.2 + row * 0.4)
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
	if key == &"ice":
		for side in [-0.75, 0.75]:
			_equipment.append(
				station_prop(self, MODEL_ICE_DEPOT, point + Vector3(side, 0.03, -2.0), 1.35, 0.49)
			)
		_solid(point + Vector3(0, 0.6, -2.0), Vector3(2.2, 1.2, 1.2))
	for pair in [
		Vector2(-1.0, -1.15),
		Vector2(-0.58, -0.92),
		Vector2(0.01, -1.26),
		Vector2(0.74, -1.03),
		Vector2(1.1, -1.32)
	]:
		if key == &"ice" or key == &"ore":
			break
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
	PaperMaterial.restyle(prop)
	prop.scale = Vector3.ONE * model_scale
	prop.position = RADIO_PIVOT_CORRECTION * model_scale
	stand.add_child(prop)
	return stand


func _console(key: StringName, accent: Color, show_machine := true) -> Node3D:
	var point: Vector3 = STATIONS[key]
	var root := Node3D.new()
	add_child(root)
	root.position = point
	_deck(point, Vector3(2.05, 0.06, 1.77), accent)
	var machine := Vector3(0, 0.39, -0.55)
	if show_machine:
		FieldWorld.box(root, machine, Vector3(0.84, 0.78, 0.45), FRAME)
		FieldWorld.box(root, machine + Vector3(0, 0.3, 0.12), Vector3(0.91, 0.25, 0.47), WHITE)
		FieldWorld.box(
			root, machine + Vector3(0, 0.3, 0.365), Vector3(0.59, 0.12, 0.045), accent, true
		)
	if show_machine and campaign_layout and key not in [&"training", &"supply"]:
		_solid(point + machine + Vector3(0, 0, 0.09), Vector3(0.91, 0.84, 0.67))
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
	label.text = "MÓDULO LUNAR" if campaign_layout and key == &"pad" else NAMES[key]
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


func _build_lander() -> void:
	var pad := LANDER_PAD
	_disc(self, Vector3(pad.x, 0.006, pad.z), 2.67, 0.034, FRAME, 12)
	_disc(self, Vector3(pad.x, 0.027, pad.z), 2.39, 0.025, DECK, 12)
	for index in range(8):
		var angle := TAU * index / 8.0
		var corner := pad + Vector3(cos(angle) * 2.52, 0.07, sin(angle) * 2.52)
		_disc(self, corner, 0.095, 0.14, AMBER, 8, true)
	descent_stage = APOLLO_BASE.instantiate()
	ascent_stage = APOLLO_ASCENT.instantiate()
	PaperMaterial.restyle(descent_stage)
	PaperMaterial.restyle(ascent_stage)
	for stage in [descent_stage, ascent_stage]:
		add_child(stage)
		stage.position = pad
		stage.rotation_degrees.y = -13.0
		stage.scale = Vector3.ONE * 0.95
	_solid(pad + Vector3.UP * 0.73, Vector3(2.3, 1.52, 2.15))
	# The ladder and footpads sit inside the striped service pad.
	plume = Node3D.new()
	ascent_stage.add_child(plume)
	FieldWorld.ball(plume, Vector3(0, 0.94, 0), Vector3(0.67, 1.50, 0.65), AMBER, true)
	FieldWorld.ball(plume, Vector3(0, 1.18, 0), Vector3(0.34, 0.81, 0.34), WHITE, true)
	plume.hide()


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
	# Intersections have a tiny rendering offset so surfaces never compete at equal depth.
	if campaign_layout:
		point.y += deck_index * 0.00032
		deck_index += 1
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
