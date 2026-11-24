class_name Spark
extends Node2D

var parts: Array = []
var color := Color.WHITE


func boot(pos: Vector2, spark_color: Color, count: int = 8, power: float = 1.0) -> void:
	position = pos
	color = spark_color
	for i in count:
		var angle := randf() * TAU
		var speed := randf_range(90.0, 300.0) * power
		parts.append({
			"p": Vector2.ZERO,
			"v": Vector2(cos(angle), sin(angle)) * speed,
			"life": randf_range(0.10, 0.32),
			"max": 0.32,
		})
	z_as_relative = false
	z_index = 3400


func _process(delta: float) -> void:
	var alive := false
	for part in parts:
		part.life -= delta
		if part.life > 0.0:
			part.p += part.v * delta
			part.v = part.v.move_toward(Vector2.ZERO, 700.0 * delta)
			alive = true
	if not alive:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	for part in parts:
		if part.life > 0.0:
			var c := color
			c.a = clampf(part.life / part.max * 1.4, 0.0, 1.0)
			draw_line(part.p, part.p - part.v * 0.035, c, 3.0, true)
			draw_circle(part.p, 2.0, c)
