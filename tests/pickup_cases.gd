class_name PickupCases
extends RefCounted

## Casos de recoger una caja soltada: el botón Acción debe seguir visible junto a ella.

var _suite: Node


func _init(suite: Node) -> void:
	_suite = suite


func run() -> void:
	await _loose_crate()


func _loose_crate() -> void:
	_suite._cases += 1
	var game: Node = await _suite._game_solo("mons_mouton_plateau")
	var ui: LunarInterface = game.ui
	var far := Vector3(-14, 0.1, 8.5)
	game._set_positions([far, Vector3.ZERO])
	await _suite._until(func() -> bool: return game.streamer.is_ready_at(far))
	await _suite._frames(30)
	game.sim._create_cargo(0, &"ice")
	await _suite._frames(3)
	_suite._check(ui._zone_buttons.is_visible_in_tree(), "carrying shows the zone buttons")
	game._interact(0, true)
	await _suite._frames(3)
	_suite._check(game.sim.pilots[0].cargo == 0, "the crate was dropped")
	_suite._check(ui._zone_buttons.is_visible_in_tree(), "zone buttons stay beside a loose crate")
	_suite._check(ui.action_button.is_visible_in_tree(), "Action button is visible")
	_suite._check(ui.action_button.text == "Recoger caja", "Action says pick up")
	_suite._check(ui._zone_title.text == "Caja de hielo", "title names the crate")
	ui.selected.emit("action", "")
	await _suite._frames(3)
	_suite._check(game.sim.pilots[0].cargo != 0, "the Action button picks the crate up again")
	game._interact(0, true)
	await _suite._frames(3)
	game._set_positions([far + Vector3(2.0, 0.0, 0.0), Vector3.ZERO])
	await _suite._frames(30)
	_suite._check(not ui._zone_buttons.is_visible_in_tree(), "beyond 1.25 m the buttons hide")
	game._set_positions([far + Vector3(1.0, 0.0, 0.0), Vector3.ZERO])
	await _suite._frames(30)
	_suite._check(ui.action_button.text == "Recoger caja", "at 1 m it can be picked up")
	DirAccess.remove_absolute(game.profile_path)
	game.get_parent().queue_free()
	await _suite.get_tree().process_frame
