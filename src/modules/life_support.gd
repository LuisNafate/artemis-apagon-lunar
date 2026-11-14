class_name LifeSupport
extends RefCounted

var enabled := false
var powered := false


func tick(config: Dictionary, supplied: bool, guests: int = 0, scrub_factor: float = 1.0) -> bool:
	powered = enabled and supplied
	var crew_factor := (float(config.crew) + guests) / 1440.0
	var oxygen_use := float(config.daily_crew_kg.o2) * crew_factor
	var carbon_output := float(config.daily_crew_kg.co2) * crew_factor
	var water_use := float(config.daily_crew_kg.water) * crew_factor
	var oxygen := 0.0
	var recycled := 0.0
	var scrubbed := 0.0
	var ratio := float(config.water_per_kg_o2)

	if powered:
		var headroom := ResourceManager.capacity(&"o2") - ResourceManager.amount(&"o2")
		recycled = float(config.water_recycled_per_minute)
		scrubbed = float(config.co2_removed_per_minute) * scrub_factor
		var available_water := ResourceManager.amount(&"water") + recycled - water_use
		oxygen = minf(float(config.o2_per_minute), headroom + oxygen_use)
		oxygen = minf(oxygen, maxf(0.0, available_water) / ratio)

	ResourceManager.adjust(&"o2", oxygen - oxygen_use)
	ResourceManager.adjust(&"co2", carbon_output - scrubbed)
	ResourceManager.adjust(&"water", recycled - water_use - oxygen * ratio)

	return (
		ResourceManager.amount(&"o2") > 0.0
		and ResourceManager.amount(&"water") > 0.0
		and ResourceManager.amount(&"co2") < ResourceManager.capacity(&"co2")
	)
