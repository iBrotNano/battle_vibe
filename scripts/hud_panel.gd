class_name HudPanel
extends Control

var fill_color := Color(0.025, 0.030, 0.050, 0.82)
var border_color := Color(0.20, 0.90, 1.0, 0.30)
var accent_color := Color(0.20, 0.90, 1.0, 0.8)
var corner := 14.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, fill_color)
	draw_rect(r, border_color, false, 1.0)
	# corner brackets
	var c := accent_color
	var s := corner
	draw_line(Vector2(0, s), Vector2(0, 0), c, 2.0)
	draw_line(Vector2(0, 0), Vector2(s, 0), c, 2.0)
	draw_line(Vector2(size.x - s, 0), Vector2(size.x, 0), c, 2.0)
	draw_line(Vector2(size.x, 0), Vector2(size.x, s), c, 2.0)
	draw_line(Vector2(0, size.y - s), Vector2(0, size.y), Color(c, 0.5), 1.5)
	draw_line(Vector2(0, size.y), Vector2(s, size.y), Color(c, 0.5), 1.5)
	draw_line(Vector2(size.x - s, size.y), Vector2(size.x, size.y), Color(c, 0.5), 1.5)
	draw_line(Vector2(size.x, size.y - s), Vector2(size.x, size.y), Color(c, 0.5), 1.5)
	draw_line(Vector2(0, 0), Vector2(size.x, 0), Color(c, 0.10), 4.0)
