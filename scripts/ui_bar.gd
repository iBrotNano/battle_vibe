class_name UIBar
extends Control

var value := 1.0
var fill_color := Color(1.0, 0.25, 0.4)
var back_color := Color(0.02, 0.02, 0.04, 0.85)
var border_color := Color(0.3, 0.36, 0.5, 0.55)
var glow_color := Color(0.0, 0.0, 0.0, 0.0)
var show_ticks := true
var tick_count := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_value(v: float) -> void:
	var nv := clampf(v, 0.0, 1.0)
	if not is_equal_approx(nv, value):
		value = nv
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(0, 0, w, h), back_color)
	if value > 0.0:
		var fill := Rect2(1, 1, maxf(0.0, (w - 2) * value), h - 2)
		draw_rect(fill, fill_color)
		draw_rect(Rect2(1, 1, fill.size.x, maxf(1.0, h * 0.35)), fill_color.lightened(0.22))
		if glow_color.a > 0.0:
			draw_rect(Rect2(0, 0, fill.size.x + 2, h), Color(glow_color, 0.10))
		draw_rect(Rect2(fill.size.x, 0, 1, h), Color(1, 1, 1, 0.45))
	if show_ticks and tick_count > 0:
		for i in range(1, tick_count):
			var x := w * float(i) / float(tick_count)
			draw_line(Vector2(x, 1), Vector2(x, h - 1), Color(0, 0, 0, 0.28), 1.0)
	draw_rect(Rect2(0, 0, w, h), border_color, false, 1.0)
