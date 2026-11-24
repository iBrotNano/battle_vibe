extends Node
## Global run state: endless leveling, stats, gear, scaling and shared signals.

signal xp_changed(current: float, needed: float, level: int)
signal leveled_up(new_level: int, points: int)
signal stats_changed
signal gear_changed(slot: String, item: Dictionary, equipped: bool)
signal credits_changed(value: int)
signal message(text: String, color: Color)
signal district_changed(index: int)
signal run_started

const STAT_KEYS := ["strength", "vitality", "agility", "tech"]
const STAT_NAMES := {
	"strength": "STRENGTH",
	"vitality": "VITALITY",
	"agility": "AGILITY",
	"tech": "TECH",
}
const STAT_HINTS := {
	"strength": "melee damage",
	"vitality": "max hp + armor",
	"agility": "speed + attack rate",
	"tech": "crit + implant energy",
}
const RARITY_NAMES := ["COMMON", "UNCOMMON", "RARE", "EPIC", "LEGENDARY"]
const RARITY_COLORS := [
	Color(0.72, 0.78, 0.88),
	Color(0.30, 1.00, 0.72),
	Color(0.25, 0.62, 1.00),
	Color(0.83, 0.36, 1.00),
	Color(1.00, 0.71, 0.18),
]
const SLOT_NAMES := {"weapon": "WEAPON", "armor": "ARMOR", "implant": "IMPLANT"}

var level := 1
var xp := 0.0
var xp_needed := 100.0
var stat_points := 0
var stats := {"strength": 5, "vitality": 5, "agility": 5, "tech": 5}
var gear := {"weapon": {}, "armor": {}, "implant": {}}
var credits := 0
var district := 0
var kills := 0
var run_time := 0.0
var best_level := 1
var run_seed := 0


func _ready() -> void:
	_setup_input()
	reset_run()


func _process(delta: float) -> void:
	run_time += delta


func _setup_input() -> void:
	_bind_keys("move_left", [KEY_A, KEY_LEFT])
	_bind_keys("move_right", [KEY_D, KEY_RIGHT])
	_bind_keys("move_up", [KEY_W, KEY_UP])
	_bind_keys("move_down", [KEY_S, KEY_DOWN])
	_bind_keys("light_attack", [KEY_J])
	_bind_keys("heavy_attack", [KEY_K])
	_bind_keys("dash", [KEY_SPACE, KEY_SHIFT])
	_bind_keys("special", [KEY_Q])
	_bind_keys("restart", [KEY_R])
	_bind_mouse("light_attack", MOUSE_BUTTON_LEFT)
	_bind_mouse("heavy_attack", MOUSE_BUTTON_RIGHT)


func _bind_keys(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)


func _bind_mouse(action: String, button: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func reset_run() -> void:
	level = 1
	xp = 0.0
	xp_needed = 100.0
	stat_points = 0
	stats = {"strength": 5, "vitality": 5, "agility": 5, "tech": 5}
	gear = {"weapon": {}, "armor": {}, "implant": {}}
	credits = 0
	district = 1
	kills = 0
	run_time = 0.0
	best_level = 1
	run_seed = int(Time.get_unix_time_from_system()) + randi() % 100000
	emit_signal("xp_changed", xp, xp_needed, level)
	emit_signal("stats_changed")
	emit_signal("credits_changed", credits)
	emit_signal("district_changed", district)
	run_started.emit()


func add_xp(amount: float) -> void:
	if amount <= 0.0:
		return
	xp += amount
	var ups := 0
	while xp >= xp_needed:
		xp -= xp_needed
		level += 1
		ups += 1
		stat_points += 3
		xp_needed = round(xp_needed * 1.12 + 25.0)
		best_level = maxi(best_level, level)
	if ups > 0:
		emit_signal("leveled_up", level, ups * 3)
		emit_signal("stats_changed")
	emit_signal("xp_changed", xp, xp_needed, level)


func lose_xp_percent(percent: float) -> void:
	var pool := xp + _xp_floor_for_level()
	var loss := int(pool * clampf(percent, 0.0, 1.0))
	xp = maxf(0.0, xp - loss)
	emit_signal("xp_changed", xp, xp_needed, level)


func _xp_floor_for_level() -> float:
	return maxf(0.0, xp_needed * 0.5)


func allocate_stat(key: String) -> void:
	if stat_points <= 0 or not stats.has(key):
		return
	stat_points -= 1
	stats[key] = int(stats[key]) + 1
	emit_signal("stats_changed")
	emit_signal("message", "+1 %s" % STAT_NAMES[key], Color(0.25, 0.95, 1.0))
	Sfx.play_ui("stat", -3.0, randf_range(0.98, 1.06))


func total_stat_points() -> int:
	var total := 0
	for k in STAT_KEYS:
		total += int(stats[k])
	return total


func gear_mod(key: String) -> float:
	var total := 0.0
	for slot in gear:
		var item: Dictionary = gear[slot]
		if item.is_empty():
			continue
		var mods: Dictionary = item.get("mods", {})
		total += float(mods.get(key, 0.0))
	return total


func gear_power() -> float:
	var total := 0.0
	for slot in gear:
		var item: Dictionary = gear[slot]
		if not item.is_empty():
			total += float(item.get("power", 0.0))
	return total


func derived() -> Dictionary:
	var vit := float(stats.vitality)
	var str := float(stats.strength)
	var agi := float(stats.agility)
	var tech := float(stats.tech)
	var dmg_pct := gear_mod("damage_pct")
	var max_hp := 90.0 + vit * 14.0 + level * 8.0 + gear_mod("max_hp")
	var damage := (8.0 + str * 2.0) * (1.0 + dmg_pct)
	var attack_speed := clampf(1.0 + agi * 0.018 + gear_mod("attack_speed"), 1.0, 2.2)
	var move_speed := 190.0 + agi * 2.0 + gear_mod("move_speed")
	var crit := clampf(0.05 + tech * 0.010 + gear_mod("crit"), 0.0, 0.75)
	var crit_mult := 1.7 + tech * 0.015
	var armor := vit * 0.6 + gear_mod("armor")
	var reduction := armor / (armor + 130.0)
	var energy_max := 100.0 + tech * 2.0 + gear_mod("energy")
	var dash_cd := clampf(0.85 - agi * 0.012, 0.34, 1.0)
	return {
		"max_hp": max_hp,
		"damage": damage,
		"attack_speed": attack_speed,
		"move_speed": move_speed,
		"crit": crit,
		"crit_mult": crit_mult,
		"armor": armor,
		"damage_reduction": reduction,
		"lifesteal": gear_mod("lifesteal"),
		"energy_max": energy_max,
		"energy_regen": 5.0 + tech * 0.25,
		"dash_cd": dash_cd,
	}


## Scalar used to scale enemies with the player's real strength (stats, gear, progress).
func threat() -> float:
	var extra_stats := maxf(0.0, float(total_stat_points() - 20))
	return 1.0 + float(level - 1) * 0.5 \
		+ extra_stats * 0.07 \
		+ gear_power() * 0.01 \
		+ float(district - 1) * 0.6


func award_loot(guaranteed: bool = false) -> Dictionary:
	var chance := 1.0 if guaranteed else 0.13
	if randf() > chance:
		return {}
	var item := Loot.roll(maxi(1, level + district - 1))
	equip_item(item)
	return item


func equip_item(item: Dictionary) -> void:
	var slot: String = item.get("slot", "weapon")
	var current: Dictionary = gear.get(slot, {})
	var equipped := current.is_empty() or float(item.power) > float(current.power)
	if equipped:
		gear[slot] = item
		emit_signal("gear_changed", slot, item, true)
		emit_signal("stats_changed")
		var msg := "EQUIPPED %s  [%s]" % [item.get("name", "?"), SLOT_NAMES.get(slot, slot)]
		emit_signal("message", msg, RARITY_COLORS[clampi(int(item.get("rarity", 0)), 0, 4)])
		Sfx.play_ui("loot", -1.0, randf_range(0.96, 1.06))
	else:
		var salvage := int(12 + float(item.get("power", 1)) * 2.5)
		credits += salvage
		emit_signal("credits_changed", credits)
		emit_signal("gear_changed", slot, item, false)
		emit_signal("message", "SALVAGED %s  +%d CR" % [item.get("name", "?"), salvage],
			Color(0.65, 0.72, 0.85))
		Sfx.play_ui("salvage", -2.0, randf_range(0.94, 1.08))


func add_credits(amount: int) -> void:
	credits += amount
	emit_signal("credits_changed", credits)


func notify(text: String, color: Color = Color(0.8, 0.85, 0.95)) -> void:
	emit_signal("message", text, color)
