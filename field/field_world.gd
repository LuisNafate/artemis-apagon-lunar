class_name FieldWorld
extends Node3D

const STATIONS := {
	&"generator": Vector3(0, 0, -10), &"farm": Vector3(-12, 0, -5), &"shelter": Vector3(8, 0, -3)
}
const ITEMS := {
	&"battery": Vector3(0, 0, 5), &"seed_a": Vector3(-21, 0, 5), &"seed_b": Vector3(20, 0, 7)
}
const AMBER := Color("#ffae59")
const MINT := Color("#87f3b6")
const CYAN := Color("#78c9ff")
const WHITE := Color("#c1cddd")
const DARK := Color("#26364e")
const SOIL := Color("#716d89")

var props: Dictionary = {}
var lamps: Dictionary = {}
var _rings: Dictionary = {}
var _time := 0.0


func build() -> void:
	_light()
	_terrain()
	_generator(STATIONS.generator)
	_farm(STATIONS.farm)
	_shelter(STATIONS.shelter)
	for key: StringName in ITEMS:
		_make_item(key, ITEMS[key])
	_landing_pad()


func _process(delta: float) -> void:
	_time += delta
	for key: StringName in _rings:
		var beacon: Node3D = _rings[key]
		if beacon.visible:
			beacon.position.y = 0.95 + sin(_time * 4.5) * 0.11
			beacon.rotation.y = _time * 1.3


func set_item_visible(key: StringName, display: bool) -> void:
	props[key].visible = display


func drop(key: StringName, point: Vector3) -> void:
	var item: Node3D = props[key]
	item.position = Vector3(point.x, 0.0, point.z)
	item.show()


func highlight(key: StringName) -> void:
	for id: StringName in _rings:
		_rings[id].visible = id == key


func update_power(online: bool, charge: float, crops: int) -> void:
	for key: StringName in lamps:
		var lamp: MeshInstance3D = lamps[key]
		var tint := Color("#d06454") if not online or charge <= 0.0 else MINT
		lamp.material_override.albedo_color = tint
		lamp.material_override.emission = tint
	for idx in range(2):
		get_node("Crop%d" % idx).visible = idx < crops


func _light() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#0a1028")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#7183b8")
	environment.ambient_light_energy = 0.72
	var settings := WorldEnvironment.new()
	settings.environment = environment
	add_child(settings)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -28, 0)
	sun.light_color = Color("#ffdfbf")
	sun.light_energy = 1.8
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 100
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-30, 140, 0)
	fill.light_color = Color("#739aff")
	fill.light_energy = 0.52
	add_child(fill)
	var earth := ball(self, Vector3(-21, 12, -135), Vector3(15, 15, 15), Color("#426f9c"), true)
	var planet: PaperMaterial = earth.material_override
	planet.unlit = 1.0
	planet.albedo_color = Color("#547da6")
	for mark in [Vector3(-23.7, 13.0, -128.3), Vector3(-19.1, 10.2, -128.2)]:
		ball(self, mark, Vector3(2.65, 1.2, 0.5), Color("#82aba7"), true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 682
	for idx in range(95):
		var point := Vector3(rng.randf_range(-210, 210), rng.randf_range(9, 90), -171)
		var width := rng.randf_range(0.08, 0.32)
		box(self, point, Vector3.ONE * width, Color("#aabde2"), true)


func _terrain() -> void:
	_floor(Vector3(0, -0.65, 13), Vector3(64, 1.3, 20), SOIL)
	_floor(Vector3(0, -0.65, -16), Vector3(64, 1.3, 30), SOIL.darkened(0.11))
	_floor(Vector3(-22, -0.65, 2), Vector3(20, 1.3, 6.0), SOIL.lightened(0.02))
	_floor(Vector3(22, -0.65, 2), Vector3(20, 1.3, 6.0), SOIL.lightened(0.02))
	_floor(Vector3(0, -4.7, 1), Vector3(24, 1, 6), Color("#272744"))
	for x in range(-11, 12, 2):
		box(self, Vector3(x, 0.025, 3.25), Vector3(0.86, 0.05, 0.24), AMBER, true)
		box(self, Vector3(x, 0.025, -1.25), Vector3(0.86, 0.05, 0.24), AMBER, true)
	for idx in range(4):
		box(self, Vector3(0, 0.04, 3.75 + idx * 0.6), Vector3(0.32, 0.06, 0.19), AMBER, true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 417
	for idx in range(168):
		var x := rng.randf_range(-31.5, 31.5)
		var z := rng.randf_range(-29.0, 22.0)
		if absf(x) < 12.0 and z > -1.6 and z < 3.6:
			continue
		if absf(x) < 2.5 or Vector2(x, z).distance_to(Vector2(-12, -5)) < 4:
			continue
		if Vector2(x, z).distance_to(Vector2(8, -3)) < 4:
			continue
		var size := rng.randf_range(0.07, 0.55)
		rock(
			Vector3(x, -size * 0.08, z),
			Vector3(size, size * 0.54, size * 0.73),
			SOIL.darkened(rng.randf_range(0.05, 0.44))
		)
	for point in [
		Vector3(-15, 0.01, 12),
		Vector3(19, 0.01, -14),
		Vector3(-22, 0.01, -12),
		Vector3(15, 0.01, 15),
		Vector3(-5, 0.01, -18)
	]:
		var lip := CylinderMesh.new()
		lip.top_radius = 1.3 + absf(point.x) * 0.05
		lip.bottom_radius = lip.top_radius
		lip.height = 0.02
		lip.radial_segments = 12
		_mesh(self, point, lip, SOIL.darkened(0.13), false)
	for idx in range(23):
		var x := -68.0 + idx * 6.0
		var height := rng.randf_range(3.2, 10.0)
		rock(
			Vector3(x, height * 0.11 - 2, -40 - rng.randf_range(2.0, 14.0)),
			Vector3(11, height, 9),
			Color("#575277")
		)
	for z in [-31.9, 23.9]:
		_floor(Vector3(0, 1, z), Vector3(65, 2.8, 1.0), SOIL.darkened(0.22))
	for x in [-32.8, 32.8]:
		_floor(Vector3(x, 1, -4), Vector3(1.0, 2.8, 55.0), SOIL.darkened(0.22))


func _generator(point: Vector3) -> void:
	var root := _platform(point, Vector3(5.3, 0.26, 4.3), AMBER)
	box(root, Vector3(0, 0.78, -0.62), Vector3(2.8, 1.32, 1.7), WHITE)
	_solid(root, Vector3(0, 0.78, -0.62), Vector3(2.8, 1.32, 1.38))
	for index in range(5):
		box(root, Vector3(-0.93 + index * 0.46, 1.46, -0.67), Vector3(0.21, 0.07, 0.9), DARK)
	box(root, Vector3(0, 0.88, 0.29), Vector3(1.28, 0.51, 0.14), DARK)
	lamps[&"generator"] = box(root, Vector3(0, 0.93, 0.37), Vector3(0.83, 0.14, 0.05), AMBER, true)
	for sign_x in [-1.0, 1.0]:
		box(root, Vector3(sign_x * 4.5, 0.85, -1.0), Vector3(0.13, 1.5, 0.13), WHITE)
		for idx in range(3):
			var pane := box(
				root,
				Vector3(sign_x * (3.0 + idx * 1.1), 1.45, -1.3),
				Vector3(1.0, 0.11, 2.25),
				Color("#31588b")
			)
			pane.rotation.x = -0.25
			box(root, pane.position + Vector3(0, 0.06, 0), Vector3(0.93, 0.03, 0.09), CYAN, true)
	_mark(&"generator", root, AMBER)


func _farm(point: Vector3) -> void:
	var root := _platform(point, Vector3(6.1, 0.26, 5.4), MINT)
	for side in [-1.0, 1.0]:
		box(root, Vector3(side * 2.55, 1.08, 0), Vector3(0.14, 1.94, 4.4), WHITE)
		for z in [-2.1, 2.1]:
			box(root, Vector3(side * 2.55, 1.2, z), Vector3(0.15, 2.2, 0.15), WHITE)
	box(root, Vector3(0, 2.28, -1.05), Vector3(5.2, 0.13, 0.19), WHITE)
	for side in [-1.0, 1.0]:
		for z in [-2.0, 0.0]:
			var brace := box(
				root, Vector3(side * 1.19, 2.46, z), Vector3(2.7, 0.12, 0.14), Color("#789cbd")
			)
			brace.rotation.z = -side * 0.27
	box(root, Vector3(0, 0.85, -2.0), Vector3(5.25, 1.4, 0.19), DARK)
	lamps[&"farm"] = box(root, Vector3(0, 2.18, -1.05), Vector3(3.9, 0.07, 0.17), MINT, true)
	for idx in range(2):
		var x := -1.38 + idx * 2.76
		box(root, Vector3(x, 0.5, 0), Vector3(1.6, 0.48, 2.8), Color("#436b66"))
		_solid(root, Vector3(x, 0.5, 0), Vector3(1.6, 0.48, 2.8))
		var crop := Node3D.new()
		crop.name = "Crop%d" % idx
		add_child(crop)
		crop.global_position = root.global_position + Vector3(x, 0.92, 0)
		for row in range(5):
			ball(
				crop,
				Vector3(0.12 * (row % 2), 0.04, -0.96 + row * 0.48),
				Vector3(0.61, 0.55, 0.46),
				Color("#7dc072")
			)
		crop.hide()
	_mark(&"farm", root, MINT)


func _shelter(point: Vector3) -> void:
	var root := _platform(point, Vector3(5.4, 0.27, 5.1), CYAN)
	box(root, Vector3(0, 1.27, -2.1), Vector3(4.9, 2.3, 0.4), Color("#637392"))
	for side in [-1.0, 1.0]:
		box(root, Vector3(side * 2.2, 1.32, -0.5), Vector3(0.38, 2.35, 3.15), WHITE)
		box(root, Vector3(side * 1.93, 0.49, -0.9), Vector3(0.43, 0.43, 2.2), DARK)
	box(root, Vector3(0, 2.53, -0.55), Vector3(5.15, 0.44, 3.85), Color("#83849c"))
	box(root, Vector3(0, 2.54, 1.39), Vector3(5.15, 0.13, 0.06), CYAN, true)
	lamps[&"shelter"] = box(root, Vector3(0, 2.1, -1.85), Vector3(2.7, 0.12, 0.08), CYAN, true)
	_mark(&"shelter", root, CYAN)


func _landing_pad() -> void:
	var root := _platform(Vector3(0, 0, 11.7), Vector3(7.1, 0.1, 4.4), CYAN)
	for side in [-1.0, 1.0]:
		box(root, Vector3(side * 2.9, 0.11, 0), Vector3(0.11, 0.05, 2.65), CYAN, true)


func _platform(point: Vector3, size: Vector3, accent: Color) -> Node3D:
	var root := Node3D.new()
	root.position = point
	add_child(root)
	box(root, Vector3(0, size.y * 0.5, 0), size, DARK)
	for sign_x in [-1.0, 1.0]:
		box(
			root,
			Vector3(sign_x * (size.x * 0.5 - 0.27), 0.21, size.z * 0.5 - 0.25),
			Vector3(0.22, 0.07, 0.40),
			accent,
			true
		)
	return root


func _make_item(key: StringName, point: Vector3) -> void:
	var root := Node3D.new()
	root.position = point
	add_child(root)
	props[key] = root
	var color := AMBER if key == &"battery" else MINT
	box(root, Vector3(0, 0.16, 0), Vector3(1.02, 0.30, 0.85), DARK)
	box(root, Vector3(0, 0.53, 0), Vector3(0.71, 0.57, 0.63), color)
	box(root, Vector3(0, 0.55, 0.33), Vector3(0.4, 0.11, 0.06), color.lightened(0.36), true)
	box(root, Vector3(0, 0.85, 0), Vector3(0.32, 0.10, 0.30), DARK)
	_mark(key, root, color)


func _mark(key: StringName, parent: Node3D, color: Color) -> void:
	var marker := Node3D.new()
	parent.add_child(marker)
	marker.position.y = 0.95
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.86
	mesh.outer_radius = 1.05
	mesh.rings = 20
	mesh.ring_segments = 12
	_mesh(marker, Vector3(0, -0.87, 0), mesh, color, true)
	var cap := box(marker, Vector3(0, 0.52, 0), Vector3(0.21, 0.21, 0.21), color, true)
	cap.rotation.z = PI / 4.0
	_rings[key] = marker


func _floor(point: Vector3, dimensions: Vector3, color: Color) -> void:
	box(self, point, dimensions, color)
	_solid(self, point, dimensions)


func _solid(parent: Node3D, point: Vector3, dimensions: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = point
	var shape := BoxShape3D.new()
	shape.size = dimensions
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)


func rock(point: Vector3, shape: Vector3, color: Color) -> void:
	var mesh := SphereMesh.new()
	mesh.radial_segments = 6
	mesh.rings = 3
	var item := _mesh(self, point, mesh, color, false)
	item.scale = shape
	item.rotation.y = point.x * 0.8


static func box(
	parent: Node3D, point: Vector3, size: Vector3, color: Color, glow: bool = false
) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(parent, point, mesh, color, glow)


static func ball(
	parent: Node3D, point: Vector3, size: Vector3, color: Color, glow: bool = false
) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radial_segments = 12
	mesh.rings = 7
	var item := _mesh(parent, point, mesh, color, glow)
	item.scale = size
	return item


static func _mesh(
	parent: Node3D, point: Vector3, mesh: Mesh, color: Color, glow: bool
) -> MeshInstance3D:
	var material := PaperMaterial.solid(color, glow)
	var item := MeshInstance3D.new()
	item.mesh = mesh
	item.material_override = material
	item.position = point
	parent.add_child(item)
	return item
