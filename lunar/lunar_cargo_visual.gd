class_name LunarCargoVisual
extends RefCounted

## Aspecto de las cajas de carga. `host` guarda las plantillas ocultas de los modelos.

const MODELS := {&"ice": [preload("res://assets/props_luna/estaciones/caja_hielo.glb"), 0.62]}
const MATCOLORS := {
	&"sample": CrestWorld.BLUE,
	&"ice": CrestWorld.BLUE,
	&"ore": CrestWorld.PURPLE,
	&"fuel": CrestWorld.AMBER,
	&"food": CrestWorld.LIME
}


static func build(host: Node, templates: Dictionary, box: Node3D, kind: StringName) -> void:
	match kind:
		&"ice":
			box.add_child(_model(host, templates, kind))
		&"food":
			FieldWorld.box(box, Vector3(0, -0.08, 0), Vector3(0.52, 0.29, 0.40), Color("#e8d9b5"))
			FieldWorld.box(box, Vector3(0, 0.077, 0), Vector3(0.24, 0.026, 0.34), CrestWorld.LIME)
			FieldWorld.box(box, Vector3(0, 0.094, 0), Vector3(0.16, 0.013, 0.05), CrestWorld.FRAME)
		&"fuel":
			FieldWorld.box(box, Vector3.ZERO, Vector3(0.45, 0.47, 0.37), CrestWorld.AMBER)
			FieldWorld.box(
				box, Vector3(0.11, 0.261, 0), Vector3(0.14, 0.052, 0.18), CrestWorld.FRAME
			)
			FieldWorld.box(
				box, Vector3(0, -0.12, 0.188), Vector3(0.32, 0.08, 0.015), CrestWorld.FRAME
			)
		_:
			FieldWorld.box(box, Vector3.ZERO, Vector3(0.53, 0.48, 0.49), MATCOLORS[kind])
			FieldWorld.box(box, Vector3.UP * 0.245, Vector3(0.25, 0.038, 0.44), CrestWorld.FRAME)


## Copia del modelo de carga. Las copias comparten los materiales de una plantilla oculta:
## liberar una caja con materiales propios deja errores del servidor de render (headless).
static func _model(host: Node, templates: Dictionary, kind: StringName) -> Node3D:
	if not templates.has(kind):
		var info: Array = MODELS[kind]
		var template: Node3D = (info[0] as PackedScene).instantiate()
		PaperMaterial.restyle(template, false)
		template.scale = Vector3.ONE * float(info[1])
		template.hide()
		host.add_child(template)
		templates[kind] = template
	var model: Node3D = (templates[kind] as Node3D).duplicate()
	model.show()
	return model
