class_name CrestIntro
extends Control

signal finished

const BEATS := [
	["ATERRIZAJE", "Dos cadetes aterrizan con un refugio, semillas y un cohete de regreso."],
	[
		"MONTAJE DE LA BASE",
		"Unen el refugio a los paneles. Con luz, la base puede producir aire y comida."
	],
	[
		"MENSAJE DE TIERRA",
		"Se acerca una alerta solar. Preparen el cohete y regresen juntos a órbita."
	]
]
const BLUE := Color("#83d8ee")
const ORANGE := Color("#ffc88a")
const INK := Color("#0e192a")
const DISPLAY := preload("res://assets/ui/fonts/BarlowCondensed-Bold.ttf")
const BODY := preload("res://assets/ui/fonts/Barlow-SemiBold.ttf")
const MONO := preload("res://assets/ui/fonts/IBMPlexMono-Medium.ttf")

var progress := 0.0
var _duration := 14.5
var _title := ""
var _dispatch := ""
var _beat := 0
var _active := false
var _skip: Button


func _ready() -> void:
	size = Vector2(1280, 720)
	mouse_filter = MOUSE_FILTER_STOP
	_skip = Button.new()
	_skip.text = "Omitir  ·  Esc"
	_skip.focus_mode = FOCUS_NONE
	_skip.position = Vector2(1090, 52)
	_skip.size = Vector2(140, 44)
	_skip.add_theme_font_override("font", BODY)
	_skip.add_theme_font_size_override("font_size", 20)
	add_child(_skip)
	_skip.pressed.connect(skip)
	hide()


func play(base_name: String, seconds: float, base_id: StringName) -> void:
	_title = base_name
	match base_id:
		&"nobile":
			_dispatch = "Las colinas cortan la radio. Confirmen el vuelo cuando vuelva la señal."
		&"taurus":
			_dispatch = "Fallan los paneles. Reserven energía para respirar y preparar el regreso."
		_:
			_dispatch = BEATS[2][1]
	_duration = seconds
	_beat = 0
	progress = 0.0
	_active = true
	show()
	queue_redraw()


func skip() -> void:
	if not _active:
		return
	_active = false
	progress = 1.0
	hide()
	finished.emit()


func _process(delta: float) -> void:
	if not _active:
		return
	progress = minf(1.0, progress + delta / _duration)
	_beat = mini(2, floori(progress * 3.0))
	if progress >= 1.0:
		skip()
	queue_redraw()


func _draw() -> void:
	var screen := Vector2(1280, 720)
	draw_rect(Rect2(Vector2.ZERO, screen), Color("#0b14294a"))
	draw_rect(Rect2(0, 0, 1280, 122), INK)
	draw_rect(Rect2(0, 540, 1280, 180), INK)
	draw_rect(Rect2(50, 47, 4, 56), ORANGE)
	draw_string(MONO, Vector2(68, 65), "BITÁCORA DE LA MISIÓN", 0, -1, 15, BLUE)
	draw_string(DISPLAY, Vector2(68, 105), _title, 0, -1, 43, Color.WHITE)
	draw_string(MONO, Vector2(68, 579), BEATS[_beat][0], 0, -1, 17, ORANGE)
	draw_string(
		BODY, Vector2(68, 626), _dispatch if _beat == 2 else BEATS[_beat][1], 0, -1, 27, Color.WHITE
	)
	draw_rect(Rect2(68, 674, 1144, 3), Color("#364966"))
	draw_rect(Rect2(68, 674, 1144 * progress, 3), BLUE)
	if _beat == 1:
		_draw_plan()
	elif _beat == 2:
		_draw_transmission()


func _draw_plan() -> void:
	var center := Vector2(640, 346)
	var alpha := lerpf(0.25, 0.86, sin(progress * PI))
	var ink := Color(BLUE, alpha)
	for index in range(5):
		var corner := center + Vector2(-144 + index * 65, -45 + index * 16)
		var diamond := PackedVector2Array(
			[
				corner,
				corner + Vector2(65, -26),
				corner + Vector2(130, 0),
				corner + Vector2(65, 26),
				corner
			]
		)
		if progress * 15.0 >= index + 5:
			draw_polyline(diamond, ink, 2, true)


func _draw_transmission() -> void:
	var center := Vector2(785, 436)
	var base := fposmod(progress * 8.0, 1.0)
	for number in range(3):
		var wave := fposmod(base + number * 0.33, 1.0)
		draw_arc(center, 24 + wave * 120, -2.65, -0.46, 20, Color(ORANGE, 0.78 * (1 - wave)), 3)
