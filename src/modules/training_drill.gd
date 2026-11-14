class_name TrainingDrill
extends RefCounted

enum Step { OFF, SUPPORT, CROP, FILTER, WALKWAY, BERTHS, RECEIVE, COMPLETE }

var step := Step.OFF


func start() -> void:
	step = Step.SUPPORT


func advance() -> void:
	step = (int(step) + 1) as Step


func is_running() -> bool:
	return step > Step.OFF and step < Step.COMPLETE
