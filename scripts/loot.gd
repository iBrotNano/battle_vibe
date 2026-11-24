class_name Loot
extends RefCounted
## Procedural cyberpunk gear: weapons, armor and implants with rarity-scaled affixes.

const SLOT_BASES := {
	"weapon": [
		"PNEUMA GAUNTLETS", "RAILSPIKE BATON", "CHROME KNUCKLES", "SYNTH-CLEAVER",
		"SHOCK PIPES", "GUTTER BLADE", "HYDRAULIC FISTS", "NEON TONFA",
	],
	"armor": [
		"KEVLAR WEAVE", "SUBJACKET", "DAMPENER RIG", "BONE-LACE VEST",
		"RIOT HARL", "CHROME CARAPACE", "STREET PLATE", "SYNTHWEAVE COAT",
	],
	"implant": [
		"SYNAPSE DRIVE", "ADRENAL PUMP", "CORTEX SHARD", "MYOMER CORE",
		"REFLEX SPINE", "BLACK-ICE LATTICE", "PAINKILLER NODE", "OPTIC SPIKE",
	],
}

const PREFIXES := [
	"STREET", "BLACK ICE", "NEON", "RUSTED", "CHROME", "VOID", "GUTTER",
	"HYPER", "KOWLOON", "SALT", "STATIC", "GODLESS",
]

const SUFFIXES := [
	"MK.IV", "//SERIES-9", "OF FRACTURE", "X-OVERCLOCK", "OF THE PIT",
	"V.2077", "OF THE JACKAL", "PRIME", "OF STATIC", "BLK-MKT",
]

const MOD_POOL := {
	"damage_pct": [0.03, 0.11],
	"attack_speed": [0.02, 0.06],
	"max_hp": [8.0, 24.0],
	"armor": [4.0, 12.0],
	"crit": [0.01, 0.035],
	"lifesteal": [0.006, 0.018],
	"move_speed": [4.0, 12.0],
	"energy": [5.0, 14.0],
}

const MOD_LABELS := {
	"damage_pct": "DAMAGE",
	"attack_speed": "ATK SPEED",
	"max_hp": "MAX HP",
	"armor": "ARMOR",
	"crit": "CRIT CHANCE",
	"lifesteal": "LIFESTEAL",
	"move_speed": "MOVE SPEED",
	"energy": "IMPLANT ENERGY",
}


static func roll(item_level: int) -> Dictionary:
	var r := randf()
	var rarity := 0
	if r > 0.985:
		rarity = 4
	elif r > 0.94:
		rarity = 3
	elif r > 0.80:
		rarity = 2
	elif r > 0.52:
		rarity = 1

	var slots: Array = ["weapon", "armor", "implant"]
	var slot: String = slots[randi() % slots.size()]
	var bases: Array = SLOT_BASES[slot]

	var power := int(round(float(item_level) * (1.05 + rarity * 0.30) * randf_range(0.9, 1.15))) + 2
	var name := _make_name(slot)
	var mod_count := 1 + rarity
	var keys: Array = MOD_POOL.keys()
	var used: Array = []
	var mods := {}
	for i in mod_count:
		var key: String = keys[randi() % keys.size()]
		var guard := 0
		while used.has(key) and guard < 20:
			key = keys[randi() % keys.size()]
			guard += 1
		used.append(key)
		var range_vals: Array = MOD_POOL[key]
		var lo: float = range_vals[0]
		var hi: float = range_vals[1]
		var scale := 1.0 + float(item_level - 1) * 0.045 + rarity * 0.10
		var value := randf_range(lo, hi) * scale
		mods[key] = value

	return {
		"slot": slot,
		"name": name,
		"rarity": rarity,
		"power": power,
		"mods": mods,
		"level": item_level,
		"color": Game.RARITY_COLORS[rarity],
	}


static func _make_name(slot: String) -> String:
	var bases: Array = SLOT_BASES[slot]
	var base: String = bases[randi() % bases.size()]
	if randf() < 0.55:
		base = "%s %s" % [PREFIXES[randi() % PREFIXES.size()], base]
	if randf() < 0.45:
		base = "%s %s" % [base, SUFFIXES[randi() % SUFFIXES.size()]]
	return base


static func mod_text(key: String, value: float) -> String:
	var label: String = MOD_LABELS.get(key, key.to_upper())
	match key:
		"damage_pct", "attack_speed", "crit", "lifesteal":
			return "+%.1f%% %s" % [value * 100.0, label]
		_:
			return "+%d %s" % [int(round(value)), label]


static func item_summary(item: Dictionary) -> String:
	if item.is_empty():
		return "EMPTY"
	var parts: Array = []
	var mods: Dictionary = item.get("mods", {})
	for k in mods:
		parts.append(mod_text(k, float(mods[k])))
	return "%s  (%s)  PWR %d\n%s" % [
		item.get("name", "?"),
		Game.RARITY_NAMES[clampi(int(item.get("rarity", 0)), 0, 4)],
		int(item.get("power", 0)),
		"  ·  ".join(parts),
	]
