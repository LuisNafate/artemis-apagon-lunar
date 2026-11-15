class_name LunarPilotFactory
extends RefCounted
## Crea los pilotos de la campaña con la física lunar del registro `open_world`.


static func spawn(parent: Node, index: int, settings: Dictionary) -> CrestPilot:
	var pilot := CrestPilot.new()
	pilot.tint = CrestWorld.BLUE if index == 0 else CrestWorld.AMBER
	pilot.collision_layer = 2
	pilot.collision_mask = 1
	pilot.gravity = float(settings.gravity)
	pilot.jump_speed = float(settings.jump_speed)
	pilot.air_acceleration = float(settings.air_control)
	pilot.position = CrestWorld.SPAWNS[index]
	parent.add_child(pilot)
	pilot.build()
	# Solo el segundo jugador lleva etiqueta; el primero va sin rotulo.
	if index > 0:
		var marker := Label3D.new()
		marker.text = "◆ J2"
		marker.font = CrestWorld.MONO
		marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		marker.modulate = pilot.tint
		marker.position = Vector3.UP * 1.92
		marker.no_depth_test = true
		marker.pixel_size = 0.019
		marker.outline_size = 12
		pilot.add_child(marker)
	return pilot
