class_name SolarArray
extends RefCounted

enum Condition { CLEAR, DUSTY, CLEANED }

var condition := Condition.CLEAR


func output_kw(config: Dictionary) -> float:
	match condition:
		Condition.DUSTY:
			return float(config.solar_kw) * float(config.dust_factor)
		Condition.CLEANED:
			return float(config.solar_kw) * float(config.cleaned_factor)
	return float(config.solar_kw)
