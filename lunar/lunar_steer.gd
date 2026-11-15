class_name LunarSteer
extends RefCounted

## Del joystick a una direccion en el plano del suelo, relativa a la camara (que nunca gira).


static func direction(camera: Camera3D, input: Vector2) -> Vector2:
	var right := Vector2(camera.basis.x.x, camera.basis.x.z).normalized()
	var back := Vector2(camera.basis.z.x, camera.basis.z.z).normalized()
	return (right * input.x + back * input.y).limit_length(input.length())
