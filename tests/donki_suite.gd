extends Node

## Tormentas de la campaña guiadas por llamaradas reales del catálogo DONKI.

var _checks := 0
var _failed := 0
var _cases := 0


func _ready() -> void:
	_catalog()
	_cards()
	_radiation()
	print("DONKI SUITE: %d cases, %d assertions, %d failed" % [_cases, _checks, _failed])
	get_tree().quit(int(_failed > 0))


func _mission(base_id: String = "mons_mouton") -> LunarMission:
	var mission := LunarMission.new()
	mission.prepare(base_id, 41)
	mission.connected[1] = true
	mission.finish_tutorial()
	return mission


func _catalog() -> void:
	_cases += 1
	var mission := _mission()
	var rules: Dictionary = mission.donki
	_check(mission.flares.size() >= 4, "DONKI catalog loads")
	var quiet_ids: Array[String] = []
	for id: String in mission.flares:
		var record: Dictionary = mission.flares[id]
		_check(
			(
				String(record.class_type).left(1) in ["C", "M", "X"]
				and id.begins_with(String(record.begin).left(16))
				and String(record.link).begins_with("https://")
			),
			"catalog record keeps DONKI fields"
		)
		if mission.flare_lead(record).is_empty():
			quiet_ids.append(id)
	_check(not quiet_ids.is_empty(), "catalog has a flare without particles")
	for id in ["mons_mouton_plateau", "mons_mouton", "haworth"]:
		mission = _mission(id)
		var pool: Dictionary = rules.pools[String(mission.base.difficulty)]
		var plain := _mission(id)
		plain.flares = {}
		var total := 0.0
		var storms := 0
		var notices := 0
		for cycle in range(40):
			mission.days = cycle
			plain.days = cycle
			mission._roll_events()
			plain._roll_events()
			var starts: Array = []
			for event: Array in mission.events:
				if event[0] == "flare":
					notices += 1
					_check(
						mission.flare_lead(mission.flares[event[4]]).is_empty(), "notice has no SEP"
					)
					continue
				starts.append(event.slice(0, 3))
				if event[0] != "sep":
					continue
				var record: Dictionary = mission.flares[event[4]]
				var lead := mission.flare_lead(record)
				_check(lead in pool.leads, "storm lead fits difficulty")
				_check(
					String(record.class_type).left(1) in pool.classes, "storm class fits difficulty"
				)
				_check(
					int(event[3]) == int(rules.warning_seconds[lead]), "warning follows real lead"
				)
				total += float(event[3])
				storms += 1
			_check(starts == plain.events, "DONKI keeps the EVT-4c calendar")
		_check(notices == 40, "one false alarm per cycle")
		var expected := 0.0
		for lead: String in pool.leads:
			expected += float(rules.warning_seconds[lead]) / pool.leads.size()
		_check(
			absf(total / maxf(1.0, storms) - expected) <= 2.0,
			"average warning balances short and long leads (%.1f s)" % (total / maxf(1.0, storms))
		)
	mission = _mission()
	var storm_id := ""
	for id: String in mission.flares:
		if not mission.flare_lead(mission.flares[id]).is_empty():
			storm_id = id
			break
	mission.events = [["sep", mission.elapsed + 10.0, 45, 15, storm_id]]
	_check(
		is_equal_approx(mission.storm_warning(), 10.0) and not mission.storm_flare().is_empty(),
		"real flare announces the storm"
	)
	mission.events = [["sep", mission.elapsed + 18.0, 45, 15, storm_id]]
	_check(mission.storm_warning() < 0.0, "short real lead gives a short warning")
	var fallback := float(mission.difficulty.warning) - 2.0
	mission.events = [["sep", mission.elapsed + fallback, 25]]
	_check(
		is_equal_approx(mission.storm_warning(), fallback) and mission.storm_flare().is_empty(),
		"old saved schedule keeps the rulebook warning"
	)
	mission.events = [["flare", mission.elapsed, 8, 0, quiet_ids[0]]]
	_check(
		not mission.storm_active() and mission.storm_warning() < 0.0,
		"false alarm never starts a storm"
	)
	_check(not mission.flare_notice().is_empty(), "false alarm is announced")
	_check(
		(
			LunarInterface.flare_label(mission.flares["2017-09-10T15:35:00-FLR-001"])
			== "Llamarada real del 10 sep 2017 · muy fuerte (X8.2)"
		),
		"alert names the real flare"
	)
	mission.events = [["sep", mission.elapsed + 5.0, 25, 10, storm_id]]
	var key := mission.solar_key()
	_check(key.begins_with("sep@"), "a new flare gets a flash key")
	mission.elapsed += 5.5
	_check(mission.solar_key() == key, "the same flare does not flash twice")
	mission.events = [["flare", mission.elapsed, 8, 0, quiet_ids[0]]]
	_check(mission.solar_key().begins_with("flare@"), "a false alarm also flashes")
	mission.events.clear()
	_check(mission.solar_key().is_empty(), "quiet sky has no flash key")
	var record := _record(mission, "donki_sep_20240510")
	_check("DONKI" in mission.science_text(record), "archive explains the DONKI storms")


func _cards() -> void:
	_cases += 1
	var mission := _mission()
	var terms := {
		"donki_sep_20240510": "SEP",
		"radlab_artemis_i_hera": "HERA",
		"neows_2016_ft14": "NeoWs",
		"tle_iss_25544": "TLE",
		"ntrs_life_support_mass": "ECLSS",
		"ntrs_lunar_radio": "Latencia",
		"nasa_lro_3d": "LOLA"
	}
	_check(mission.records.size() == terms.size(), "seven archive cards")
	for record: Dictionary in mission.records:
		var text := mission.science_text(record)
		_check(text.contains("Palabras de científico:"), "card explains its terms")
		_check(text.contains("En el juego:"), "card separates the game from the data")
		_check(text.contains(terms[record.id]), "card keeps its term %s" % terms[record.id])
		_check(not text.contains("%"), "card has no empty data slot")
	var radio := _record(mission, "ntrs_lunar_radio")
	_check(mission.science_text(radio).contains("384 000 km"), "big numbers are easy to read")


func _radiation() -> void:
	_cases += 1
	const OUT: Array[bool] = [false, false]
	const SAFE: Array[bool] = [true, true]
	const AWAY: Array[StringName] = [&"", &""]
	var mission := _mission()
	var rules: Dictionary = mission.rules.radiation
	var storm := func(m: LunarMission) -> void: m.events = [["sep", m.elapsed - 0.1, 400, 10, ""]]
	storm.call(mission)
	_walk(mission, OUT, 4.0)
	_check(is_equal_approx(mission.dose_level(0), 0.2), "dose rises outside in the red phase")
	_check(not mission.is_tired(0), "no tiredness below half")
	_walk(mission, OUT, 6.0)
	_check(mission.is_tired(0), "half dose makes the astronaut tired")
	_check(
		is_equal_approx(mission.speed_factor(0), float(rules.tired_speed)),
		"a tired astronaut walks slower"
	)
	var dose := mission.dose_level(0)
	_walk(mission, SAFE, 3.0)
	_check(not mission.is_tired(0), "resting in the shelter removes tiredness")
	_check(mission.dose_level(0) == dose, "the dose never goes down during the mission")
	mission.events.clear()
	_walk(mission, OUT, 5.0)
	_check(mission.dose_level(0) == dose, "no dose without a storm")
	storm.call(mission)
	var evacuated := false
	for step in range(40):
		mission.tick(0.5, OUT, AWAY)
		evacuated = evacuated or mission.evacuated[0]
	_check(evacuated and mission.dose_level(0) == 1.0, "a full dosimeter sends the crew home")
	mission.events.clear()
	mission.pilots[0].checkup = float(rules.checkup_seconds)
	_check(mission.speed_factor(0) == 0.0, "no walking during the medical check")
	_check(
		mission.use_station(0, &"radio").begins_with("Revisión médica"),
		"no actions during the medical check"
	)
	_walk(mission, SAFE, float(rules.checkup_seconds) + 0.5)
	_check(mission.checkup_left(0) == 0.0, "the medical check ends")
	_check(mission.crew_dose() == float(rules.limit), "the report reads the crew dose")
	var easy := _mission("mons_mouton_plateau")
	storm.call(easy)
	_walk(easy, OUT, float(easy.rules.events.alert_seconds))
	_check(easy.dose_level(0) < 1.0, "on easy one storm cannot fill the dosimeter")
	var old := _mission()
	old.pilots[0].erase("tired")
	old.pilots[0].erase("checkup")
	_check(not old.is_tired(0) and old.checkup_left(0) == 0.0, "old saves start without effects")
	var profile := LunarProfile.new(mission.rules, "user://donki-%d.dat" % randi())
	var coins := int(mission.difficulty.coins)
	_check(profile.pay_clean(mission.base_id, coins), "careful crew earns the bonus once")
	_check(not profile.pay_clean(mission.base_id, coins), "the bonus cannot be paid twice")
	_check(not profile.pay_clean(mission.base_id, coins + 1), "the bonus needs the real difficulty")


func _walk(mission: LunarMission, sheltered: Array[bool], seconds: float) -> void:
	var away: Array[StringName] = [&"", &""]
	for step in range(roundi(seconds / 0.5)):
		mission.tick(0.5, sheltered, away)


func _record(mission: LunarMission, id: String) -> Dictionary:
	for record: Dictionary in mission.records:
		if record.id == id:
			return record
	return {}


func _check(ok: bool, reason: String) -> void:
	_checks += 1
	if not ok:
		_failed += 1
		push_error(reason)
