class_name Rain
extends Control

var drops: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for i in 150:
		drops.append({
			"x": randf_range(-100.0, 1380.0),
			"y": randf_range(-40.0, 760.0),
			"len": randf_range(8.0, 26.0),
			"speed": randf_range(420.0, 900.0),
			"alpha": randf_range(0.05, 0.22),
		})


func _process(delta: float) -> void:
	var h := maxf(720.0, size.y)
	var w := maxf(1280.0, size.x)
	for d in drops:
		d.y += d.speed * delta
		d.x -= d.speed * 0.16 * delta
		if d.y > h + 30.0 or d.x < -80.0:
			d.y = randf_range(-120.0, -20.0)
			d.x = randf_range(-80.0, w)
	queue_redraw()


func _draw() -> void:
	for d in drops:
		var c := Color(0.55, 0.75, 1.0, d.alpha)
		draw_line(Vector2(d.x, d.y), Vector2(d.x - d.len * 0.16, d.y - d.len), c, 1.2, true)
