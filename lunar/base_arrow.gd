class_name BaseArrow
extends Node3D

## Flecha plana junto al piloto que apunta a la puerta de la base, con la distancia en metros.
## Solo se ve fuera de la base.

var label := Label3D.new()
var _distance := 1.8
var _hover := 0.25


func _init(settings: Dictionary = {}) -> void:
	if not settings.is_empty():
		_distance = float(settings.base_wall.arrow_distance)
		_hover = float(settings.base_wall.arrow_height)


func build() -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Cola y punta (triangulos en XZ, la punta hacia +Z) en las dos orientaciones: se ve desde
	# cualquier lado sin depender del culling.
	var corners := PackedVector3Array(
		[
			Vector3(-0.14, 0, -0.5),
			Vector3(0.14, 0, -0.5),
			Vector3(0.14, 0, 0.1),
			Vector3(-0.14, 0, -0.5),
			Vector3(0.14, 0, 0.1),
			Vector3(-0.14, 0, 0.1),
			Vector3(-0.4, 0, 0.1),
			Vector3(0.4, 0, 0.1),
			Vector3(0, 0, 0.7)
		]
	)
	for first in range(0, corners.size(), 3):
		for order in [0, 1, 2, 0, 2, 1]:
			tool.add_vertex(corners[first + order])
	tool.generate_normals()
	var item := MeshInstance3D.new()
	item.mesh = tool.commit()
	item.material_override = PaperMaterial.solid(CrestWorld.AMBER, true)
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(item)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.009
	label.font_size = 64
	label.outline_size = 14
	label.modulate = Color("#fff4dc")
	label.outline_modulate = CrestWorld.FRAME
	label.position = Vector3(0, 0.7, 0)
	add_child(label)
	scale = Vector3.ONE * 1.4
	hide()


## Pone la flecha delante del piloto, mirando a `target`; solo se ve si `visible_outside`.
func point_to(pilot: Vector3, target: Vector3, visible_outside: bool) -> void:
	visible = visible_outside
	if not visible_outside:
		return
	var way := Vector2(target.x - pilot.x, target.z - pilot.z)
	var away := way.length()
	var heading := way / away if away > 0.001 else Vector2.DOWN
	position = Vector3(
		pilot.x + heading.x * _distance, pilot.y + _hover, pilot.z + heading.y * _distance
	)
	rotation.y = atan2(heading.x, heading.y)
	label.text = "%d m" % roundi(away)
