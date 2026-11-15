class_name LunarBackdrop
extends Control

const EARTH := preload("res://assets/props_luna/nasa/tierra_apolo17.jpg")
const SKY := Color("#0c1423")

var orbital := false
var planet_scale := 1.0
var earth_mode := "visible"
var earth_level := 1.0
var relief := 0.16
## Desplazamiento lateral de la camara en anchos de pantalla: mueve las crestas del horizonte.
var pan := 0.0
var _seed := 37
var _age := 0.0
var _stars := PackedVector2Array()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var rng := RandomNumberGenerator.new()
	rng.seed = 2116
	for index in range(113):
		_stars.append(Vector2(rng.randf(), rng.randf() * (1.0 if orbital else 0.50)))
	var earth := TextureRect.new()
	earth.name = "Earth"
	earth.texture = EARTH
	earth.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	earth.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var blend := CanvasItemMaterial.new()
	blend.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	earth.material = blend
	earth.z_index = 1
	add_child(earth)
	resized.connect(_place_earth)
	_place_earth()


func configure(base_id: String, landscape: Dictionary) -> void:
	earth_mode = landscape.earth
	relief = float(landscape.relief)
	_seed = hash(base_id)
	earth_level = 0.0 if earth_mode == "hidden" else 1.0
	_place_earth()
	queue_redraw()


func update_sky(delta: float, radio_cut: bool) -> void:
	_age += delta
	var shown := earth_mode == "visible" or (earth_mode == "radio" and not radio_cut)
	earth_level = move_toward(earth_level, float(shown), delta * 0.55)
	_place_earth()
	queue_redraw()


func _place_earth() -> void:
	var earth := get_node_or_null("Earth") as TextureRect
	if earth == null:
		return
	var diameter := size.y * (0.41 * planet_scale if orbital else 0.205)
	earth.size = Vector2.ONE * diameter
	earth.position = (
		size * (Vector2(0.77, 0.39) if orbital else Vector2(0.82, 0.156)) - earth.size * 0.5
	)
	earth.position.x += sin(_age * 0.13) * 5.0
	earth.modulate.a = earth_level * 0.93


func _draw() -> void:
	if size.x <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), SKY)
	for index in range(_stars.size()):
		var glow := 0.32 + 0.15 * sin(_age * 0.52 + float(index) * 1.6)
		var point := _stars[index] * size
		point.x = fposmod(point.x + _age * (0.9 + float(index % 3) * 0.25), size.x)
		draw_circle(point, 1.4 if index % 11 == 0 else 0.74, Color(0.82, 0.90, 1.0, glow))
	if orbital:
		_draw_orbital_limb()
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	for index in range(3):
		var color: Color = [Color("#283043"), Color("#3b4155"), Color("#555367")][index]
		var line := 0.178 + index * 0.047
		var margins := PackedFloat32Array()
		for step in range(18):
			margins.append(rng.randf_range(-relief, relief) * (0.15 + index * 0.07))
		# Las crestas se repiten cada pantalla; las mas cercanas se desplazan mas (paralaje).
		var shift := fposmod(pan * (0.6 + index * 0.2), 1.0)
		var points := PackedVector2Array()
		for step in range(37):
			var x := (float(step) / 18.0 - shift) * size.x
			points.append(Vector2(x, (line + margins[step % 18]) * size.y))
		points.append(Vector2(points[-1].x, size.y))
		points.append(Vector2(points[0].x, size.y))
		draw_colored_polygon(points, color)


func _draw_orbital_limb() -> void:
	var center := Vector2(size.x * 0.16, size.y * 1.46)
	var radius := size.y * 0.68
	draw_circle(center, radius, Color("#393e52"), true, -1.0, true)
	draw_circle(center + Vector2(8, 19), radius * 0.96, Color("#4d4c5b"), true, -1.0, true)
	draw_arc(center, radius - 1.5, PI * 1.18, PI * 1.89, 44, Color("#77758a"), 2.8, true)
	for detail: Vector3 in [
		Vector3(-0.48, -0.42, 0.13),
		Vector3(-0.22, -0.67, 0.16),
		Vector3(0.13, -0.73, 0.08),
		Vector3(0.46, -0.56, 0.10)
	]:
		var point := center + Vector2(detail.x, detail.y) * radius
		draw_set_transform(point, -0.09, Vector2(1.0, 0.47))
		draw_circle(Vector2.ZERO, radius * detail.z, Color("#605e6c"), true, -1.0, true)
		draw_circle(Vector2(0, 4), radius * detail.z * 0.79, Color("#383948"), true, -1.0, true)
	draw_set_transform(Vector2.ZERO)
