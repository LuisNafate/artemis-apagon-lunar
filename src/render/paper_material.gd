class_name PaperMaterial
extends ShaderMaterial
## Material unico del juego. Envuelve src/render/papel.gdshader y conserva los
## nombres de propiedad de StandardMaterial3D que usaba el codigo existente.

const SHADER := preload("res://src/render/papel.gdshader")

var albedo_color: Color = Color.WHITE:
	set(value):
		albedo_color = value
		set_shader_parameter("albedo_color", value)

var emission: Color = Color.BLACK:
	set(value):
		emission = value
		set_shader_parameter("emission_color", value)

var emission_energy_multiplier: float = 0.0:
	set(value):
		emission_energy_multiplier = value
		set_shader_parameter("emission_energy", value)

var unlit: float = 0.0:
	set(value):
		unlit = value
		set_shader_parameter("unlit", value)


func _init(color: Color = Color.WHITE) -> void:
	shader = SHADER
	albedo_color = color


static func solid(color: Color, glow: bool = false) -> PaperMaterial:
	var material := PaperMaterial.new(color)
	if glow:
		material.emission = color
		material.emission_energy_multiplier = 0.38
	return material


## Cambia todos los materiales de un modelo importado al material papel,
## conservando su color y su textura base. Con faceted = false conserva las
## normales del modelo (para modelos texturizados de muchos poligonos).
static func restyle(root: Node, faceted: bool = true) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var item := node as MeshInstance3D
		if item.mesh == null:
			continue
		for surface in range(item.mesh.get_surface_count()):
			var original := item.get_active_material(surface) as BaseMaterial3D
			var paper := PaperMaterial.new()
			if not faceted:
				paper.set_shader_parameter("flat_facets", false)
				paper.set_shader_parameter("facet_variation", 0.0)
			if original != null:
				paper.albedo_color = original.albedo_color
				if original.albedo_texture != null:
					paper.set_shader_parameter("albedo_texture", original.albedo_texture)
					paper.set_shader_parameter("use_texture", true)
			item.set_surface_override_material(surface, paper)
