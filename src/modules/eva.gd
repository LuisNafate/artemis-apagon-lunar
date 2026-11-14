class_name EVA
extends RefCounted

enum Stage { INDOORS, OUTSIDE, CALIBRATED, COMPLETE }

var stage := Stage.INDOORS
var oxygen := 0.0


func is_outside() -> bool:
	return stage == Stage.OUTSIDE or stage == Stage.CALIBRATED


func tick(rate: float) -> void:
	if is_outside():
		oxygen = maxf(0.0, oxygen - rate)
