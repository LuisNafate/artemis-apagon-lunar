class_name EnclosureCases
extends RefCounted

## Casos del muro, la puerta, la flecha y las rutas alrededor de la base (open_world_suite).

var _suite: Node


func _init(suite: Node) -> void:
	_suite = suite


func run() -> void:
	await _enclosure()
	await _around_base()


## Muro, puerta corredera y flecha de regreso a la base (solo campaña).
func _enclosure() -> void:
	_suite._cases += 1
	var game: Node = await _suite._game_solo("mons_mouton_plateau")
	var s: Dictionary = game.sim.rules.open_world
	var flat: Rect2 = _suite._rect(s.base_flat_rect)
	var enclosure: BaseEnclosure = game.world.enclosure
	var arrow: BaseArrow = game.world.base_arrow
	_suite._check(enclosure != null and arrow != null, "the campaign base builds wall and arrow")
	var door := enclosure.door_point()
	_suite._check(
		is_equal_approx(door.x, flat.end.x + float(s.base_wall.thickness) * 0.5),
		"door sits in the east wall"
	)
	_suite._check(
		is_equal_approx(enclosure.outside_point().x - door.x, float(s.base_wall.outside_distance)),
		"outside point is beyond the door"
	)
	# Ningun lado se puede cruzar, ni caminando ni saltando contra el.
	var trials: Array = []
	for x in [-14.0, 0.0, 12.0]:
		trials.append([Vector3(x, 0.1, -9.5), Vector2(x, -30.0)])
		trials.append([Vector3(x, 0.1, 9.5), Vector2(x, 30.0)])
	for z in [-8.0, -2.0, 8.0]:
		trials.append([Vector3(-18.5, 0.1, z), Vector2(-40.0, z)])
	for z in [-8.0, -5.0, 8.0, 10.0]:
		trials.append([Vector3(18.5, 0.1, z), Vector2(40.0, z)])
	var trial := 0
	for item: Array in trials:
		for jumping in [false, true]:
			trial += 1
			game._set_positions([item[0], Vector3.ZERO])
			var escaped := false
			var nearest := INF
			for frame in range(100):
				game._route[0] = PackedVector2Array([item[1]])
				game._jump[0] = jumping and frame % 20 == 0
				await _suite._frames(1)
				var at: Vector3 = game.pilots[0].position
				escaped = escaped or not flat.has_point(Vector2(at.x, at.z))
				nearest = minf(nearest, _wall_gap(flat, at))
			_suite._check(
				not escaped, "trial %d (%s, jump %s) stays inside" % [trial, item[0], jumping]
			)
			_suite._check(
				nearest < 0.7, "trial %d pushed against the wall (%.2f m)" % [trial, nearest]
			)
	game._route[0].clear()
	# La puerta se abre sola con un piloto cerca y se cierra al alejarse.
	game._set_positions([Vector3(door.x - 2.0, 0.1, door.z), Vector3.ZERO])
	await _suite._frames(60)
	_suite._check(
		enclosure.is_open() and enclosure.openness > 0.99, "door opens with a pilot at 2 m"
	)
	game._set_positions([Vector3(door.x - 3.5, 0.1, door.z), Vector3.ZERO])
	await _suite._frames(60)
	_suite._check(not enclosure.is_open() and enclosure.openness < 0.01, "door closes at 3.5 m")
	# Sin el juego de por medio: la puerta solo depende de las posiciones que recibe, las
	# mismas en el anfitrion y en el invitado.
	var shared := BaseEnclosure.new(s)
	_suite.add_child(shared)
	shared.build()
	var unseen: Array[Vector3] = [Vector3(door.x - 8.0, 0.0, door.z)]
	shared.update_door(unseen)
	await _suite._frames(40)
	_suite._check(shared.openness < 0.01, "a distant pilot leaves the door closed")
	var near: Array[Vector3] = [Vector3(door.x - 8.0, 0.0, door.z), door + Vector3(2.9, 0, 0)]
	shared.update_door(near)
	await _suite._frames(40)
	_suite._check(shared.openness > 0.99, "either pilot opens it")
	shared.update_door(unseen)
	await _suite._frames(40)
	_suite._check(shared.openness < 0.01, "it closes again when both walk away")
	shared.queue_free()
	# Se sale y se vuelve a entrar por la puerta siguiendo la ruta.
	game._set_positions([CrestWorld.SPAWNS[0], Vector3.ZERO])
	await _suite._frames(30)
	game._set_destination(0, enclosure.outside_point())
	var frames := 0
	while game.pilots[0].position.x < flat.end.x + 0.8 and frames < 900:
		frames += 1
		await _suite._frames(1)
	_suite._check(
		game.pilots[0].position.x >= flat.end.x + 0.8, "the route leads out through the door"
	)
	game._set_destination(0, CrestWorld.SPAWNS[0])
	frames = 0
	while game.pilots[0].position.x > flat.end.x - 1.0 and frames < 900:
		frames += 1
		await _suite._frames(1)
	_suite._check(
		game.pilots[0].position.x <= flat.end.x - 1.0, "from outside the route returns inside"
	)
	_suite._check(
		flat.has_point(Vector2(game.pilots[0].position.x, game.pilots[0].position.z)),
		"pilot is back inside"
	)
	# Ninguna ruta cruza el muro: entra y sale por la puerta.
	var tap_out := door + Vector3(10.0, 0.0, 0.0)
	for start: Vector3 in [Vector3(5, 0.1, -8), Vector3(-12, 0.1, 7), CrestWorld.SPAWNS[1]]:
		game._set_positions([start, Vector3.ZERO])
		await _suite._frames(30)
		var outbound: PackedVector2Array = game._planner.plan(game._routes, start, tap_out, s)
		var inbound: PackedVector2Array = game._planner.plan(game._routes, tap_out, start, s)
		for route: PackedVector2Array in [outbound, inbound]:
			var origin := start if route == outbound else tap_out
			_suite._check(route.size() >= 2, "route across the door exists from %s" % start)
			_suite._check(
				not _route_hits_wall(enclosure, origin, route),
				"route from %s avoids the wall" % origin
			)
	# La flecha: solo fuera, hacia la puerta, con los metros.
	var spots: Array[Vector3] = [
		Vector3(-60, 1, 40),
		Vector3(45, 1, -70),
		Vector3(30, 1, 3),
		Vector3(250, 1, -30),
		Vector3(-10, 1, -45)
	]
	for spot in spots:
		game._set_positions([spot, Vector3.ZERO])
		await _suite._until(func() -> bool: return game.streamer.is_ready_at(spot))
		await _suite._frames(20)
		var at: Vector3 = game.pilots[0].position
		var to_door := Vector2(door.x - at.x, door.z - at.z)
		var heading := Vector2(arrow.global_basis.z.x, arrow.global_basis.z.z)
		_suite._check(arrow.visible, "arrow is visible at %s" % spot)
		_suite._check(
			(
				rad_to_deg(heading.angle_to(to_door)) < 3.0
				and rad_to_deg(heading.angle_to(to_door)) > -3.0
			),
			"arrow points at the door from %s" % spot
		)
		_suite._check(
			arrow.label.text == "%d m" % roundi(to_door.length()),
			"arrow label shows %d m (%s)" % [roundi(to_door.length()), arrow.label.text]
		)
	game._set_positions([Vector3(2, 0.1, 2), Vector3.ZERO])
	await _suite._frames(30)
	_suite._check(not arrow.visible, "no arrow inside the base")
	DirAccess.remove_absolute(game.profile_path)
	game.get_parent().queue_free()
	await _suite.get_tree().process_frame


## Las rutas rodean la base: nunca cruzan el muro y un piloto que las sigue llega al destino.
func _around_base() -> void:
	_suite._cases += 1
	var game: Node = await _suite._game_solo("mons_mouton_plateau")
	var s: Dictionary = game.sim.rules.open_world
	var enclosure: BaseEnclosure = game.world.enclosure
	var inside := Vector3(5, 0.1, -8)
	var taps := {
		"north near": Vector3(5, 0, -22),
		"north far": Vector3(5, 0, -90),
		"south near": Vector3(5, 0, 22),
		"south far": Vector3(5, 0, 90),
		"west near": Vector3(-30, 0, 0),
		"west far": Vector3(-100, 0, 0),
		"east far": Vector3(100, 0, 20),
	}
	for label: String in taps:
		var tap: Vector3 = taps[label]
		var out: PackedVector2Array = game._planner.plan(game._routes, inside, tap, s)
		_suite._check(out.size() >= 2, "route inside to %s exists" % label)
		_suite._check(
			not _route_hits_wall(enclosure, inside, out), "inside to %s avoids the wall" % label
		)
		_suite._check(
			out[out.size() - 1].distance_to(Vector2(tap.x, tap.z)) < 1.0, "%s ends there" % label
		)
		var back: PackedVector2Array = game._planner.plan(game._routes, tap, inside, s)
		_suite._check(
			not _route_hits_wall(enclosure, tap, back), "%s to inside avoids the wall" % label
		)
	var pairs := [
		[Vector3(5, 0, -22), Vector3(5, 0, 22)],
		[Vector3(-35, 0, 0), Vector3(35, 0, 0)],
		[Vector3(5, 0, 90), Vector3(5, 0, -90)],
		[Vector3(-100, 0, 3), Vector3(100, 0, -3)],
		[Vector3(30, 0, -15), Vector3(-30, 0, 15)],
		[Vector3(21, 0, -12), Vector3(21, 0, 12)],
	]
	for pair: Array in pairs:
		var route: PackedVector2Array = game._planner.plan(game._routes, pair[0], pair[1], s)
		_suite._check(
			not _route_hits_wall(enclosure, pair[0], route), "%s to %s avoids the wall" % pair
		)
		_suite._check(
			route[route.size() - 1].distance_to(Vector2(pair[1].x, pair[1].z)) < 1.0,
			"%s to %s ends at the tap" % pair
		)
	# Un piloto que sigue la ruta llega, no se queda pegado al muro.
	var trips := [
		[inside, Vector3(5, 0, -22)],
		[inside, Vector3(-30, 0, 0)],
		[Vector3(5, 0, -22), Vector3(5, 0, 22)],
		[Vector3(-30, 0, 8), Vector3(32, 0, -8)],
	]
	for trip: Array in trips:
		game._set_positions([trip[0], Vector3.ZERO])
		await _suite._until(func() -> bool: return game.streamer.is_ready_at(trip[0]))
		await _suite._frames(30)
		game._set_destination(0, trip[1])
		var frames := 0
		var target := Vector2(trip[1].x, trip[1].z)
		while _flat_distance(game.pilots[0].position, target) > 1.5 and frames < 3000:
			frames += 1
			await _suite._frames(1)
		_suite._check(
			frames < 3000, "pilot reaches %s from %s (%d frames)" % [trip[1], trip[0], frames]
		)
	DirAccess.remove_absolute(game.profile_path)
	game.get_parent().queue_free()
	await _suite.get_tree().process_frame


func _flat_distance(point: Vector3, target: Vector2) -> float:
	return Vector2(point.x, point.z).distance_to(target)


## Distancia del piloto al muro mas cercano (en XZ, desde el borde plano).
func _wall_gap(flat: Rect2, at: Vector3) -> float:
	return minf(
		minf(at.x - flat.position.x, flat.end.x - at.x),
		minf(at.z - flat.position.y, flat.end.y - at.z)
	)


## Algun punto de la ruta (muestreada cada 5 cm) cae dentro de una pieza solida del muro.
func _route_hits_wall(enclosure: BaseEnclosure, origin: Vector3, route: PackedVector2Array) -> bool:
	var previous := Vector2(origin.x, origin.z)
	for point in route:
		var length := previous.distance_to(point)
		for step in range(int(length / 0.05) + 1):
			var sample := previous.lerp(point, float(step) * 0.05 / maxf(length, 0.001))
			for rect in enclosure.wall_rects():
				if rect.has_point(sample):
					return true
		previous = point
	return false
