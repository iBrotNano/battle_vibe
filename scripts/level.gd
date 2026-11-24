class_name Level
extends Node2D
## One procedurally generated district: arenas, waves, gates, loot and a player.

signal district_cleared
signal player_died
signal announce(title: String, subtitle: String, color: Color)

const DISTRICT_NAMES := [
	"KOWLOON SPRAWL", "CHROME MARKET", "THE GUTTERS", "NEON CEMETERY",
	"SALT DISTRICT", "REDLINE", "BLACK ICE TOWERS", "HELIX SLUMS",
]

var player
var enemies: Array = []
var arenas: Array = []
var district_index := 1
var district_name := "KOWLOON SPRAWL"
var rng := RandomNumberGenerator.new()
var total_width := 0.0
var active_arena := -1
var actors: Node2D
var projectile_root: Node2D
var backdrop: Backdrop
var district_done := false
var camera_ref: Camera2D
var seed_value := 0
var run_bonus := 0


func build(district_idx: int, seed_val: int, cam: Camera2D) -> void:
	district_index = district_idx
	seed_value = seed_val
	camera_ref = cam
	district_name = DISTRICT_NAMES[(district_index - 1) % DISTRICT_NAMES.size()]
	rng.seed = seed_val + district_index * 104729
	district_done = false
	active_arena = -1
	enemies.clear()
	arenas.clear()

	for c in get_children():
		remove_child(c)
		c.queue_free()

	_generate_arenas()

	backdrop = Backdrop.new()
	add_child(backdrop)
	backdrop.configure(total_width, seed_val + district_index * 13, district_index, cam)

	actors = Node2D.new()
	actors.name = "Actors"
	add_child(actors)

	projectile_root = Node2D.new()
	projectile_root.name = "Projectiles"
	add_child(projectile_root)

	player = Player.new()
	player.level_ref = self
	actors.add_child(player)
	player.position = Vector2(240.0, 220.0)
	player.bounds_min_x = 40.0
	player.bounds_max_x = total_width + 500.0
	player.apply_stats()
	player.hp = player.max_hp
	player.energy = player.energy_max
	player.died.connect(_on_player_died)

	announce.emit("DISTRICT %02d" % district_index, district_name, Color(0.2, 0.95, 1.0))


func _generate_arenas() -> void:
	var arena_count := 3 + mini(district_index / 2, 2) + rng.randi_range(0, 1)
	var cursor := 420.0
	for i in arena_count:
		var width := rng.randf_range(1400.0, 1760.0)
		var start := cursor
		var end := cursor + width
		var wave_count := 2 + mini(district_index / 2, 2)
		if i == arena_count - 1:
			wave_count += 1
		var waves: Array = []
		for w in wave_count:
			var count := 2 + w + mini(district_index, 3) + rng.randi_range(0, 1)
			count = mini(count, 7)
			var specs: Array = []
			for e in count:
				specs.append(_pick_enemy_spec(w == wave_count - 1))
			waves.append(specs)
		arenas.append({
			"start": start,
			"end": end,
			"waves": waves,
			"wave": 0,
			"cleared": false,
			"active": false,
			"delay": 0.9,
		})
		cursor = end + rng.randf_range(280.0, 400.0)
	total_width = cursor + 520.0


func _pick_enemy_spec(final_wave: bool) -> Dictionary:
	var roll := rng.randf()
	var kind := "thug"
	if district_index <= 1:
		if roll < 0.20:
			kind = "gunner"
	elif district_index == 2:
		if roll < 0.18:
			kind = "gunner"
		elif roll < 0.36:
			kind = "drone"
		elif roll < 0.52:
			kind = "bruiser"
	else:
		if roll < 0.16:
			kind = "gunner"
		elif roll < 0.36:
			kind = "drone"
		elif roll < 0.55:
			kind = "bruiser"
	var elite_chance := 0.05 + float(district_index) * 0.035
	if final_wave:
		elite_chance += 0.08
	var elite := rng.randf() < minf(elite_chance, 0.34)
	return {"kind": kind, "elite": elite}


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_cleanup_enemies()
	if player.dead:
		return
	_update_separation()
	_update_arenas(delta)
	if not district_done and _all_arenas_cleared() and player.position.x > total_width - 240.0:
		district_done = true
		player.control_enabled = false
		Game.add_xp(90.0 * Game.threat() + 40.0 * district_index)
		Game.award_loot(true)
		Game.award_loot(true)
		Game.add_credits(60 + district_index * 40)
		announce.emit("DISTRICT CLEAR", "%s SECURED" % district_name, Color(1.0, 0.75, 0.2))
		Sfx.play_ui("district_clear", 2.0)
		district_cleared.emit()
	if active_arena >= 0:
		queue_redraw()


func _cleanup_enemies() -> void:
	for i in range(enemies.size() - 1, -1, -1):
		var e = enemies[i]
		if e == null or not is_instance_valid(e) or e.dead:
			if e == null or not is_instance_valid(e):
				enemies.remove_at(i)


func _update_arenas(delta: float) -> void:
	if active_arena < 0:
		for i in arenas.size():
			var a: Dictionary = arenas[i]
			if not bool(a.cleared) and player.position.x > float(a.start) + 150.0:
				_activate_arena(i)
				break
		return

	var a: Dictionary = arenas[active_arena]
	if not bool(a.active):
		return
	if enemies.is_empty():
		a.delay = float(a.delay) - delta
		if float(a.delay) <= 0.0:
			if int(a.wave) + 1 < a.waves.size():
				a.wave = int(a.wave) + 1
				_spawn_wave(a)
				a.delay = 1.1
				announce.emit("WAVE %d / %d" % [int(a.wave) + 1, a.waves.size()], "", Color(1.0, 0.35, 0.6))
			else:
				_clear_arena(active_arena)


func _activate_arena(index: int) -> void:
	var a: Dictionary = arenas[index]
	a.active = true
	a.wave = 0
	a.delay = 1.0
	active_arena = index
	player.bounds_min_x = float(a.start) + 40.0
	player.bounds_max_x = float(a.end) - 70.0
	_spawn_wave(a)
	announce.emit("SECTOR %d" % (index + 1), "GANG TERRITORY — CLEAR THEM OUT", Color(1.0, 0.3, 0.55))
	Sfx.play_ui("alert", -1.0)
	queue_redraw()


func _spawn_wave(a: Dictionary) -> void:
	var specs: Array = a.waves[int(a.wave)]
	var arena_start := float(a.start)
	var arena_end := float(a.end)
	Sfx.play("portal", Vector2((arena_start + arena_end) * 0.5, 210.0), -2.0, randf_range(0.92, 1.06))
	for spec in specs:
		var e := Enemy.new()
		e.level_ref = self
		e.target = player
		e.configure(String(spec.kind), bool(spec.elite), Game.threat(), district_index)
		var side := 1
		if absf(player.position.x - (arena_end - 110.0)) < 330.0:
			side = -1
		var sx := arena_end - 110.0 if side > 0 else arena_start + 110.0
		var sy := rng.randf_range(85.0, 315.0)
		e.position = Vector2(sx + rng.randf_range(-40.0, 40.0), sy)
		e.z_index = int(sy) + 20
		actors.add_child(e)
		e.died.connect(_on_enemy_died)
		enemies.append(e)
		Fx.portal(Vector2(sx, sy), e.tint)


func _clear_arena(index: int) -> void:
	var a: Dictionary = arenas[index]
	a.cleared = true
	a.active = false
	active_arena = -1
	enemies.clear()
	player.bounds_min_x = 40.0
	player.bounds_max_x = total_width + 500.0
	var xp_gain: float = (24.0 + 14.0 * a.waves.size()) * Game.threat()
	Game.add_xp(xp_gain)
	Game.award_loot(true)
	Game.add_credits(20 + district_index * 12)
	player.heal(player.max_hp * 0.18)
	announce.emit("SECTOR CLEAR", "+%d XP  ·  MOVE RIGHT" % int(xp_gain), Color(0.25, 1.0, 0.7))
	Sfx.play_ui("arena_clear", 0.0)
	queue_redraw()


func _on_enemy_died(enemy) -> void:
	if enemy in enemies:
		enemies.erase(enemy)
	if enemy == null or not is_instance_valid(enemy):
		return
	Game.kills += 1
	Game.add_xp(float(enemy.xp_value))
	if enemy.elite:
		Game.award_loot(true)
		Game.notify("ELITE DOWN // %s" % enemy.get_kind_name(), enemy.tint)
	elif randf() < 0.14:
		Game.award_loot(false)
	else:
		var cr := int(2 + randf() * 5 + district_index)
		Game.add_credits(cr)
	Fx.spark(enemy.global_position + Vector2(0, -50), enemy.tint, 10, 1.2)


func _on_player_died() -> void:
	player_died.emit()


func _all_arenas_cleared() -> bool:
	for a in arenas:
		if not bool(a.cleared):
			return false
	return true


func _update_separation() -> void:
	for i in range(enemies.size()):
		var a = enemies[i]
		if a == null or not is_instance_valid(a) or a.dead:
			continue
		for j in range(i + 1, enemies.size()):
			var b = enemies[j]
			if b == null or not is_instance_valid(b) or b.dead:
				continue
			var d: Vector2 = b.position - a.position
			d.y *= 1.6
			var dist := d.length()
			if dist < 36.0 and dist > 0.01:
				var push := d.normalized() * (36.0 - dist) * 0.5
				a.position -= push
				b.position += push
		if active_arena >= 0:
			var arena: Dictionary = arenas[active_arena]
			a.position.x = clampf(a.position.x, float(arena.start) + 50.0, float(arena.end) - 50.0)
		if player != null and not player.dead:
			var pd: Vector2 = a.position - player.position
			if pd.length() < 32.0:
				a.position += pd.normalized() * (32.0 - pd.length()) * 0.4


func spawn_projectile(from: Vector2, dir: Vector2, dmg: float, tint: Color) -> void:
	var p := Projectile.new()
	p.target = player
	p.boot(from, dir, dmg, tint)
	projectile_root.add_child(p)


func camera_target_x() -> float:
	if player == null:
		return 0.0
	var look: float = player.position.x + float(player.facing) * 80.0
	if active_arena >= 0:
		var a: Dictionary = arenas[active_arena]
		var lo := float(a.start) + 430.0
		var hi := float(a.end) - 430.0
		if hi < lo:
			hi = lo
		return clampf(look, lo, hi)
	return clampf(look, 640.0, maxf(total_width + 200.0, 640.0))


func _draw() -> void:
	if active_arena < 0 or active_arena >= arenas.size():
		return
	var a: Dictionary = arenas[active_arena]
	if not bool(a.active):
		return
	var pulse := 0.45 + 0.25 * sin(Time.get_ticks_msec() * 0.006)
	var c := Color(0.2, 0.95, 1.0, pulse)
	for gx in [float(a.start) + 40.0, float(a.end) - 70.0]:
		draw_line(Vector2(gx, -60.0), Vector2(gx, 355.0), Color(c, 0.30), 10.0, true)
		draw_line(Vector2(gx, -60.0), Vector2(gx, 355.0), c, 2.0, true)
		var y := 0.0
		while y < 355.0:
			draw_line(Vector2(gx - 8.0, y), Vector2(gx + 8.0, y + 16.0), Color(c, 0.55), 1.5, true)
			y += 28.0
		draw_circle(Vector2(gx, 352.0), 16.0, Color(c, 0.10))
		draw_arc(Vector2(gx, 352.0), 16.0, 0.0, TAU, 20, Color(c, 0.5), 2.0, true)


func get_arena_status() -> String:
	if active_arena >= 0:
		var a: Dictionary = arenas[active_arena]
		return "SECTOR %d/%d  ·  WAVE %d/%d" % [active_arena + 1, arenas.size(), int(a.wave) + 1, a.waves.size()]
	var cleared := 0
	for a in arenas:
		if bool(a.cleared):
			cleared += 1
	return "SECTOR %d/%d  ·  ROAMING" % [cleared, arenas.size()]
