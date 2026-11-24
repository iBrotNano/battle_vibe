class_name Shockwave
extends Node2D

var radius := 0.0
var max_radius := 190.0
var life := 0.45
var max_life := 0.45
var color := Color(0.2, 0.95, 1.0)
var line_width := 7.0


func boot(pos: Vector2, spark_color: Color, duration: float = 0.45, size: float = 190.0) -> void:
	position = pos
	color = spark_color
	max_life = duration
	life = duration
	max_radius = size
	z_as_relative = false
	z_index = 3200


func _process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := 1.0 - clampf(life / max_life, 0.0, 1.0)
	radius = max_radius * ease(t, 0.25)
	var alpha := (1.0 - t) * 0.85
	var c := color
	c.a = alpha
	# Ground-plane ring (squashed ellipse).
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.34))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, c, line_width, true)
	var inner := color
	inner.a = alpha * 0.35
	draw_arc(Vector2.ZERO, radius * 0.82, 0.0, TAU, 40, inner, line_width * 2.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
