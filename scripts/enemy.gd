class_name Enemy
extends Actor

signal died(enemy)

enum Kind { THUG, GUNNER, BRUISER, DRONE }

var kind := Kind.THUG
var target
var level_ref
var elite := false
var tint := Color(0.98, 0.22, 0.55)
var speed := 92.0
var damage := 8.0
var xp_value := 12.0
var attack_range := 62.0
var windup_max := 0.38
var windup := 0.0
var attack_cd := 0.6
var ai_state := "chase"
var stagger := 0.0
var armor := 0.0
var death_reported := false
var hover_t := 0.0
var shoot_cd := 1.2
var difficulty := 1.0
var telegraphed := false


func configure(kind_name: String, is_elite: bool, threat: float, district: int) -> void:
	elite = is_elite
	difficulty = threat
	match kind_name:
		"gunner":
			kind = Kind.GUNNER
		"bruiser":
			kind = Kind.BRUISER
		"drone":
			kind = Kind.DRONE
		_:
			kind = Kind.THUG

	var base_hp := 42.0
	var base_dmg := 7.0
	var base_xp := 14.0
	match kind:
		Kind.GUNNER:
			base_hp = 34.0
			base_dmg = 6.0
			base_xp = 16.0
			speed = 82.0
			attack_range = 330.0
			windup_max = 0.55
			body_scale = 0.98
		Kind.BRUISER:
			base_hp = 115.0
			base_dmg = 15.0
			base_xp = 30.0
			speed = 64.0
			attack_range = 70.0
			windup_max = 0.62
			body_scale = 1.30
			armor = 0.16
		Kind.DRONE:
			base_hp = 30.0
			base_dmg = 9.0
			base_xp = 20.0
			speed = 145.0
			attack_range = 90.0
			windup_max = 0.34
			body_scale = 1.0
			armor = 0.05
		_:
			base_hp = 42.0
			base_dmg = 7.0
			base_xp = 14.0
			speed = 96.0
			attack_range = 60.0
			windup_max = 0.36
			body_scale = 0.94

	if elite:
		base_hp *= 2.4
		base_dmg *= 1.45
		base_xp *= 2.8
		armor += 0.08
		body_scale *= 1.16

	var hp_mult := 1.0 + 0.78 * maxf(0.0, threat - 1.0)
	var dmg_mult := 1.0 + 0.30 * maxf(0.0, threat - 1.0)
	max_hp = base_hp * hp_mult
	hp = max_hp
	damage = base_dmg * dmg_mult
	xp_value = base_xp * (1.0 + 0.16 * maxf(0.0, threat - 1.0))
	speed *= 1.0 + 0.012 * maxf(0.0, threat - 1.0) + district * 0.02
	attack_cd = randf_range(0.4, 1.1)
	shoot_cd = randf_range(0.8, 1.8)

	var palette := [
		Color(1.0, 0.22, 0.55), Color(0.25, 1.0, 0.72), Color(0.4, 0.7, 1.0),
		Color(1.0, 0.55, 0.15), Color(0.85, 0.35, 1.0), Color(1.0, 0.85, 0.2),
	]
	tint = palette[randi() % palette.size()]
	if district > 0 and randi() % 3 != 0:
		tint = DistrictColors.color_for(district)
	z_as_relative = false
	anim_t = randf() * 7.0
	hover_t = randf() * TAU


func _process(delta: float) -> void:
	base_update(delta)
	if dead:
		if not death_reported:
			death_reported = true
			died.emit(self)
		queue_redraw()
		return

	hover_t += delta * 4.0
	if stagger > 0.0:
		stagger -= delta
		queue_redraw()
		return
	if target == null or not is_instance_valid(target) or target.dead:
		queue_redraw()
		return

	speed_actual = 0.0
	var dx: float = target.position.x - position.x
	var dy: float = target.position.y - position.y
	var flat := Vector2(dx, dy)
	facing = 1 if dx >= 0.0 else -1

	if kind == Kind.GUNNER:
		_ai_gunner(dx, dy, flat, delta)
	elif kind == Kind.DRONE:
		_ai_drone(dx, dy, flat, delta)
	else:
		_ai_melee(dx, dy, flat, delta)

	queue_redraw()


func _ai_melee(dx: float, dy: float, flat: Vector2, delta: float) -> void:
	if ai_state == "windup":
		windup -= delta
		if windup <= 0.0:
			_strike_melee()
			ai_state = "recover"
			attack_cd = randf_range(0.7, 1.3)
		return
	if ai_state == "recover":
		attack_cd -= delta
		if attack_cd <= 0.0:
			ai_state = "chase"
		return

	attack_cd -= delta
	var dist := Vector2(dx, dy * 1.5).length()
	if dist > attack_range * 0.9 or absf(dy) > 26.0:
		var dir := Vector2(signf(dx), clampf(dy / 45.0, -1.0, 1.0) * 0.55).normalized()
		position += dir * speed * delta
		speed_actual = speed
	elif attack_cd <= 0.0:
		ai_state = "windup"
		windup = windup_max


func _strike_melee() -> void:
	if target == null or target.dead:
		return
	Sfx.play("swing_heavy", global_position, -3.0 if kind == Kind.DRONE else 0.0,
		randf_range(1.05, 1.25) if kind == Kind.DRONE else randf_range(0.80, 0.92))
	var dx: float = absf(target.position.x - position.x)
	var dy: float = absf(target.position.y - position.y)
	if kind == Kind.DRONE:
		if dx < 105.0 and dy < 52.0:
			target.take_damage(damage, global_position, 340.0, false)
			Fx.spark(target.global_position + Vector2(0, -60), tint, 8, 1.0)
		return
	if dx < attack_range + 22.0 and dy < 38.0:
		target.take_damage(damage, global_position, 280.0, false)
		Fx.spark(target.global_position + Vector2(0, -60), tint, 7, 0.9)
		if kind == Kind.BRUISER:
			Fx.shake(4.0, 0.2)


func _ai_gunner(dx: float, dy: float, flat: Vector2, delta: float) -> void:
	if ai_state == "windup":
		windup -= delta
		if windup <= 0.0:
			_fire()
			ai_state = "recover"
			attack_cd = randf_range(1.1, 1.9)
		return
	if ai_state == "recover":
		attack_cd -= delta
		if attack_cd <= 0.0:
			ai_state = "chase"
		return

	attack_cd -= delta
	shoot_cd -= delta
	var distance := absf(dx)
	var desired := 310.0
	var move := 0.0
	if distance < desired - 70.0:
		move = -1.0
	elif distance > desired + 90.0:
		move = 1.0
	if move != 0.0:
		position.x += signf(dx) * move * speed * delta
		speed_actual = speed
	position.y = move_toward(position.y, target.position.y, speed * 0.55 * delta)
	if absf(dy) < 34.0 and distance < 560.0 and shoot_cd <= 0.0:
		ai_state = "windup"
		windup = windup_max
		shoot_cd = randf_range(1.6, 2.6)
		Sfx.play("aim", global_position, -5.0, randf_range(0.95, 1.10))


func _fire() -> void:
	if target == null or target.dead or level_ref == null:
		return
	var origin := global_position + Vector2(0, -72)
	var aim: Vector2 = (target.global_position + Vector2(0, -55) - origin).normalized()
	level_ref.spawn_projectile(origin, aim, damage * 0.85, tint)
	Fx.spark(global_position + Vector2(float(facing) * 22, -72), tint, 5, 0.6)
	Sfx.play("gunshot", global_position, 1.0, randf_range(0.94, 1.06))


func _ai_drone(dx: float, dy: float, flat: Vector2, delta: float) -> void:
	if ai_state == "windup":
		windup -= delta
		# dive toward the target during the windup
		var dive := Vector2(signf(dx), clampf(dy / 40.0, -1.0, 1.0)).normalized()
		position += dive * speed * 1.6 * delta
		speed_actual = speed * 1.6
		if windup <= 0.0:
			_strike_melee()
			ai_state = "recover"
			attack_cd = randf_range(0.9, 1.5)
			knock_vel += Vector2(-signf(dx) * 180.0, 0.0)
		return
	if ai_state == "recover":
		attack_cd -= delta
		if attack_cd <= 0.0:
			ai_state = "chase"
		return

	attack_cd -= delta
	var dist := Vector2(dx, dy * 1.3).length()
	if dist > 95.0:
		var dir := Vector2(signf(dx), clampf(dy / 50.0, -1.0, 1.0) * 0.7).normalized()
		position += dir * speed * delta
		speed_actual = speed
	elif attack_cd <= 0.0:
		ai_state = "windup"
		windup = windup_max


func take_damage(amount: float, from_pos: Vector2, knock: float, crit: bool) -> bool:
	var reduced := amount * (1.0 - armor)
	var hit := super.take_damage(reduced, from_pos, knock, crit)
	if hit and not dead:
		var stagger_resist := 0.0
		if kind == Kind.BRUISER:
			stagger_resist = 0.65
		if elite:
			stagger_resist += 0.2
		if randf() > stagger_resist:
			stagger = 0.18
			if ai_state == "windup":
				ai_state = "chase"
				windup = 0.0
				attack_cd = maxf(attack_cd, 0.25)
		if randf() < 0.25:
			Fx.hitstop(0.02)
	return hit


func _die() -> void:
	super._die()
	death_reported = false
	Sfx.play("die_enemy", global_position, 0.0,
		1.20 if kind == Kind.DRONE else randf_range(0.92, 1.08))
	if kind == Kind.DRONE:
		Fx.spark(global_position + Vector2(0, -70), Color(1.0, 0.5, 0.15), 18, 1.6)
		Fx.shake(4.0, 0.25)
		Fx.flash(Color(1.0, 0.4, 0.1, 0.06))


func get_kind_name() -> String:
	match kind:
		Kind.GUNNER:
			return "GUNNER"
		Kind.BRUISER:
			return "BRUISER"
		Kind.DRONE:
			return "DRONE"
		_:
			return "THUG"


func _draw() -> void:
	var dim := 1.0
	if dead:
		dim = 0.7
	draw_shadow(30.0 * body_scale, 0.38)
	draw_circle(Vector2(0, -62.0 * body_scale), 46.0 * body_scale, Color(tint, 0.085))
	if elite:
		var pulse := 1.0 + sin(anim_t * 3.0) * 0.1
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.3))
		draw_arc(Vector2.ZERO, 44.0 * pulse, 0.0, TAU, 36, Color(tint, 0.5), 3.0, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	match kind:
		Kind.GUNNER:
			_draw_gunner(dim)
		Kind.BRUISER:
			_draw_bruiser(dim)
		Kind.DRONE:
			_draw_drone(dim)
		_:
			_draw_thug(dim)

	draw_health_bar(-126.0 * body_scale, 54.0 * body_scale)
	if hurt_flash > 0.0:
		var fa := clampf(hurt_flash / 0.13, 0.0, 1.0) * 0.5
		draw_circle(Vector2(0, -62.0 * body_scale), 34.0 * body_scale, Color(1.0, 1.0, 1.0, fa))

	if ai_state == "windup" and kind != Kind.GUNNER:
		var p := 1.0 - clampf(windup / maxf(windup_max, 0.001), 0.0, 1.0)
		var c := Color(1.0, 0.3, 0.2, 0.16 + p * 0.2)
		draw_arc(Vector2(0, -60), 34.0 + p * 10.0, -1.1, 1.1, 16, c, 4.0, true)
		if p > 0.55:
			draw_set_transform(Vector2(0, -150), 0.0, Vector2(1.0, 1.0))
			draw_string(ThemeDB.fallback_font, Vector2(-20, 0), "!", HORIZONTAL_ALIGNMENT_CENTER, 40, 22, Color(1.0, 0.3, 0.2, 0.9))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if ai_state == "windup" and kind == Kind.GUNNER:
		var alpha := 0.25 + 0.25 * (1.0 - windup / maxf(windup_max, 0.001))
		draw_line(Vector2(26, -74), Vector2(560, -74), Color(tint, alpha), 2.0, true)
		draw_line(Vector2(26, -74), Vector2(560, -74), Color(1.0, 0.2, 0.2, alpha * 0.6), 5.0, true)


func _draw_thug(_dim: float) -> void:
	var t := anim_t
	var walk := sin(t * 9.0) * clampf(speed_actual / 120.0, 0.0, 1.0) * 8.0
	var skin := Color(0.62, 0.45, 0.34)
	var cloth := Color(0.16, 0.17, 0.25)
	var cloth_hi := Color(0.24, 0.26, 0.36)
	var pants := Color(0.10, 0.11, 0.17)
	var metal := Color(0.48, 0.52, 0.60)

	limb3(Vector2(-4, -52), Vector2(-7 - walk * 0.5, -27), Vector2(-10 - walk, -1), 11.0, pants)
	limb3(Vector2(4, -52), Vector2(7 + walk * 0.5, -27), Vector2(11 + walk, -1), 12.0, pants)
	# torso hoodie
	var torso := PackedVector2Array([
		Vector2(-20, -88), Vector2(20, -88), Vector2(23, -64),
		Vector2(15, -50), Vector2(-15, -50), Vector2(-23, -64),
	])
	draw_colored_polygon(torso, cloth)
	draw_polyline(PackedVector2Array([Vector2(-20, -88), Vector2(20, -88), Vector2(23, -64), Vector2(15, -50), Vector2(-15, -50), Vector2(-23, -64), Vector2(-20, -88)]), Color(tint, 0.35), 1.5, true)
	draw_line(Vector2(-23, -64), Vector2(-20, -88), Color(tint, 0.65), 2.0, true)
	draw_line(Vector2(20, -88), Vector2(23, -64), Color(tint, 0.6), 2.0, true)
	draw_rect(Rect2(-15, -66, 30, 4), cloth_hi)
	# hood
	draw_circle(Vector2(1, -96), 14.0, cloth_hi)
	draw_circle(Vector2(2, -95), 11.0, Color(0.03, 0.03, 0.05))
	# face + mask
	draw_circle(Vector2(4, -94), 8.5, skin)
	draw_line(Vector2(-2, -96), Vector2(11, -96), tint, 3.0, true)
	draw_circle(Vector2(8, -95), 1.5, Color(1.0, 1.0, 1.0, 0.8))
	# arms
	var fist_a := Vector2(-24 - walk * 0.6, -58)
	var fist_b := Vector2(25 + walk * 0.4, -56)
	limb3(Vector2(-17, -83), Vector2(-25, -70), fist_a, 9.0, cloth)
	limb3(Vector2(17, -83), Vector2(26, -68), fist_b, 9.0, skin)
	draw_circle(fist_a, 4.5, skin)
	# pipe
	var wind := 0.0
	if ai_state == "windup":
		wind = 1.0 - clampf(windup / maxf(windup_max, 0.001), 0.0, 1.0)
	var pipe_start := fist_b
	var angle := lerpf(0.15, -1.25, wind)
	var pipe_end := pipe_start + Vector2(cos(angle), sin(angle)) * 38.0
	draw_line(pipe_start, pipe_end, Color(0.15, 0.16, 0.2), 6.0, true)
	draw_line(pipe_start, pipe_end, metal, 3.0, true)
	draw_circle(pipe_end, 4.0, Color(tint, 0.8))
	if ai_state == "windup":
		draw_circle(pipe_end, 6.0 + wind * 4.0, Color(1.0, 0.2, 0.2, 0.25))


func _draw_bruiser(_dim: float) -> void:
	var t := anim_t
	var walk := sin(t * 7.0) * clampf(speed_actual / 100.0, 0.0, 1.0) * 7.0
	var skin := Color(0.55, 0.42, 0.38)
	var metal := Color(0.42, 0.47, 0.55)
	var metal_hi := Color(0.65, 0.72, 0.80)
	var pants := Color(0.11, 0.11, 0.17)

	limb3(Vector2(-6, -50), Vector2(-10 - walk * 0.4, -26), Vector2(-14 - walk, -1), 14.0, pants)
	limb3(Vector2(6, -50), Vector2(10 + walk * 0.4, -26), Vector2(15 + walk, -1), 15.0, pants)
	# massive torso
	var torso := PackedVector2Array([
		Vector2(-30, -94), Vector2(30, -94), Vector2(34, -70),
		Vector2(20, -48), Vector2(-20, -48), Vector2(-34, -70),
	])
	draw_colored_polygon(torso, Color(0.19, 0.20, 0.28))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-15, -88), Vector2(15, -88), Vector2(11, -55), Vector2(-11, -55),
	]), skin)
	# cyber shoulder plates
	draw_circle(Vector2(-27, -86), 12.0, metal)
	draw_circle(Vector2(28, -86), 12.0, metal)
	draw_circle(Vector2(-27, -86), 7.0, metal_hi)
	draw_circle(Vector2(28, -86), 7.0, metal_hi)
	draw_line(Vector2(-30, -70), Vector2(-22, -52), Color(tint, 0.5), 2.0, true)
	draw_line(Vector2(30, -70), Vector2(22, -52), Color(tint, 0.5), 2.0, true)
	# head, tiny for the body
	draw_circle(Vector2(2, -105), 10.0, skin)
	draw_rect(Rect2(-6, -103, 17, 5), metal)
	draw_line(Vector2(-5, -101), Vector2(9, -101), Color(tint, 0.9), 2.0, true)
	draw_rect(Rect2(-2, -94, 9, 4), metal_hi)
	# arms
	var wind := 0.0
	if ai_state == "windup":
		wind = 1.0 - clampf(windup / maxf(windup_max, 0.001), 0.0, 1.0)
	var fist := Vector2(38 + wind * 16, -45 - wind * 26)
	var elbow := Vector2(38, -66 - wind * 8)
	limb3(Vector2(26, -84), elbow, fist, 16.0, metal)
	limb3(Vector2(-26, -84), Vector2(-38, -62), Vector2(-40, -44), 15.0, skin)
	draw_circle(fist, 10.0, metal_hi)
	draw_circle(Vector2(-40, -44), 9.0, skin)
	if ai_state == "windup":
		draw_circle(fist, 14.0 + wind * 6.0, Color(1.0, 0.25, 0.15, 0.22))


func _draw_gunner(_dim: float) -> void:
	var t := anim_t
	var walk := sin(t * 9.0) * clampf(speed_actual / 100.0, 0.0, 1.0) * 6.0
	var skin := Color(0.66, 0.48, 0.36)
	var coat := Color(0.15, 0.17, 0.25)
	var coat_hi := Color(0.24, 0.28, 0.40)
	var gun := Color(0.25, 0.28, 0.35)
	var gun_hi := Color(0.55, 0.62, 0.72)

	limb3(Vector2(-4, -52), Vector2(-7 - walk * 0.5, -27), Vector2(-9 - walk, -1), 10.0, Color(0.08, 0.08, 0.12))
	limb3(Vector2(4, -52), Vector2(7 + walk * 0.5, -27), Vector2(10 + walk, -1), 11.0, Color(0.08, 0.08, 0.12))
	var torso := PackedVector2Array([
		Vector2(-17, -92), Vector2(17, -92), Vector2(20, -68),
		Vector2(13, -50), Vector2(-13, -50), Vector2(-20, -68),
	])
	draw_colored_polygon(torso, coat)
	draw_polyline(PackedVector2Array([Vector2(-17, -92), Vector2(17, -92), Vector2(20, -68), Vector2(13, -50), Vector2(-13, -50), Vector2(-20, -68), Vector2(-17, -92)]), Color(tint, 0.35), 1.5, true)
	draw_line(Vector2(-17, -92), Vector2(-13, -50), Color(tint, 0.6), 2.0, true)
	draw_line(Vector2(17, -92), Vector2(13, -50), Color(tint, 0.5), 2.0, true)
	draw_rect(Rect2(-13, -62, 26, 3), coat_hi)
	# head with visor helmet
	draw_circle(Vector2(2, -104), 10.0, skin)
	draw_rect(Rect2(-8, -108, 20, 7), Color(0.05, 0.06, 0.10))
	draw_line(Vector2(-7, -105), Vector2(11, -105), Color(tint, 0.9), 2.5, true)
	draw_circle(Vector2(-8, -100), 2.5, tint)
	# arms + rifle
	limb3(Vector2(15, -86), Vector2(20, -74), Vector2(26, -72), 8.0, coat)
	limb3(Vector2(-15, -86), Vector2(-10, -76), Vector2(20, -72), 8.0, coat)
	var rifle_y := -74.0
	draw_line(Vector2(14, rifle_y), Vector2(52, rifle_y), gun, 7.0, true)
	draw_line(Vector2(18, rifle_y - 4), Vector2(40, rifle_y - 4), gun_hi, 3.0, true)
	draw_line(Vector2(30, rifle_y + 3), Vector2(34, rifle_y + 9), gun, 4.0, true)
	draw_rect(Rect2(16, rifle_y - 8, 10, 5), gun_hi)
	draw_circle(Vector2(52, rifle_y), 3.0, Color(tint, 0.9))
	if ai_state == "windup":
		var p := 1.0 - clampf(windup / maxf(windup_max, 0.001), 0.0, 1.0)
		draw_circle(Vector2(52, rifle_y), 4.0 + p * 5.0, Color(1.0, 0.25, 0.15, 0.3 + p * 0.3))


func _draw_drone(_dim: float) -> void:
	var hover := sin(hover_t) * 7.0
	var c := tint
	var body := Color(0.20, 0.23, 0.30)
	var metal := Color(0.55, 0.62, 0.72)
	var center := Vector2(0, -78 + hover)

	# rotors
	var spin := sin(anim_t * 30.0) * 10.0
	draw_line(center + Vector2(-34, -18), center + Vector2(-6, -12), Color(0.3, 0.33, 0.4), 4.0, true)
	draw_line(center + Vector2(34, -18), center + Vector2(6, -12), Color(0.3, 0.33, 0.4), 4.0, true)
	draw_line(center + Vector2(-34 - spin, -22), center + Vector2(-34 + spin, -14), Color(metal, 0.7), 2.0, true)
	draw_line(center + Vector2(34 - spin, -22), center + Vector2(34 + spin, -14), Color(metal, 0.7), 2.0, true)
	# chassis
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-24, -10), center + Vector2(-14, -24), center + Vector2(14, -24),
		center + Vector2(24, -10), center + Vector2(16, 10), center + Vector2(-16, 10),
	]), body)
	draw_line(center + Vector2(-22, -8), center + Vector2(22, -8), Color(c, 0.6), 2.0, true)
	draw_circle(center + Vector2(6, -4), 8.0, Color(0.04, 0.05, 0.07))
	var eye := 3.2 + sin(anim_t * 6.0) * 0.6
	draw_circle(center + Vector2(6, -4), eye + 2.5, Color(c, 0.28))
	draw_circle(center + Vector2(6, -4), eye, Color(1.0, 0.45, 0.35))
	# thrusters
	var glow := Color(c, 0.5)
	draw_line(center + Vector2(-12, 10), center + Vector2(-14, 22), glow, 4.0, true)
	draw_line(center + Vector2(12, 10), center + Vector2(14, 22), glow, 4.0, true)
	if ai_state == "windup":
		var p := 1.0 - clampf(windup / maxf(windup_max, 0.001), 0.0, 1.0)
		draw_circle(center + Vector2(6, -4), 12.0 + p * 10.0, Color(1.0, 0.3, 0.2, 0.22 + p * 0.2))


class DistrictColors:
	static func color_for(district: int) -> Color:
		var palettes := [
			Color(1.0, 0.22, 0.55),
			Color(0.25, 1.0, 0.72),
			Color(0.4, 0.7, 1.0),
			Color(1.0, 0.55, 0.15),
			Color(0.85, 0.35, 1.0),
		]
		if district <= 0:
			return Color(0, 0, 0, 0)
		# deterministic per district, with a little variation
		return palettes[(district - 1) % palettes.size()]
