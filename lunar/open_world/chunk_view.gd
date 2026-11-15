class_name ChunkView
extends Node3D

## Vista de un chunk: malla facetada, colision de 1 m, rocas y marcadores de deposito.
## `mesh_arrays` es estatica y pura para poder ejecutarse en WorkerThreadPool.

const MODEL_ICE := preload("res://assets/props_luna/estaciones/deposito_hielo.glb")
const ICE_SCALE := 1.35
const ICE_HALF_HEIGHT := 0.49
const ORE_COLOR := Color("#ffbc76")
const EMPTY_COLOR := Color("#3a3844")
const EMPTY_SINK := 0.4
const ORE_SIZE := 0.7

## Radio de colision de una roca a escala 1; lo fija el streamer desde los ajustes.
var rock_radius := 0.6
var data: ChunkData
var body: StaticBody3D
var _markers: Dictionary = {}


## Vertices y normales planas de la malla del terreno, en coordenadas locales del chunk.
static func mesh_arrays(source: ChunkData) -> Array:
	var step := source.size / float(source.samples - 1)
	var cells := source.samples - 1
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	vertices.resize(cells * cells * 6)
	normals.resize(cells * cells * 6)
	var at := 0
	for row in range(cells):
		for col in range(cells):
			var a := _corner(source, col, row, step)
			var b := _corner(source, col + 1, row, step)
			var c := _corner(source, col, row + 1, step)
			var d := _corner(source, col + 1, row + 1, step)
			var corners: Array[Vector3] = [a, b, c, b, d, c]
			for half in range(2):
				var base := half * 3
				var normal := (
					(corners[base + 2] - corners[base])
					. cross(corners[base + 1] - corners[base])
					. normalized()
				)
				for i in range(3):
					vertices[at] = corners[base + i]
					normals[at] = normal
					at += 1
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	return arrays


static func _corner(source: ChunkData, col: int, row: int, step: float) -> Vector3:
	return Vector3(float(col) * step, source.heights[row * source.samples + col], float(row) * step)


## Construye mallas, colision, rocas y marcadores. `arrays` evita recalcular la malla
## cuando un hilo de trabajo ya la preparo.
func build(source: ChunkData, soil: Color, arrays: Array = []) -> void:
	data = source
	position = Vector3(float(source.coord.x), 0.0, float(source.coord.y)) * source.size
	if arrays.is_empty():
		arrays = mesh_arrays(source)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var ground := MeshInstance3D.new()
	ground.name = "Terreno"
	ground.mesh = mesh
	ground.material_override = PaperMaterial.solid(soil)
	add_child(ground)
	_add_collision(source)
	_add_rocks(source, soil)
	for deposit in source.deposits:
		_add_marker(deposit)


## Alterna el marcador entre la forma llena y la vacia.
func set_deposit(id: int, left: int) -> void:
	var marker: Dictionary = _markers.get(id, {})
	if marker.is_empty():
		return
	var shape: Node3D = marker.shape
	var empty := left <= 0
	shape.position.y = float(marker.base_y) - (EMPTY_SINK if empty else 0.0)
	# Se tiñen los materiales propios del marcador: cambiar el material de un modelo
	# importado deja errores del servidor de render al liberarlo (visto en headless).
	for paint: Array in marker.paints:
		var material: PaperMaterial = paint[0]
		material.albedo_color = EMPTY_COLOR if empty else paint[1]
		material.emission_energy_multiplier = 0.0 if empty else paint[2]


func _add_collision(source: ChunkData) -> void:
	var step := source.size / float(source.samples - 1)
	var shape := HeightMapShape3D.new()
	shape.map_width = source.samples
	shape.map_depth = source.samples
	shape.map_data = source.heights
	body = StaticBody3D.new()
	body.name = "Suelo"
	body.collision_layer = 1
	body.position = Vector3(source.size * 0.5, 0.0, source.size * 0.5)
	body.scale = Vector3(step, 1.0, step)
	var owner_id := body.create_shape_owner(body)
	body.shape_owner_add_shape(owner_id, shape)
	add_child(body)


func _add_rocks(source: ChunkData, soil: Color) -> void:
	if source.rocks.is_empty():
		return
	var rocks := MultiMesh.new()
	rocks.transform_format = MultiMesh.TRANSFORM_3D
	rocks.use_colors = true
	rocks.mesh = LunarCrater.rock_mesh(7)
	rocks.instance_count = source.rocks.size()
	for index in range(source.rocks.size()):
		var rock: Dictionary = source.rocks[index]
		var size: float = float(rock.scale) * rock_radius
		var rng := RandomNumberGenerator.new()
		rng.seed = int(rock.seed)
		var spin := Basis(Vector3.UP, rng.randf_range(0.0, TAU))
		var basis := spin.scaled(Vector3(size, size * rng.randf_range(0.7, 1.3), size))
		rocks.set_instance_transform(index, Transform3D(basis, rock.point - position))
		rocks.set_instance_color(index, soil.lightened(rng.randf_range(0.06, 0.26)))
	var field := MultiMeshInstance3D.new()
	field.name = "Rocas"
	field.multimesh = rocks
	field.material_override = PaperMaterial.new()
	add_child(field)


func _add_marker(deposit: Dictionary) -> void:
	var pivot := Node3D.new()
	pivot.name = "Deposito%d" % int(deposit.id)
	pivot.position = deposit.point - position
	add_child(pivot)
	var shape: Node3D
	var base_y := 0.0
	if deposit.kind == &"ice":
		shape = MODEL_ICE.instantiate()
		PaperMaterial.restyle(shape, false)
		shape.scale = Vector3.ONE * ICE_SCALE
		base_y = ICE_HALF_HEIGHT * ICE_SCALE
	else:
		var piece := MeshInstance3D.new()
		piece.mesh = LunarCrater.rock_mesh(int(deposit.id))
		piece.scale = Vector3.ONE * ORE_SIZE
		piece.material_override = PaperMaterial.solid(ORE_COLOR, true)
		shape = piece
		base_y = ORE_SIZE * 0.3
	shape.position.y = base_y
	pivot.add_child(shape)
	var paints: Array = []
	var items: Array[Node] = shape.find_children("*", "MeshInstance3D", true, false)
	if shape is MeshInstance3D:
		items.append(shape)
	for item: MeshInstance3D in items:
		var materials: Array[Material] = [item.material_override]
		for surface in range(item.get_surface_override_material_count()):
			materials.append(item.get_surface_override_material(surface))
		for material in materials:
			var paper := material as PaperMaterial
			if paper != null:
				paints.append([paper, paper.albedo_color, paper.emission_energy_multiplier])
	_markers[int(deposit.id)] = {"shape": shape, "base_y": base_y, "paints": paints}
