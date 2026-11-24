class_name Player
extends Actor

signal died

enum State { FREE, ATTACK, DASH, DEAD }

const LIGHT_ATTACKS := [
	{
		"dur": 0.30, "start": 0.055, "active": 0.17, "reach": 86.0, "depth": 42.0,
		"mult": 1.00, "knock": 230.0, "stop": 0.018, "shake": 2.0, "lunge": 20.0,
	},
	{
		"dur": 0.32, "start": 0.06, "active": 0.19, "reach": 90.0, "depth": 44.0,
		"mult": 1.08, "knock": 250.0, "stop": 0.02, "shake": 2.5, "lunge": 22.0,
	},
	{
		"dur": 0.48, "start": 0.13, "active": 0.30, "reach": 104.0, "depth": 52.0,
		"mult": 1.75, "knock": 560.0, "stop": 0.07, "shake": 6.0, "lunge": 34.0,
	},
]

const HEAVY_ATTACK := {
	"dur": 0.62, "start": 0.30, "active": 0.46, "reach": 112.0, "depth": 56.0,
	"mult": 2.45, "knock": 720.0, "stop": 0.09, "shake": 8.0, "lunge": 46.0,
}

var state := State.FREE
var level_ref
var derived := {}
var energy := 100.0
var energy_max := 100.0
var dash_cd := 0.0
var bounds_min_x := 40.0
var bounds_max_x := 99999.0
var control_enabled := true
var regen_timer := 0.0
var step_timer := 0.0

var attack_kind := "light"
var attack_step := 0
var attack_time := 0.0
var attack_hits: Dictionary = {}
var buffer_light := 0.0
var buffer_heavy := 0.0

var dash_time := 0.0
var dash_dir := Vector2.RIGHT
var dash_ghost_timer := 0.0
var special_time := 0.0


func _ready() -> void:
	super._ready()
	z_as_relative = false
	apply_stats()
	hp = max_hp
	energy = energy_max
	Game.stats_changed.connect(apply_stats)


func apply_stats() -> void:
	var d: Dictionary = Game.derived()
	var old_max := max_hp
	derived = d
	max_hp = float(d.max_hp)
	if old_max > 0.0:
		hp = minf(max_hp, hp + (max_hp - old_max))
	else:
		hp = max_hp
	energy_max = float(d.energy_max)
	energy = minf(energy, energy_max)


func _process(delta: float) -> void:
	base_update(delta)
	if dead or state == State.DEAD:
		queue_redraw()
		return

	dash_cd = maxf(0.0, dash_cd - delta)
	buffer_light = maxf(0.0, buffer_light - delta)
	buffer_heavy = maxf(0.0, buffer_heavy - delta)
	regen_timer = maxf(0.0, regen_timer - delta)
	energy = minf(energy_max, energy + float(derived.energy_regen) * delta)
	if regen_timer <= 0.0 and hp < max_hp:
		hp = minf(max_hp, hp + max_hp * 0.02 * delta)

	if not control_enabled:
		speed_actual = 0.0
		queue_redraw()
		return

	match state:
		State.FREE:
			_update_free(delta)
		State.ATTACK:
			_update_attack(delta)
		State.DASH:
			_update_dash(delta)

	position.x = clampf(position.x, bounds_min_x, bounds_max_x)
	queue_redraw()


func _update_free(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if state != State.ATTACK and absf(input.x) > 0.1:
		facing = 1 if input.x > 0.0 else -1
	var speed: float = float(derived.move_speed)
	speed_actual = input.length() * speed
	var mv := Vector2(input.x * speed, input.y * speed * 0.62)
	position += mv * delta

	step_timer -= delta
	if speed_actual > 30.0 and step_timer <= 0.0:
		step_timer = 0.30
		Sfx.play("step", global_position, -8.0, randf_range(0.85, 1.15))

	if Input.is_action_just_pressed("light_attack"):
		_start_attack("light", 0)
		return
	if Input.is_action_just_pressed("heavy_attack"):
		_start_attack("heavy", 0)
		return
	if Input.is_action_just_pressed("special"):
		_try_special()
		return
	if Input.is_action_just_pressed("dash"):
		_try_dash(input)


func _update_attack(delta: float) -> void:
	attack_time += delta
	speed_actual = 60.0
	if Input.is_action_just_pressed("light_attack"):
		buffer_light = 0.25
	if Input.is_action_just_pressed("heavy_attack"):
		buffer_heavy = 0.25

	var data := _attack_data()
	var p := attack_time / maxf(float(data.dur), 0.001)
	if p >= 0.30 and p <= 0.75:
		position.x += float(facing) * float(data.lunge) * delta

	if attack_kind == "special":
		special_time += delta
		if attack_time >= 0.5:
			state = State.FREE
			attack_step = 0
			special_time = 0.0
		return

	if attack_time >= float(data.start) and attack_time <= float(data.active):
		_do_hit_check(data)

	if attack_time >= float(data.dur):
		state = State.FREE
		if attack_kind == "light" and attack_step < 2 and buffer_light > 0.0:
			_start_attack("light", attack_step + 1)
		elif attack_kind == "heavy" and buffer_light > 0.0:
			_start_attack("light", 0)
		else:
			attack_step = 0
		attack_kind = "light"


func _update_dash(delta: float) -> void:
	dash_time -= delta
	speed_actual = 700.0
	var spd := 720.0
	position += dash_dir * Vector2(spd, spd * 0.60) * delta
	dash_ghost_timer -= delta
	if dash_ghost_timer <= 0.0:
		dash_ghost_timer = 0.045
		Fx.spark(global_position + Vector2(0, -50), Color(0.2, 0.9, 1.0, 0.6), 2, 0.4)
	if dash_time <= 0.0:
		state = State.FREE
		invuln = maxf(invuln, 0.05)


func _attack_data() -> Dictionary:
	var base: Dictionary
	if attack_kind == "heavy":
		base = HEAVY_ATTACK
	elif attack_kind == "special":
		base = HEAVY_ATTACK
	else:
		base = LIGHT_ATTACKS[clampi(attack_step, 0, LIGHT_ATTACKS.size() - 1)]
	var spd: float = maxf(1.0, float(derived.attack_speed))
	return {
		"dur": float(base.dur) / spd,
		"start": float(base.start) / spd,
		"active": float(base.active) / spd,
		"reach": float(base.reach),
		"depth": float(base.depth),
		"mult": float(base.mult),
		"knock": float(base.knock),
		"stop": float(base.stop),
		"shake": float(base.shake),
		"lunge": float(base.lunge),
	}


func _start_attack(kind: String, step: int) -> void:
	if state == State.DASH:
		return
	state = State.ATTACK
	attack_kind = kind
	attack_step = step
	attack_time = 0.0
	attack_hits.clear()
	buffer_light = 0.0
	buffer_heavy = 0.0
	_soft_aim()
	if kind == "heavy":
		Fx.shake(1.5, 0.12)
		Sfx.play("swing_heavy", global_position, 0.0, randf_range(0.95, 1.05))
	else:
		Sfx.play("swing_light", global_position, -1.0, randf_range(0.90, 1.15))


func _soft_aim() -> void:
	var best = null
	var best_d := 9999.0
	for e in level_ref.enemies:
		if e == null or not is_instance_valid(e) or e.dead:
			continue
		var dx: float = (e.position.x - position.x) * float(facing)
		if dx < -8.0 or dx > 150.0:
			continue
		var dy: float = absf(e.position.y - position.y)
		if dy > 74.0:
			continue
		var score: float = absf(dx - 55.0) + dy * 0.6
		if score < best_d:
			best_d = score
			best = e
	if best != null:
		position.y = move_toward(position.y, best.position.y, 22.0)
		if absf(best.position.y - position.y) < 10.0:
			position.y = best.position.y


func _do_hit_check(data: Dictionary) -> void:
	var dmg_base: float = float(derived.damage) * float(data.mult)
	for e in level_ref.enemies:
		if e == null or not is_instance_valid(e) or e.dead:
			continue
		if attack_hits.has(e):
			continue
		var dx: float = (e.position.x - position.x) * float(facing)
		var dy: float = absf(e.position.y - position.y)
		if dx < -18.0 or dx > float(data.reach) + e.radius:
			continue
		if dy > float(data.depth) + e.radius * 0.5:
			continue
		var crit: bool = randf() < float(derived.crit)
		var dmg: float = dmg_base * randf_range(0.92, 1.08)
		if crit:
			dmg *= float(derived.crit_mult)
			Fx.hitstop(0.035)
			Fx.flash(Color(1.0, 0.85, 0.3, 0.10))
		var hit: bool = e.take_damage(dmg, global_position, float(data.knock), crit)
		if hit:
			attack_hits[e] = true
			energy = minf(energy_max, energy + 6.0)
			var ls: float = float(derived.lifesteal)
			if ls > 0.0:
				heal(dmg * ls)
			Fx.spark(e.global_position + Vector2(0, -60), Color(0.2, 0.95, 1.0), 9, 1.0)
			var heavy_hit: bool = attack_kind == "heavy" or attack_step == 2
			Sfx.play("hit_heavy" if heavy_hit else "hit_light", e.global_position,
				1.0 if heavy_hit else -1.0, randf_range(0.92, 1.10))
	if attack_hits.size() > 0 and (attack_kind == "heavy" or attack_step == 2):
		Fx.hitstop(float(data.stop))
		Fx.shake(float(data.shake), 0.22)


func _try_dash(input: Vector2) -> void:
	if dash_cd > 0.0 or state == State.ATTACK:
		return
	state = State.DASH
	dash_time = 0.19
	dash_cd = float(derived.dash_cd)
	invuln = 0.28
	if input.length() > 0.1:
		dash_dir = input.normalized()
	else:
		dash_dir = Vector2(float(facing), 0.0)
	dash_ghost_timer = 0.0
	Fx.spark(global_position + Vector2(0, -40), Color(0.2, 0.9, 1.0, 0.7), 5, 0.6)
	Sfx.play("dash", global_position, 0.5, randf_range(0.95, 1.08))


func _try_special() -> void:
	if energy < 50.0 or state != State.FREE:
		return
	energy -= 50.0
	state = State.ATTACK
	attack_kind = "special"
	attack_step = 0
	attack_time = 0.0
	special_time = 0.0
	invuln = 0.55
	attack_hits.clear()
	Fx.shockwave(global_position, Color(0.2, 0.95, 1.0))
	Fx.shake(10.0, 0.45)
	Fx.hitstop(0.06)
	Fx.flash(Color(0.2, 0.8, 1.0, 0.16))
	Sfx.play("overclock", global_position, 1.0, 1.0)
	var dmg_base: float = float(derived.damage) * 2.3
	for e in level_ref.enemies:
		if e == null or not is_instance_valid(e) or e.dead:
			continue
		var dx: float = absf(e.position.x - position.x)
		var dy: float = absf(e.position.y - position.y)
		if dx <= 195.0 and dy <= 115.0:
			var crit: bool = randf() < float(derived.crit)
			var dmg: float = dmg_base * randf_range(0.95, 1.05)
			if crit:
				dmg *= float(derived.crit_mult)
			e.take_damage(dmg, global_position, 760.0, crit)
			Fx.spark(e.global_position + Vector2(0, -60), Color(0.2, 0.95, 1.0), 10, 1.3)


func take_damage(amount: float, from_pos: Vector2, knock: float, crit: bool) -> bool:
	if dead or invuln > 0.0:
		return false
	var reduction: float = clampf(float(derived.damage_reduction), 0.0, 0.75)
	var actual: float = amount * (1.0 - reduction)
	var ok := super.take_damage(actual, from_pos, knock * 0.55, crit)
	if ok:
		regen_timer = 4.0
		energy = minf(energy_max, energy + 8.0)
		Fx.shake(5.0, 0.3)
		Fx.flash(Color(1.0, 0.1, 0.2, 0.22))
		Sfx.play("hurt", global_position, 1.0, randf_range(0.92, 1.08))
		if dead:
			pass
	return ok


func _die() -> void:
	super._die()
	state = State.DEAD
	Fx.shake(14.0, 0.7)
	Fx.hitstop(0.14)
	Sfx.play("die_player", global_position, 1.5, 1.0)
	died.emit()


func _draw() -> void:
	var t := anim_t
	var walk_ratio := clampf(speed_actual / 210.0, 0.0, 1.0)
	var swing := sin(t * 11.0) * walk_ratio * 12.0
	var breath := sin(t * 2.2) * 1.4

	var skin := Color(0.78, 0.52, 0.38)
	var skin_dark := Color(0.58, 0.36, 0.26)
	var jacket := Color(0.10, 0.13, 0.20)
	var jacket_hi := Color(0.19, 0.23, 0.34)
	var pants := Color(0.07, 0.09, 0.15)
	var chrome := Color(0.45, 0.53, 0.63)
	var chrome_hi := Color(0.70, 0.78, 0.86)
	var neon := Color(0.16, 0.94, 1.0)
	var hot := Color(1.0, 0.24, 0.56)
	var boot := Color(0.05, 0.06, 0.10)

	if dead:
		swing = 0.0
		breath = 0.0

	draw_shadow(34.0)
	# Rim light halo so the player pops out of the dark street.
	draw_circle(Vector2(0, -78), 44.0, Color(0.18, 0.85, 1.0, 0.035))
	draw_circle(Vector2(0, -78), 30.0, Color(1.0, 0.22, 0.55, 0.035))

	var ext := 0.0
	var heavy_pull := 0.0
	var active := false
	var data := {}
	if state == State.ATTACK:
		data = _attack_data()
		var p := clampf(attack_time / maxf(float(data.dur), 0.001), 0.0, 1.0)
		active = attack_time >= float(data.start) and attack_time <= float(data.active)
		if attack_kind == "light":
			ext = sin(p * PI) * 1.0
		elif attack_kind == "heavy":
			heavy_pull = clampf(1.0 - p / 0.45, 0.0, 1.0)
			ext = clampf((p - 0.38) / 0.30, 0.0, 1.0) * 1.25 - heavy_pull * 0.45
		elif attack_kind == "special":
			ext = 0.7
	elif state == State.DASH:
		ext = 0.35

	var hip := Vector2(0, -55 + breath * 0.4)
	var shoulder_y := -92 + breath
	var lean := ext * 4.0 + heavy_pull * -5.0

	# --- back leg -----------------------------------------------------------
	var bk := Vector2(-5 - swing * 0.4, -30)
	var bf := Vector2(-9 - swing, -2)
	limb3(hip + Vector2(-3, 0), bk, bf, 13.0, pants)
	draw_line(bf + Vector2(-4, -2), bf + Vector2(9, -2), boot, 8.0, true)

	# --- front leg ----------------------------------------------------------
	var fk := Vector2(6 + swing * 0.4, -30)
	var ff := Vector2(10 + swing, -2)
	limb3(hip + Vector2(3, 0), fk, ff, 14.0, pants.lightened(0.06))
	draw_line(ff + Vector2(-5, -2), ff + Vector2(10, -2), boot, 8.0, true)
	draw_line(ff + Vector2(-5, -1), ff + Vector2(10, -1), neon.darkened(0.2), 1.5, true)

	# --- back cybernetic arm ------------------------------------------------
	var bshoulder := Vector2(-21 + lean * 0.4, shoulder_y + 4)
	var belbow := Vector2(-30 - ext * 10, shoulder_y + 22)
	var bfist := Vector2(-34 - ext * 10 + swing * 0.4, shoulder_y + 42)
	limb3(bshoulder, belbow, bfist, 11.0, chrome.darkened(0.25))
	draw_line(bshoulder, belbow, neon.darkened(0.35), 2.0, true)
	draw_circle(bfist, 6.0, chrome)
	draw_circle(bfist, 3.0, neon)

	# --- torso --------------------------------------------------------------
	var lean_top := lean
	var torso := PackedVector2Array([
		Vector2(-26 + lean_top, shoulder_y - 2),
		Vector2(25 + lean_top, shoulder_y - 2),
		Vector2(31 + lean_top * 0.6, shoulder_y + 15),
		Vector2(17, -56),
		Vector2(-17, -56),
		Vector2(-31 + lean_top * 0.6, shoulder_y + 15),
	])
	draw_colored_polygon(torso, jacket)
	# open jacket chest
	var chest := PackedVector2Array([
		Vector2(-12 + lean_top * 0.6, shoulder_y + 2),
		Vector2(14 + lean_top * 0.6, shoulder_y + 2),
		Vector2(10, -58),
		Vector2(-9, -58),
	])
	draw_colored_polygon(chest, skin_dark)
	draw_line(Vector2(-11 + lean_top * 0.6, shoulder_y + 3), Vector2(-7, -58), skin, 3.0, true)
	draw_line(Vector2(13 + lean_top * 0.6, shoulder_y + 3), Vector2(9, -58), skin, 3.0, true)
	# pecs / abs
	draw_line(Vector2(-7, -76), Vector2(8, -76), skin.darkened(0.25), 2.0, true)
	draw_line(Vector2(-4, -66), Vector2(5, -66), skin.darkened(0.3), 2.0, true)
	# jacket collar + neon trim
	var collar := PackedVector2Array([
		Vector2(-26 + lean_top, shoulder_y - 2),
		Vector2(-8 + lean_top, shoulder_y + 8),
		Vector2(-12 + lean_top * 0.7, shoulder_y + 15),
		Vector2(-30 + lean_top * 0.6, shoulder_y + 7),
	])
	draw_colored_polygon(collar, jacket_hi)
	var trim := PackedVector2Array([
		Vector2(-31 + lean_top * 0.6, shoulder_y + 15),
		Vector2(-26 + lean_top, shoulder_y - 2),
		Vector2(-16, -56),
	])
	draw_polyline(trim, Color(neon, 0.85), 2.0, true)
	var trim2 := PackedVector2Array([
		Vector2(31 + lean_top * 0.6, shoulder_y + 15),
		Vector2(25 + lean_top, shoulder_y - 2),
		Vector2(15, -56),
	])
	draw_polyline(trim2, Color(hot, 0.85), 2.0, true)
	# belt
	draw_rect(Rect2(-17, -58, 34, 5), Color(0.03, 0.04, 0.07))
	draw_rect(Rect2(-17, -58, 34, 1), Color(neon, 0.7))
	# chest implant
	draw_circle(Vector2(15 + lean_top * 0.5, -79), 4.0, chrome)
	draw_circle(Vector2(15 + lean_top * 0.5, -79), 2.2, neon)
	var implant_pulse := 1.0 + sin(t * 4.0) * 0.25
	draw_circle(Vector2(15 + lean_top * 0.5, -79), 6.5 * implant_pulse, Color(neon, 0.15))

	# --- head ---------------------------------------------------------------
	var head := Vector2(2 + lean_top, -109 + breath)
	draw_line(Vector2(0 + lean_top, -94), head + Vector2(0, 10), skin_dark, 10.0, true)
	draw_circle(head, 12.0, skin)
	draw_circle(head + Vector2(-4, -2), 11.0, skin)
	# jaw shadow
	draw_arc(head + Vector2(0, 3), 9.0, 0.25, PI - 0.1, 12, skin_dark, 2.0, true)
	# mohawk
	var hawk := PackedVector2Array([
		head + Vector2(-11, -4),
		head + Vector2(-4, -17),
		head + Vector2(1, -8),
		head + Vector2(7, -16),
		head + Vector2(11, -3),
		head + Vector2(9, 1),
		head + Vector2(-9, 2),
	])
	draw_colored_polygon(hawk, hot.darkened(0.15))
	draw_polyline(PackedVector2Array([
		head + Vector2(-11, -4), head + Vector2(-4, -17),
		head + Vector2(1, -8), head + Vector2(7, -16), head + Vector2(11, -3),
	]), Color(1.0, 0.55, 0.75), 1.5, true)
	# visor
	var visor := Rect2(head + Vector2(-11, -4), Vector2(24, 7))
	draw_rect(visor, Color(0.02, 0.05, 0.09))
	draw_line(head + Vector2(-10, -1), head + Vector2(11, -1), neon, 2.5, true)
	draw_line(head + Vector2(-9, -2), head + Vector2(6, -2), Color(0.8, 1.0, 1.0, 0.8), 1.0, true)
	# ear implant
	draw_circle(head + Vector2(-10, 3), 3.2, chrome)
	draw_circle(head + Vector2(-10, 3), 1.5, hot)

	# --- front arm ----------------------------------------------------------
	var shoulder := Vector2(22 + lean * 0.5, shoulder_y + 4)
	var elbow := Vector2(28 + ext * 22, shoulder_y + 21 - ext * 8)
	var fist := Vector2(31 + ext * 49, shoulder_y + 39 - ext * 18)
	if heavy_pull > 0.0:
		fist = Vector2(6 - heavy_pull * 20, shoulder_y + 12)
		elbow = Vector2(24 - heavy_pull * 10, shoulder_y + 24)
	limb3(shoulder, elbow, fist, 12.0, skin)
	# sleeve
	limb(shoulder, shoulder.lerp(elbow, 0.55), 14.0, jacket_hi)
	draw_circle(fist, 7.5, skin)
	draw_circle(fist, 4.0, Color(neon, 0.9))
	draw_arc(fist, 9.0, 0.0, TAU, 16, Color(neon, 0.25), 2.0, true)
	# knuckle glow when winding / striking
	if active or heavy_pull > 0.2:
		draw_circle(fist, 13.0, Color(hot, 0.25))
		draw_circle(fist, 6.0, Color(1.0, 0.8, 0.9, 0.7))

	# --- attack arc ---------------------------------------------------------
	if active and data.size() > 0:
		var arc_col := Color(neon, 0.30)
		if attack_kind == "heavy":
			arc_col = Color(hot, 0.38)
		var r := float(data.reach) * 0.85
		draw_arc(Vector2(16, -72), r, -0.85, 0.85, 22, arc_col, 6.0, true)
		draw_arc(Vector2(16, -72), r * 0.72, -0.7, 0.7, 18, Color(1.0, 1.0, 1.0, 0.10), 12.0, true)

	# --- special aura -------------------------------------------------------
	if attack_kind == "special" and state == State.ATTACK:
		var pulse := 1.0 + sin(t * 30.0) * 0.08
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.34))
		draw_arc(Vector2.ZERO, 90.0 * pulse, 0.0, TAU, 40, Color(neon, 0.6), 5.0, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# --- dash afterimages ---------------------------------------------------
	if state == State.DASH:
		for i in 2:
			var off := -dash_dir * (10.0 + i * 11.0) * float(facing) * -1.0
			var ghost := Color(0.2, 0.9, 1.0, 0.16 - i * 0.05)
			draw_circle(Vector2(0, -80) + off, 22.0, ghost)
			draw_line(hip + off, Vector2(0, -80) + off, ghost, 10.0, true)

	# --- hurt flash ---------------------------------------------------------
	if hurt_flash > 0.0:
		var fa := clampf(hurt_flash / 0.13, 0.0, 1.0) * 0.6
		draw_circle(Vector2(0, -78), 26.0, Color(1.0, 1.0, 1.0, fa))
		draw_circle(Vector2(2, -108), 13.0, Color(1.0, 1.0, 1.0, fa))

	# --- low energy warning -------------------------------------------------
	if hp > 0.0 and hp / max_hp < 0.25:
		var pulse2 := (sin(t * 6.0) * 0.5 + 0.5) * 0.25
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.3))
		draw_arc(Vector2.ZERO, 42.0, 0.0, TAU, 32, Color(1.0, 0.15, 0.3, pulse2), 3.0, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
