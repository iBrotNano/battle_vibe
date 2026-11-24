class_name Projectile
extends Node2D

var vel := Vector2.ZERO
var damage := 10.0
var target
var color := Color(1.0, 0.4, 0.1)
var life := 3.0
var radius := 7.0


func boot(from: Vector2, dir: Vector2, dmg: float, tint: Color) -> void:
	position = from
	vel = dir.normalized() * 760.0
	damage = dmg
	color = tint
	z_as_relative = false
	z_index = 2400


func _process(delta: float) -> void:
	position += vel * delta
	life -= delta
	if target != null and is_instance_valid(target) and not target.dead:
		if absf(position.x - target.position.x) < 24.0 \
				and absf(position.y - (target.position.y - 55.0)) < 42.0:
			if target.take_damage(damage, position - vel.normalized() * 40.0, 300.0, false):
				Fx.spark(position, color, 8, 0.9)
				queue_free()
				return
	if life <= 0.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var dir := vel.normalized()
	var tail := color
	tail.a = 0.22
	draw_line(-dir * 34.0, Vector2.ZERO, tail, 8.0, true)
	draw_line(-dir * 18.0, Vector2.ZERO, color, 3.0, true)
	draw_circle(Vector2.ZERO, 5.0, Color(1.0, 0.95, 0.9))
	draw_circle(Vector2.ZERO, 10.0, Color(color, 0.18))
