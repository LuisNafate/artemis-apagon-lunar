class_name LunarCrater
extends MeshInstance3D

const SIDES := 11


func build(radius: float, height: float, seed_value: int, soil: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var rings: Array[PackedVector3Array] = [[], [], [], [], []]
	var proportions := [1.0, 0.76, 0.65, 0.39, 0.16]
	var heights := [0.0, 0.79, 0.9, 0.16, 0.08]
	var rotation_offset := rng.randf_range(0.0, TAU)
	for index in range(SIDES):
		var angle := TAU * index / SIDES + rotation_offset + rng.randf_range(-0.1, 0.1)
		var length := radius * rng.randf_range(0.83, 1.14)
		var ridge := rng.randf_range(0.67, 1.32)
		var side := Vector3(cos(angle), 0, sin(angle))
		for ring in range(rings.size()):
			var point := side * length * float(proportions[ring])
			point.y = height * float(heights[ring]) * ridge
			rings[ring].append(point)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	var tints := [soil, soil.lightened(0.12), soil.darkened(0.33), soil.darkened(0.22)]
	for index in range(SIDES):
		var next := (index + 1) % SIDES
		for ring in range(rings.size() - 1):
			surface.set_color(tints[ring].lightened(rng.randf_range(0, 0.045)))
			surface.add_vertex(rings[ring][index])
			surface.add_vertex(rings[ring][next])
			surface.add_vertex(rings[ring + 1][index])
			surface.add_vertex(rings[ring][next])
			surface.add_vertex(rings[ring + 1][next])
			surface.add_vertex(rings[ring + 1][index])
		surface.set_color(soil.darkened(0.23))
		surface.add_vertex(rings.back()[index])
		surface.add_vertex(rings.back()[next])
		surface.add_vertex(Vector3.UP * height * 0.07)
	surface.generate_normals()
	mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.96
	material_override = material
