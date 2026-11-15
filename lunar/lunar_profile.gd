class_name LunarProfile
extends RefCounted

const SAVE_PATH := "user://artemis_campaign_v1.dat"
const SCALE := 10000
# Keep fixed-point arithmetic and its two-decimal display within exact integer range.
const MAX_BALANCE := 1_000_000_000 * SCALE
const AWARD_BATCH := 64

static var _save_mutex := Mutex.new()

var rules: Dictionary
var path: String
var error := OK
var data: Dictionary
var save_error := OK
var _committed: Dictionary
var _saved_bytes := PackedByteArray()
var _has_save := false


func _init(campaign_rules: Dictionary, save_path: String = SAVE_PATH) -> void:
	rules = campaign_rules
	path = save_path
	if FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		if file != null:
			_saved_bytes = file.get_buffer(file.get_length())
			file.seek(0)
			var saved: Variant = file.get_var(false)
			if file.get_error() == OK and _valid_save(saved):
				data = saved
				data.merge({"solo_bases": {}, "recent_mode": "host"})
				_committed = data.duplicate(true)
				_has_save = true
				return
		error = ERR_FILE_CORRUPT
		return
	data = {
		"version": 1,
		"id": Crypto.new().generate_random_bytes(16).hex_encode(),
		"balance": 0,
		"opened": [String(rules.starting_base)],
		"roles": [],
		"active_role": "",
		"recent": "",
		"recent_mode": "host",
		"bases": {},
		"solo_bases": {},
		"paid_missions": {},
		"guest_awards": {},
		"received": {}
	}

	_committed = data.duplicate(true)


func _valid_save(saved: Variant) -> bool:
	if not saved is Dictionary or saved.get("version") != 1:
		return false
	var balance: Variant = saved.get("balance")
	if not balance is int or balance < 0 or balance > MAX_BALANCE:
		return false
	for key in ["opened", "roles"]:
		var ids: Variant = saved.get(key)
		if not ids is Array or not ids.all(func(id: Variant) -> bool: return id is String):
			return false
	for key in ["active_role", "recent", "recent_mode"]:
		if not saved.get(key, "" if key == "recent_mode" else null) is String:
			return false
	for key in ["bases", "solo_bases", "paid_missions", "guest_awards", "received"]:
		if not saved.get(key, {} if key == "solo_bases" else null) is Dictionary:
			return false
	return (
		_valid_profile_id(saved.get("id"))
		and saved.guest_awards.values().all(
			func(pending: Variant) -> bool: return pending is Dictionary
		)
		and _valid_slots(saved.bases)
		and _valid_slots(saved.get("solo_bases", {}))
	)


func _valid_slots(slots: Dictionary) -> bool:
	for slot: Variant in slots.values():
		if not slot is Dictionary:
			return false
		if not slot.get("active") is Dictionary or not slot.get("checkpoint") is Dictionary:
			return false
		if not slot.get("guest_pending", {}) is Dictionary:
			return false
		for key in ["positions", "checkpoint_positions"]:
			var points: Variant = slot.get(key)
			if not points is Array or points.size() != 2:
				return false
			if not points.all(func(point: Variant) -> bool: return point is Vector3):
				return false
	return true


func save() -> bool:
	_save_mutex.lock()
	save_error = _write_profile()
	if save_error == OK:
		_committed = data.duplicate(true)
	elif error == OK:
		data = _committed.duplicate(true)
	_save_mutex.unlock()
	return save_error == OK


func _write_profile() -> Error:
	if error != OK:
		return error
	if not _valid_save(data):
		return ERR_INVALID_DATA
	var tmp := "%s.%d.%d.tmp" % [path, OS.get_process_id(), get_instance_id()]
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_var(data, false)
	file.flush()
	var result := file.get_error()
	file.close()
	if result == OK:
		# A second window can hold an older copy of the same profile.
		if FileAccess.file_exists(path) != _has_save:
			result = ERR_BUSY
		elif _has_save and FileAccess.get_file_as_bytes(path) != _saved_bytes:
			result = ERR_BUSY
	if result == OK:
		var written := FileAccess.get_file_as_bytes(tmp)
		if written.is_empty():
			result = ERR_FILE_CANT_READ
		else:
			result = DirAccess.rename_absolute(tmp, path)
			if result == OK:
				_saved_bytes = written
				_has_save = true
	if result != OK:
		DirAccess.remove_absolute(tmp)
	return result


func open_base(id: String) -> bool:
	return id in data.opened


func saved_bases(single_player: bool) -> Dictionary:
	return data.solo_bases if single_player else data.bases


func campaign_finished() -> bool:
	return rules.bases.keys().all(
		func(id: String) -> bool: return data.paid_missions.get(id, false)
	)


func balance_text() -> String:
	return "%.2f" % (float(data.balance) / SCALE)


func buy(id: String, role: bool) -> bool:
	save_error = OK
	var catalog: Dictionary = rules.roles if role else rules.bases
	var owned: Array = data.roles if role else data.opened
	if not catalog.has(id) or id in owned:
		return false
	var price: Variant = rules.wallet.role_price if role else catalog[id].cost
	if not _valid_amount(price, float(MAX_BALANCE) / SCALE) or float(price) != floorf(price):
		return false
	var cost := int(price) * SCALE
	if data.balance < cost:
		return false
	data.balance -= cost
	owned.append(id)
	return save()


func pay_day(base: String, run: int, day: int, amount: float, guest: Dictionary) -> void:
	var maximum := _day_cap(base, false)
	if run < 0 or day <= 0 or not _valid_amount(amount, maximum):
		return
	var receipt := "%s/%s/%d/%d" % [data.id, base, run, day]
	if not credit(receipt, roundi(amount * SCALE)):
		return
	var guest_cap := _day_cap(base, true)
	for id: Variant in guest:
		# The guest share is accumulated per frame. Round before enforcing the cap.
		if _valid_amount(guest[id], guest_cap + 1.0 / SCALE):
			var units := roundi(float(guest[id]) * SCALE)
			if units <= roundi(guest_cap * SCALE):
				_queue_guest(id, receipt, units)


func pay_mission(base: String, difficulty: int, guest_id: String) -> void:
	if not rules.bases.has(base) or difficulty != int(_difficulty_coins(base)):
		return
	var amount := int(rules.wallet.mission_bonus) * difficulty * SCALE
	var receipt := "lunar/mission/%s" % base
	credit(receipt, amount)
	data.paid_missions[base] = true
	_queue_guest(guest_id, receipt, amount)


## Bono de «astronauta precavido»: una sola vez por base, si la tripulación regresó sin
## recibir radiación. Es local: no se reparte al invitado.
func pay_clean(base: String, difficulty: int) -> bool:
	if not rules.bases.has(base) or difficulty != int(_difficulty_coins(base)):
		return false
	var amount := int(rules.radiation.clean_bonus) * difficulty * SCALE
	return credit("lunar/clean/%s" % base, amount)


func credit(receipt: String, amount: int) -> bool:
	if receipt.is_empty() or receipt.length() > 128 or amount <= 0 or amount > MAX_BALANCE:
		return false
	if data.received.has(receipt):
		return false
	data.received[receipt] = true
	data.balance += mini(amount, MAX_BALANCE - int(data.balance))
	return true


func valid_guest_award(receipt: Variant, amount: Variant) -> bool:
	if not receipt is String or receipt.length() > 128 or not amount is int or amount <= 0:
		return false
	var parts: PackedStringArray = receipt.split("/")
	if parts.size() == 3 and parts[0] == "lunar" and parts[1] == "mission":
		return (
			amount
			== roundi(float(rules.wallet.mission_bonus) * _difficulty_coins(parts[2]) * SCALE)
		)
	if parts.size() != 4 or not _valid_profile_id(parts[0]):
		return false
	var run := int(parts[2])
	var day := int(parts[3])
	if run < 0 or day <= 0 or str(run) != parts[2] or str(day) != parts[3]:
		return false
	return amount <= roundi(_day_cap(parts[1], true) * SCALE)


func _day_cap(base: String, guest: bool) -> float:
	var share := float(rules.wallet.share) if guest else 1.0
	return float(rules.wallet.base) * _difficulty_coins(base) * float(rules.wallet.cap) * share


func _difficulty_coins(base: String) -> float:
	if not rules.bases.has(base):
		return 0.0
	var difficulty: String = rules.bases[base].difficulty
	return float(rules.difficulties[difficulty].coins)


func _valid_amount(amount: Variant, maximum: float) -> bool:
	return (amount is float or amount is int) and float(amount) > 0 and float(amount) <= maximum


static func _valid_profile_id(id: Variant) -> bool:
	return id is String and id.length() == 32 and id.to_lower().is_valid_hex_number()


func _queue_guest(id: Variant, receipt: String, amount: int) -> void:
	if not _valid_profile_id(id) or amount <= 0:
		return
	if not data.guest_awards.has(id):
		data.guest_awards[id] = {}
	var pending: Dictionary = data.guest_awards[id]
	if not pending.has(receipt):
		pending[receipt] = amount
