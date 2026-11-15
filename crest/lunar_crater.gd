class_name LunarCrater
extends MeshInstance3D
## Crater de papel apilado: manto de eyecciones, borde elevado, paredes con
## terrazas y suelo hundido. Facetas planas; el color por faceta sale de la paleta
## del suelo y el relieve produce las sombras del sol y la oclusion ambiental.

const SIDES := 14
const PROPORTIONS := [1.12, 1.0, 0.84, 0.70, 0.58, 0.46, 0.34, 0.20]
const HEIGHTS := [0.0, 0.10, 0.70, 0.95, 0.55, 0.50, 0.18, 0.06]
# Tono de cada anillo al siguiente: manto, flanco, subida, pared, terraza, pared, fondo.
const SHADES := [0.10, 0.04, 0.16, -0.30, -0.14, -0.38, -0.25]


func build(radius: float, height: float, seed_value: int, soil: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var rings: Array[PackedVector3Array] = []
	for _ring in PROPORTIONS:
		rings.append(PackedVector3Array())
	var rotation_offset := rng.randf_range(0.0, TAU)
	for index in range(SIDES):
		var angle := TAU * index / SIDES + rotation_offset + rng.randf_range(-0.08, 0.08)
		var length := radius * rng.randf_range(0.83, 1.14)
		var ridge := rng.randf_range(0.67, 1.32)
		var side := Vector3(cos(angle), 0, sin(angle))
		for ring in range(PROPORTIONS.size()):
			var point := side * length * float(PROPORTIONS[ring])
			point.y = height * float(HEIGHTS[ring]) * ridge
			rings[ring].append(point)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	for index in range(SIDES):
		var next := (index + 1) % SIDES
		for ring in range(PROPORTIONS.size() - 1):
			var shade: float = SHADES[ring]
			var tint := soil.lightened(shade) if shade >= 0.0 else soil.darkened(-shade)
			surface.set_color(tint.lightened(rng.randf_range(0, 0.045)))
			surface.add_vertex(rings[ring][index])
			surface.add_vertex(rings[ring][next])
			surface.add_vertex(rings[ring + 1][index])
			surface.add_vertex(rings[ring][next])
			surface.add_vertex(rings[ring + 1][next])
			surface.add_vertex(rings[ring + 1][index])
		surface.set_color(soil.darkened(0.3))
		surface.add_vertex(rings.back()[index])
		surface.add_vertex(rings.back()[next])
		surface.add_vertex(Vector3.UP * height * 0.04)
	# Rocas pequenas sobre la cresta del borde.
	var crest := 3
	for _rock in range(maxi(3, int(radius * 2.2))):
		var base: Vector3 = rings[crest][rng.randi_range(0, SIDES - 1)]
		var scale_factor := rng.randf_range(0.05, 0.1) * radius
		_add_rock(surface, base, scale_factor, soil.lightened(rng.randf_range(0.16, 0.3)), rng)
	surface.generate_normals()
	mesh = surface.commit()
	material_override = PaperMaterial.new()


static func rock_mesh(seed_value: int = 7) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	_add_rock(surface, Vector3.ZERO, 1.0, Color.WHITE, rng)
	surface.generate_normals()
	return surface.commit()


static func _add_rock(
	surface: SurfaceTool, base: Vector3, size: float, tint: Color, rng: RandomNumberGenerator
) -> void:
	var sides := 5
	var top := base + Vector3(rng.randf_range(-0.12, 0.12), 0.7, rng.randf_range(-0.12, 0.12)) * size
	var bottom := base + Vector3(0, -0.12, 0) * size
	var ring: Array[Vector3] = []
	var phase := rng.randf_range(0.0, TAU)
	for index in range(sides):
		var angle := TAU * index / sides + phase + rng.randf_range(-0.25, 0.25)
		var reach := rng.randf_range(0.7, 1.15)
		ring.append(
			base + Vector3(cos(angle) * reach, rng.randf_range(0.05, 0.22), sin(angle) * reach) * size
		)
	for index in range(sides):
		var next := (index + 1) % sides
		surface.set_color(tint.lightened(rng.randf_range(0.0, 0.08)))
		surface.add_vertex(ring[index])
		surface.add_vertex(ring[next])
		surface.add_vertex(top)
		surface.set_color(tint.darkened(rng.randf_range(0.1, 0.25)))
		surface.add_vertex(ring[next])
		surface.add_vertex(ring[index])
		surface.add_vertex(bottom)
