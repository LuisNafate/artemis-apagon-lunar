class_name Greenhouse
extends RefCounted

var active := false
var powered := false
var minutes := 0


func tick(supplied: bool, goal: int, boost: int = 0) -> void:
	powered = active and supplied and minutes < goal
	if powered:
		minutes = mini(goal, minutes + 1 + boost)


func complete(goal: int) -> bool:
	return minutes >= goal
