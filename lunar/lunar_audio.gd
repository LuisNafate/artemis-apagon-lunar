extends Node

# Efectos originales sintetizados: no requieren archivos externos ni conexión.
const RATE := 22050
const VOICES := 6
const BOOST_DB := 4.0
const DURATIONS := {&"button": 0.09, &"step": 0.13, &"near": 0.18, &"drill": 0.16}

var streams: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _volume := 1.0
var _last_position := Vector3.ZERO
var _tracking := false
var _distance := 0.0
var _spot := &""
var _near_cooldown := 0.0
var _drill_cooldown := 0.0


func _ready() -> void:
	for kind: StringName in DURATIONS:
		streams[kind] = _make_sound(kind, DURATIONS[kind])
	for index in range(VOICES):
		var voice := AudioStreamPlayer.new()
		voice.volume_db = BOOST_DB
		add_child(voice)
		_voices.append(voice)


func set_volume(level: float) -> void:
	_volume = clampf(level, 0.0, 1.0)
	for voice in _voices:
		voice.volume_db = BOOST_DB + linear_to_db(_volume)


func play_effect(kind: StringName) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not streams.has(kind) or _voices.is_empty() or _volume <= 0.0:
		return
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = streams[kind]
	voice.play()


func reset_tracking() -> void:
	_tracking = false
	_distance = 0.0
	_spot = &""
	_near_cooldown = 0.0
	_drill_cooldown = 0.0


func update_player(delta: float, position: Vector3, spot: StringName, mining: bool) -> void:
	_near_cooldown = maxf(0.0, _near_cooldown - delta)
	if _tracking:
		var moved := Vector2(position.x - _last_position.x, position.z - _last_position.z).length()
		# Los saltos de red y los teletransportes no representan pasos.
		if moved < 1.0:
			_distance += moved
			if _distance >= 1.35:
				play_effect(&"step")
				_distance = fposmod(_distance, 1.35)
	else:
		_tracking = true
	_last_position = position
	if spot != _spot and spot != &"" and _near_cooldown <= 0.0:
		play_effect(&"near")
		_near_cooldown = 1.2
	_spot = spot
	if mining:
		_drill_cooldown -= delta
		if _drill_cooldown <= 0.0:
			play_effect(&"drill")
			_drill_cooldown = 0.42
	else:
		_drill_cooldown = 0.0


func _make_sound(kind: StringName, duration: float) -> AudioStreamWAV:
	var count := int(RATE * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	for index in range(count):
		var t := float(index) / RATE
		var progress := float(index) / count
		var envelope := minf(1.0, t * 90.0) * pow(1.0 - progress, 2.0)
		var noise := fposmod(sin(float(index) * 12.9898) * 43758.5453, 2.0) - 1.0
		var sample := 0.0
		match kind:
			&"button":
				sample = sin(TAU * (780.0 * t - 900.0 * t * t)) * 0.45
			&"near":
				sample = (sin(TAU * 620.0 * t) + sin(TAU * 930.0 * t)) * 0.22
			&"step":
				sample = sin(TAU * (110.0 * t - 180.0 * t * t)) * 0.36 + noise * 0.16
			&"drill":
				sample = sin(TAU * 155.0 * t) * 0.25 + noise * 0.32
		var value := int(clampf(sample * envelope, -1.0, 1.0) * 32767.0)
		data.encode_s16(index * 2, value)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	return stream
