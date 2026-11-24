class_name Actor
extends Node2D
## Shared ground-plane actor: depth-sorted feet position, knockback, damage flash, death.

var max_hp := 100.0
var hp := 100.0
var radius := 18.0
var facing := 1
var dead := false
var invuln := 0.0
var hurt_flash := 0.0
var knock_vel := Vector2.ZERO
var anim_t := 0.0
var body_scale := 1.0
var depth_min := 55.0
var depth_max := 330.0
var death_t := 0.0
var spark_color := Color(1.0, 0.25, 0.5)
var speed_actual := 0.0


func _ready() -> void:
	anim_t = randf() * 10.0
	z_as_relative = false


func base_update(delta: float) -> void:
	anim_t += delta
	if invuln > 0.0:
		invuln -= delta
	if hurt_flash > 0.0:
		hurt_flash -= delta

	if dead:
		death_t = minf(1.0, death_t + delta * 1.8)
		modulate.a = 1.0 - death_t
		rotation = death_t * 1.35 * (-facing)
		if death_t >= 1.0:
			queue_free()
		return

	position += knock_vel * delta
	knock_vel = knock_vel.move_toward(Vector2.ZERO, 1600.0 * delta)
	position.y = clampf(position.y, depth_min, depth_max)
	z_index = int(position.y) + 20
	scale = Vector2(float(facing) * body_scale, body_scale)


func take_damage(amount: float, from_pos: Vector2, knock: float, crit: bool) -> bool:
	if dead or invuln > 0.0:
		return false
	hp -= amount
	hurt_flash = 0.13
	invuln = 0.06
	var dir := signf(position.x - from_pos.x)
	if is_zero_approx(dir):
		dir = 1.0
	knock_vel += Vector2(dir * knock, 0.0)
	Fx.damage_number(global_position + Vector2(0.0, -105.0 * body_scale), amount, crit)
	Fx.spark(global_position + Vector2(0.0, -62.0 * body_scale), spark_color, 7)
	if hp <= 0.0:
		hp = 0.0
		_die()
	return true


func _die() -> void:
	dead = true
	death_t = 0.0
	invuln = 999.0
	Fx.spark(global_position + Vector2(0.0, -55.0 * body_scale), spark_color, 14, 1.4)


func heal(amount: float) -> void:
	if dead:
		return
	hp = minf(max_hp, hp + amount)


func draw_shadow(width: float = 30.0, alpha: float = 0.42) -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.30))
	draw_circle(Vector2.ZERO, width, Color(0.0, 0.0, 0.0, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func draw_health_bar(y: float, width: float, height: float = 4.0) -> void:
	if hp >= max_hp or dead:
		return
	var t := clampf(hp / max_hp, 0.0, 1.0)
	var back := Rect2(-width * 0.5 - 1.0, y - 1.0, width + 2.0, height + 2.0)
	draw_rect(back, Color(0.02, 0.02, 0.04, 0.82))
	var fill := Color(1.0, 0.22, 0.38)
	if t < 0.3:
		fill = Color(1.0, 0.55, 0.15)
	draw_rect(Rect2(-width * 0.5, y, width * t, height), fill)


func limb(a: Vector2, b: Vector2, width: float, color: Color) -> void:
	draw_line(a, b, color, width, true)
	draw_circle(a, width * 0.5, color)
	draw_circle(b, width * 0.5, color)


func limb3(a: Vector2, b: Vector2, c: Vector2, width: float, color: Color) -> void:
	draw_line(a, b, color, width, true)
	draw_line(b, c, color, width, true)
	draw_circle(a, width * 0.5, color)
	draw_circle(b, width * 0.5, color)
	draw_circle(c, width * 0.5, color)
