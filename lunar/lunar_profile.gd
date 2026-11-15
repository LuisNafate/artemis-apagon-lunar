class_name LunarProfile
extends RefCounted

const SAVE_PATH := "user://artemis_campaign_v1.dat"
const SCALE := 10000

var rules: Dictionary
var path: String
var error := OK
var data: Dictionary


func _init(campaign_rules: Dictionary, save_path: String = SAVE_PATH) -> void:
	rules = campaign_rules
	path = save_path
	if FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		if file != null:
			var saved: Variant = file.get_var(false)
			if saved is Dictionary and saved.get("version") == 1:
				data = saved
				data.merge({"solo_bases": {}, "recent_mode": "host"})
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


func save() -> bool:
	if error != OK:
		return false
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_var(data, false)
	file.flush()
	var ok := file.get_error() == OK
	file.close()
	if not ok:
		return false
	return DirAccess.rename_absolute(tmp, path) == OK


func open_base(id: String) -> bool:
	return id in data.opened


func saved_bases(single_player: bool) -> Dictionary:
	return data.solo_bases if single_player else data.bases


func balance_text() -> String:
	return "%.2f" % (float(data.balance) / SCALE)


func buy(id: String, role: bool) -> bool:
	var catalog: Dictionary = rules.roles if role else rules.bases
	var owned: Array = data.roles if role else data.opened
	if not catalog.has(id) or id in owned:
		return false
	var cost := int(rules.wallet.role_price if role else catalog[id].cost) * SCALE
	if data.balance < cost:
		return false
	data.balance -= cost
	owned.append(id)
	if save():
		return true
	owned.erase(id)
	data.balance += cost
	return false


func pay_day(base: String, run: int, day: int, amount: float, guest: Dictionary) -> void:
	var receipt := "%s/%s/%d/%d" % [data.id, base, run, day]
	credit(receipt, roundi(amount * SCALE))
	for id: String in guest:
		_queue_guest(id, receipt, roundi(float(guest[id]) * SCALE))


func pay_mission(base: String, difficulty: int, guest_id: String) -> void:
	var amount := int(rules.wallet.mission_bonus) * difficulty * SCALE
	var receipt := "lunar/mission/%s" % base
	credit(receipt, amount)
	data.paid_missions[base] = true
	if not guest_id.is_empty():
		_queue_guest(guest_id, receipt, amount)


func credit(receipt: String, amount: int) -> void:
	if not data.received.has(receipt) and amount > 0:
		data.received[receipt] = true
		data.balance += amount


func _queue_guest(id: String, receipt: String, amount: int) -> void:
	if not data.guest_awards.has(id):
		data.guest_awards[id] = {}
	data.guest_awards[id][receipt] = amount
