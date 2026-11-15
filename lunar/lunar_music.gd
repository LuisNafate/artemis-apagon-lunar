extends Node

const FADE_SECONDS := 2.0
const MUSIC_DB := -7.0
const TRACKS := {
	&"menu": "res://assets/music/menu.mp3",
	&"day": "res://assets/music/dia.mp3",
	&"night": "res://assets/music/noche.mp3"
}

var players: Dictionary = {}
var levels: Dictionary = {}
var current := &""


func _ready() -> void:
	for name: StringName in TRACKS:
		var path: String = TRACKS[name]
		if not ResourceLoader.exists(path):
			continue
		var track := load(path) as AudioStreamMP3
		if track == null:
			continue
		track = track.duplicate() as AudioStreamMP3
		track.loop = true
		var player := AudioStreamPlayer.new()
		player.stream = track
		player.volume_db = -80.0
		add_child(player)
		players[name] = player
		levels[name] = 0.0


func set_context(context: StringName) -> void:
	if context == current:
		return
	current = context
	if DisplayServer.get_name() == "headless":
		return
	if not players.has(context):
		return
	var player: AudioStreamPlayer = players[context]
	if player.stream_paused:
		player.stream_paused = false
	elif not player.playing:
		player.play()


func _exit_tree() -> void:
	for player: AudioStreamPlayer in players.values():
		player.stop()


func _process(delta: float) -> void:
	for name: StringName in players:
		var player: AudioStreamPlayer = players[name]
		var target := 1.0 if name == current else 0.0
		var level := move_toward(float(levels[name]), target, delta / FADE_SECONDS)
		levels[name] = level
		player.volume_db = MUSIC_DB + linear_to_db(level)
		if target == 0.0 and level == 0.0 and player.playing:
			player.stream_paused = true
