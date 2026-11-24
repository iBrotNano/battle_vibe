class_name HUD
extends CanvasLayer
## In-game HUD, title screen, death screen, banners and messages.

signal start_requested
signal restart_requested

enum Mode { TITLE, PLAYING, DEAD, CLEARED }

const CYAN := Color(0.18, 0.95, 1.0)
const MAGENTA := Color(1.0, 0.22, 0.56)
const GOLD := Color(1.0, 0.76, 0.22)
const DIM := Color(0.62, 0.68, 0.80)

var mode := Mode.TITLE
var player
var level
var _time := 0.0

var root: Control
var game_ui: Control
var flash_rect: ColorRect
var title_screen: Control
var death_screen: Control
var title_pulse: Label
var display_label: Label

var hp_bar: UIBar
var hp_text: Label
var en_bar: UIBar
var en_text: Label
var xp_bar: UIBar
var xp_text: Label
var name_label: Label
var credits_label: Label
var sector_label: Label
var threat_label: Label
var kills_label: Label
var stats_rows: Array = []
var points_label: Label
var derived_label: Label
var gear_rows: Array = []
var ability_boxes: Array = []
var banner_title: Label
var banner_sub: Label
var banner_tween: Tween
var msg_labels: Array = []
var msg_timers: Array = []
var death_stats: Label

var notice_tween: Tween


class AbilityBox extends Control:
	var key_text := "J"
	var name_text := "LIGHT"
	var sub_text := ""
	var charge := 1.0
	var color := Color(0.18, 0.95, 1.0)
	var is_ready := true

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_data(c: float, sub: String = "") -> void:
		charge = clampf(c, 0.0, 1.0)
		sub_text = sub
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.03, 0.05, 0.85))
		var fill_h := (size.y - 2) * charge
		var fill_c := color
		fill_c.a = 0.16 if charge > 0.99 else 0.10
		draw_rect(Rect2(1, size.y - 1 - fill_h, size.x - 2, fill_h), fill_c)
		var border := color
		border.a = 0.65 if charge > 0.99 else 0.22
		draw_rect(Rect2(Vector2.ZERO, size), border, false, 1.0)
		var font := ThemeDB.fallback_font
		var key_col := color if charge > 0.99 else Color(0.55, 0.6, 0.7)
		draw_string(font, Vector2(6, 16), key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, key_col)
		draw_string(font, Vector2(-4, 40), name_text, HORIZONTAL_ALIGNMENT_CENTER, size.x + 8, 12,
			Color(0.9, 0.94, 1.0, 0.95 if charge > 0.99 else 0.45))
		if sub_text != "":
			draw_string(font, Vector2(-4, 55), sub_text, HORIZONTAL_ALIGNMENT_CENTER, size.x + 8, 9,
				Color(0.6, 0.66, 0.78, 0.9))


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	Game.message.connect(_on_message)
	Game.leveled_up.connect(_on_leveled_up)
	Game.stats_changed.connect(_refresh_character)
	Game.gear_changed.connect(_on_gear_changed)
	Game.leveled_up.connect(func(_l, _p): _refresh_character())
	Settings.changed.connect(_update_display_label)
	show_title()
	_update_display_label()


# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

func _build() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	game_ui = Control.new()
	game_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(game_ui)

	_build_top_left()
	_build_top_right()
	_build_stats()
	_build_gear()
	_build_abilities()
	_build_messages()
	_build_banner()

	flash_rect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.color = Color(0, 0, 0, 0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash_rect)

	title_screen = _build_title()
	root.add_child(title_screen)
	death_screen = _build_death()
	root.add_child(death_screen)


func _mk_panel(pos: Vector2, sz: Vector2, border: Color = Color(0.20, 0.90, 1.0, 0.30)) -> HudPanel:
	var p := HudPanel.new()
	p.position = pos
	p.size = sz
	p.border_color = border
	p.accent_color = Color(border.r, border.g, border.b, 0.85)
	game_ui.add_child(p)
	return p


func _mk_label(parent: Node, pos: Vector2, sz: Vector2, text: String, font_size: int,
		color: Color = Color(0.9, 0.94, 1.0), align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = sz
	l.text = text
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	parent.add_child(l)
	return l


func _build_top_left() -> void:
	var p := _mk_panel(Vector2(18, 16), Vector2(392, 134))
	name_label = _mk_label(p, Vector2(16, 8), Vector2(240, 24), "VEX // LVL 01", 18, Color(0.95, 0.98, 1.0))
	credits_label = _mk_label(p, Vector2(250, 10), Vector2(128, 20), "CR 0", 12, GOLD, HORIZONTAL_ALIGNMENT_RIGHT)

	hp_bar = UIBar.new()
	hp_bar.position = Vector2(16, 42)
	hp_bar.size = Vector2(360, 18)
	hp_bar.fill_color = Color(0.95, 0.16, 0.35)
	hp_bar.glow_color = Color(1.0, 0.2, 0.3, 0.5)
	hp_bar.tick_count = 10
	p.add_child(hp_bar)
	hp_text = _mk_label(p, Vector2(18, 41), Vector2(356, 18), "150 / 150", 11,
		Color(1, 1, 1, 0.9), HORIZONTAL_ALIGNMENT_CENTER)

	en_bar = UIBar.new()
	en_bar.position = Vector2(16, 68)
	en_bar.size = Vector2(360, 12)
	en_bar.fill_color = CYAN
	en_bar.show_ticks = false
	p.add_child(en_bar)
	en_text = _mk_label(p, Vector2(18, 67), Vector2(356, 12), "100", 9,
		Color(0, 0.1, 0.15, 0.9), HORIZONTAL_ALIGNMENT_RIGHT)

	xp_bar = UIBar.new()
	xp_bar.position = Vector2(16, 88)
	xp_bar.size = Vector2(360, 8)
	xp_bar.fill_color = GOLD
	xp_bar.show_ticks = false
	p.add_child(xp_bar)
	xp_text = _mk_label(p, Vector2(16, 100), Vector2(360, 16), "XP 0 / 100", 10, DIM)
	var hint := _mk_label(p, Vector2(16, 114), Vector2(360, 14),
		"CREDITS FARMED ON STREET KILLS", 9, Color(0.45, 0.5, 0.62))


func _build_top_right() -> void:
	var p := _mk_panel(Vector2(870, 16), Vector2(392, 96), Color(1.0, 0.22, 0.56, 0.35))
	sector_label = _mk_label(p, Vector2(14, 6), Vector2(364, 22), "SECTOR 1/3  ·  ROAMING", 15, Color(0.95, 0.97, 1.0))
	threat_label = _mk_label(p, Vector2(14, 30), Vector2(364, 20), "DISTRICT 01 // KOWLOON SPRAWL", 11, CYAN)
	kills_label = _mk_label(p, Vector2(14, 54), Vector2(364, 20), "THREAT 1.0  ·  KILLS 0", 10, DIM)
	var tip := _mk_label(p, Vector2(14, 72), Vector2(364, 16), "ENEMIES SCALE WITH YOUR POWER", 9,
		Color(0.48, 0.53, 0.66))


func _build_stats() -> void:
	var p := _mk_panel(Vector2(18, 462), Vector2(400, 240))
	_mk_label(p, Vector2(14, 6), Vector2(360, 20), "AUGMENT LOADOUT // STATS", 12, Color(0.75, 0.82, 0.95))
	for i in 4:
		var row := _mk_label(p, Vector2(14, 28 + i * 24), Vector2(368, 22), "", 13, Color(0.88, 0.92, 1.0))
		stats_rows.append(row)
	points_label = _mk_label(p, Vector2(14, 128), Vector2(368, 20), "", 12, GOLD)
	derived_label = _mk_label(p, Vector2(14, 152), Vector2(368, 34), "", 10, DIM)
	_mk_label(p, Vector2(14, 190), Vector2(368, 18), "PRESS 1-4 TO SPEND POINTS", 9,
		Color(0.45, 0.5, 0.62))
	_mk_label(p, Vector2(14, 208), Vector2(368, 18), "GEAR AUTO-EQUIPS ON POWER", 9,
		Color(0.45, 0.5, 0.62))


func _build_gear() -> void:
	var p := _mk_panel(Vector2(862, 462), Vector2(400, 240), Color(1.0, 0.22, 0.56, 0.30))
	_mk_label(p, Vector2(14, 6), Vector2(360, 20), "LOOT // AUGMENTS", 12, Color(0.95, 0.75, 0.85))
	var slots := ["weapon", "armor", "implant"]
	for i in slots.size():
		var row := {
			"slot": _mk_label(p, Vector2(14, 28 + i * 58), Vector2(80, 18), "", 9, CYAN),
			"name": _mk_label(p, Vector2(14, 42 + i * 58), Vector2(368, 20), "— EMPTY —", 12, DIM),
			"mods": _mk_label(p, Vector2(14, 60 + i * 58), Vector2(368, 18), "", 9, DIM),
		}
		gear_rows.append(row)
	_mk_label(p, Vector2(14, 206), Vector2(368, 18), "BETTER GEAR REPLACES WORSE · ELSE SALVAGED", 8,
		Color(0.45, 0.5, 0.62))


func _build_abilities() -> void:
	var defs := [
		["J", "LIGHT", "COMBO x3", CYAN],
		["K", "HEAVY", "BREAKER", MAGENTA],
		["SPACE", "DASH", "I-FRAMES", Color(0.35, 1.0, 0.7)],
		["Q", "OVERCLOCK", "50 EN", GOLD],
	]
	for i in defs.size():
		var box := AbilityBox.new()
		box.position = Vector2(436 + i * 104, 624)
		box.size = Vector2(100, 62)
		box.key_text = defs[i][0]
		box.name_text = defs[i][1]
		box.sub_text = defs[i][2]
		box.color = defs[i][3]
		game_ui.add_child(box)
		ability_boxes.append(box)
	var hint := _mk_label(game_ui, Vector2(436, 694), Vector2(412, 16),
		"WASD MOVE  ·  J/K ATTACK  ·  SPACE DASH  ·  Q BURST  ·  1-4 STATS", 9,
		Color(0.45, 0.5, 0.62), HORIZONTAL_ALIGNMENT_CENTER)


func _build_messages() -> void:
	for i in 4:
		var l := _mk_label(game_ui, Vector2(436, 470 + i * 22), Vector2(412, 20), "", 11,
			Color(0.8, 0.85, 0.95), HORIZONTAL_ALIGNMENT_RIGHT)
		l.modulate.a = 0.0
		msg_labels.append(l)
		msg_timers.append(0.0)


func _build_banner() -> void:
	banner_title = _mk_label(root, Vector2(240, 150), Vector2(800, 48), "", 34,
		Color(1, 1, 1), HORIZONTAL_ALIGNMENT_CENTER)
	banner_sub = _mk_label(root, Vector2(240, 194), Vector2(800, 26), "", 13, CYAN,
		HORIZONTAL_ALIGNMENT_CENTER)
	banner_title.modulate.a = 0.0
	banner_sub.modulate.a = 0.0


func _build_title() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.01, 0.008, 0.02, 0.72)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(bg)

	var line_color := Color(0.18, 0.95, 1.0, 0.35)
	_add_line(c, Vector2(180, 108), Vector2(1100, 108), line_color)
	_add_line(c, Vector2(180, 604), Vector2(1100, 604), Color(1.0, 0.22, 0.56, 0.35))

	_mk_label(c, Vector2(140, 126), Vector2(1000, 100), "NEON CARNAGE", 76,
		Color(0.96, 0.98, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	var sub := _mk_label(c, Vector2(140, 226), Vector2(1000, 34), "ANARCHY NEVER SLEEPS", 20,
		Color(1.0, 0.30, 0.60), HORIZONTAL_ALIGNMENT_CENTER)
	sub.add_theme_constant_override("shadow_offset_x", 2)

	var story := _mk_label(c, Vector2(300, 272), Vector2(680, 96),
		"The city is a machine that eats the poor. Gangs sell chrome, guns and dreams by the gram. "
		+ "You are VEX — a slab of muscle and bad wiring with nothing left to lose. "
		+ "Fight through the sprawl, take their augments, and get stronger. Forever.",
		13, Color(0.78, 0.84, 0.94), HORIZONTAL_ALIGNMENT_CENTER)
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	var controls := [
		["MOVE", "WASD / ARROWS"],
		["LIGHT ATTACK", "J / LEFT MOUSE"],
		["HEAVY ATTACK", "K / RIGHT MOUSE"],
		["DASH (I-FRAMES)", "SPACE / SHIFT"],
		["OVERCLOCK BURST", "Q  (50 ENERGY)"],
		["SPEND STAT POINTS", "1 / 2 / 3 / 4"],
		["MUTE AUDIO", "M"],
	]
	for i in controls.size():
		var col := i % 2
		var row := i / 2
		var x := 380.0 + col * 300.0
		var y := 392.0 + row * 30.0
		_mk_label(c, Vector2(x, y), Vector2(130, 24), String(controls[i][0]), 11, CYAN)
		_mk_label(c, Vector2(x + 118, y), Vector2(180, 24), String(controls[i][1]), 11,
			Color(0.85, 0.88, 0.96))

	_mk_label(c, Vector2(140, 530), Vector2(1000, 24),
		"PROCEDURAL DISTRICTS  ·  ENDLESS LEVELS  ·  ENEMIES SCALE WITH YOU", 12,
		Color(0.70, 0.78, 0.92), HORIZONTAL_ALIGNMENT_CENTER)

	title_pulse = _mk_label(c, Vector2(140, 566), Vector2(1000, 30), "PRESS ENTER TO JACK IN", 16,
		GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	display_label = _mk_label(c, Vector2(140, 610), Vector2(1000, 18), "", 10,
		Color(0.5, 0.58, 0.72), HORIZONTAL_ALIGNMENT_CENTER)
	_mk_label(c, Vector2(140, 662), Vector2(1000, 20),
		"NEON CARNAGE  ·  BUILT WITH GODOT + GDSCRIPT", 9, Color(0.4, 0.45, 0.58),
		HORIZONTAL_ALIGNMENT_CENTER)
	return c


func _add_line(parent: Node, a: Vector2, b: Vector2, color: Color) -> void:
	var line := Line2D.new()
	line.points = PackedVector2Array([a, b])
	line.width = 1.5
	line.default_color = color
	parent.add_child(line)


func _build_death() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.005, 0.02, 0.90)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(bg)
	_mk_label(c, Vector2(140, 150), Vector2(1000, 110), "FLATLINED", 84, Color(1.0, 0.20, 0.40),
		HORIZONTAL_ALIGNMENT_CENTER)
	_mk_label(c, Vector2(140, 264), Vector2(1000, 30), "YOUR SIGNAL WENT DARK", 16,
		Color(0.8, 0.5, 0.6), HORIZONTAL_ALIGNMENT_CENTER)
	death_stats = _mk_label(c, Vector2(140, 330), Vector2(1000, 130), "", 16,
		Color(0.88, 0.92, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	death_stats.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_mk_label(c, Vector2(140, 500), Vector2(1000, 30), "PRESS R TO REBOOT THE DISTRICT", 18,
		GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_mk_label(c, Vector2(140, 536), Vector2(1000, 24), "REBOOT BURNS 25% OF YOUR XP — LEVELS AND GEAR SURVIVE", 10,
		Color(0.6, 0.65, 0.78), HORIZONTAL_ALIGNMENT_CENTER)
	return c


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func bind(p, l) -> void:
	player = p
	level = l
	_refresh_character()


func show_title() -> void:
	mode = Mode.TITLE
	game_ui.visible = false
	title_screen.visible = true
	death_screen.visible = false
	_set_banner_visible(false)


func show_playing() -> void:
	mode = Mode.PLAYING
	game_ui.visible = true
	title_screen.visible = false
	death_screen.visible = false


func show_death() -> void:
	mode = Mode.DEAD
	death_screen.visible = true
	game_ui.visible = false
	_set_banner_visible(false)
	var mins := int(Game.run_time) / 60
	var secs := int(Game.run_time) % 60
	var dist_name := "?"
	if level != null and is_instance_valid(level):
		dist_name = level.district_name
	death_stats.text = "LEVEL %d      DISTRICT %d // %s\n\nKILLS %d      CREDITS %d      THREAT %.1f\n\nRUN TIME %02d:%02d      BEST LEVEL %d" % [
		Game.level, Game.district, dist_name, Game.kills, Game.credits, Game.threat(),
		mins, secs, Game.best_level,
	]


func flash_screen(color: Color) -> void:
	if flash_rect == null:
		return
	flash_rect.color = color
	if notice_tween != null and notice_tween.is_valid():
		notice_tween.kill()
	notice_tween = create_tween()
	notice_tween.tween_property(flash_rect, "color:a", 0.0, 0.30)


func banner(title: String, subtitle: String = "", color: Color = Color(1, 1, 1)) -> void:
	banner_title.text = title
	banner_title.add_theme_color_override("font_color", color)
	banner_sub.text = subtitle
	banner_sub.add_theme_color_override("font_color", Color(color, 0.85))
	_set_banner_visible(true)
	banner_title.modulate.a = 0.0
	banner_sub.modulate.a = 0.0
	if banner_tween != null and banner_tween.is_valid():
		banner_tween.kill()
	banner_tween = create_tween()
	banner_tween.set_parallel(true)
	banner_tween.tween_property(banner_title, "modulate:a", 1.0, 0.15)
	banner_tween.tween_property(banner_sub, "modulate:a", 1.0, 0.22)
	banner_tween.set_parallel(false)
	banner_tween.tween_interval(1.65)
	banner_tween.set_parallel(true)
	banner_tween.tween_property(banner_title, "modulate:a", 0.0, 0.35)
	banner_tween.tween_property(banner_sub, "modulate:a", 0.0, 0.35)


func _set_banner_visible(v: bool) -> void:
	if banner_title == null:
		return
	banner_title.visible = v
	banner_sub.visible = v


func push_message(text: String, color: Color = Color(0.8, 0.85, 0.95)) -> void:
	for i in range(msg_labels.size() - 1, 0, -1):
		msg_labels[i].text = msg_labels[i - 1].text
		msg_labels[i].add_theme_color_override("font_color", msg_labels[i - 1].get_theme_color("font_color"))
		msg_timers[i] = msg_timers[i - 1]
	msg_labels[0].text = text
	msg_labels[0].add_theme_color_override("font_color", color)
	msg_timers[0] = 6.0
	msg_labels[0].modulate.a = 1.0


func _refresh_character() -> void:
	if stats_rows.is_empty():
		return
	var rows := [
		["1  STRENGTH", "strength"],
		["2  VITALITY", "vitality"],
		["3  AGILITY", "agility"],
		["4  TECH", "tech"],
	]
	for i in rows.size():
		var key: String = rows[i][1]
		var hint: String = Game.STAT_HINTS[key]
		stats_rows[i].text = "%s        %2d        %s" % [rows[i][0], int(Game.stats[key]), hint]
	if Game.stat_points > 0:
		points_label.text = "◆ %d STAT POINTS AVAILABLE — PRESS 1-4" % Game.stat_points
		points_label.add_theme_color_override("font_color", GOLD)
	else:
		points_label.text = "NO UNSPENT POINTS"
		points_label.add_theme_color_override("font_color", Color(0.45, 0.5, 0.62))
	var d: Dictionary = Game.derived()
	derived_label.text = "DMG %.0f   CRIT %.0f%%   ARMOR %.0f%%   LIFESTEAL %.0f%%\nTHREAT %.1f   DASH %.2fs" % [
		float(d.damage), float(d.crit) * 100.0, float(d.damage_reduction) * 100.0,
		float(d.lifesteal) * 100.0, Game.threat(), float(d.dash_cd),
	]
	_refresh_gear()


func _refresh_gear() -> void:
	var slots := ["weapon", "armor", "implant"]
	for i in slots.size():
		var slot: String = slots[i]
		var item: Dictionary = Game.gear.get(slot, {})
		var row: Dictionary = gear_rows[i]
		row.slot.text = Game.SLOT_NAMES[slot]
		if item.is_empty():
			row.name.text = "— EMPTY —"
			row.name.add_theme_color_override("font_color", DIM)
			row.mods.text = ""
		else:
			var color: Color = Game.RARITY_COLORS[clampi(int(item.rarity), 0, 4)]
			row.name.text = "%s  [PWR %d]" % [item.name, int(item.power)]
			row.name.add_theme_color_override("font_color", color)
			var parts: Array = []
			var mods: Dictionary = item.get("mods", {})
			for k in mods:
				parts.append(Loot.mod_text(k, float(mods[k])))
			row.mods.text = "  ·  ".join(parts)


func _on_message(text: String, color: Color) -> void:
	push_message(text, color)


func _on_gear_changed(_slot: String, _item: Dictionary, _equipped: bool) -> void:
	_refresh_gear()


func _on_leveled_up(new_level: int, points: int) -> void:
	banner("LEVEL %d" % new_level, "+%d STAT POINTS — PRESS 1-4" % points, GOLD)
	Sfx.play_ui("levelup", 1.0)
	_refresh_character()


func _update_display_label() -> void:
	if display_label == null:
		return
	display_label.text = "DISPLAY: %s   ·   F11 FULLSCREEN   ·   F10 WINDOW SIZE   ·   M MUTE   ·   ESC QUIT" % Settings.current_description()


# ---------------------------------------------------------------------------
# Loop + input
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	if mode == Mode.TITLE and title_pulse != null:
		title_pulse.modulate.a = 0.55 + 0.45 * sin(_time * 3.0)
	if mode != Mode.PLAYING:
		return
	if player == null or not is_instance_valid(player):
		return

	hp_bar.set_value(float(player.hp) / maxf(1.0, float(player.max_hp)))
	hp_text.text = "%d / %d" % [int(round(player.hp)), int(round(player.max_hp))]
	en_bar.set_value(float(player.energy) / maxf(1.0, float(player.energy_max)))
	en_text.text = "EN %d" % int(player.energy)
	xp_bar.set_value(Game.xp / maxf(1.0, Game.xp_needed))
	xp_text.text = "XP %d / %d" % [int(Game.xp), int(Game.xp_needed)]
	name_label.text = "VEX // LVL %02d" % Game.level
	credits_label.text = "CR %d" % Game.credits
	if level != null and is_instance_valid(level):
		sector_label.text = level.get_arena_status()
		if level.enemies.size() > 0:
			kills_label.text = "THREAT %.1f  ·  KILLS %d  ·  HOSTILES %d" % [Game.threat(), Game.kills, level.enemies.size()]
		else:
			kills_label.text = "THREAT %.1f  ·  KILLS %d" % [Game.threat(), Game.kills]
		threat_label.text = "DISTRICT %02d // %s" % [Game.district, level.district_name]
	else:
		kills_label.text = "THREAT %.1f  ·  KILLS %d" % [Game.threat(), Game.kills]

	var d: Dictionary = player.derived
	if d.size() > 0:
		var dash_ratio: float = 1.0
		var max_cd := maxf(0.001, float(d.dash_cd))
		dash_ratio = 1.0 - clampf(float(player.dash_cd) / max_cd, 0.0, 1.0)
		ability_boxes[0].set_data(1.0, "COMBO x3")
		ability_boxes[1].set_data(1.0, "BREAKER")
		ability_boxes[2].set_data(dash_ratio, "I-FRAMES")
		var burst_ratio: float = clampf(float(player.energy) / 50.0, 0.0, 1.0)
		ability_boxes[3].set_data(burst_ratio, "50 EN")

	for i in msg_labels.size():
		if msg_timers[i] > 0.0:
			msg_timers[i] -= delta
			msg_labels[i].modulate.a = clampf(msg_timers[i], 0.0, 1.0)
		else:
			msg_labels[i].modulate.a = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match mode:
		Mode.TITLE:
			if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER or key.keycode == KEY_SPACE:
				start_requested.emit()
				get_viewport().set_input_as_handled()
		Mode.DEAD:
			if key.keycode == KEY_R or key.keycode == KEY_ENTER:
				restart_requested.emit()
				get_viewport().set_input_as_handled()
		Mode.PLAYING:
			match key.keycode:
				KEY_1:
					Game.allocate_stat("strength")
				KEY_2:
					Game.allocate_stat("vitality")
				KEY_3:
					Game.allocate_stat("agility")
				KEY_4:
					Game.allocate_stat("tech")
