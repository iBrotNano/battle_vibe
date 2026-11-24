class_name DamageNumber
extends Node2D

var text := "0"
var color := Color.WHITE
var life := 0.75
var max_life := 0.75
var vel := Vector2(0, -95)
var boost := 1.0


func boot(pos: Vector2, amount: float, crit: bool) -> void:
	position = pos + Vector2(randf_range(-14.0, 14.0), 0)
	text = str(int(round(amount)))
	if crit:
		text += "!"
		color = Color(1.0, 0.82, 0.22)
		boost = 1.4
		life = 1.0
		max_life = 1.0
	else:
		color = Color(0.92, 0.96, 1.0)
	z_as_relative = false
	z_index = 3500


func _process(delta: float) -> void:
	life -= delta
	position += vel * delta
	vel *= 0.93
	if life <= 0.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var alpha := clampf(life / max_life * 1.6, 0.0, 1.0)
	var c := color
	c.a = alpha
	var font := ThemeDB.fallback_font
	var size := int(19 * boost)
	draw_string(font, Vector2(-80, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 160, size, c)
