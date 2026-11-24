extends Node
## Screen feel and world-space feedback (hitstop, shake, damage numbers, sparks).

var world: Node2D
var camera: Camera2D
var hud: CanvasLayer

var _shake_amount := 0.0
var _shake_time := 0.0
var _shake_total := 0.0
var _hitstop_until_ms := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func setup(world_node: Node2D, cam: Camera2D, hud_node: CanvasLayer) -> void:
	world = world_node
	camera = cam
	hud = hud_node


func _process(delta: float) -> void:
	if Time.get_ticks_msec() < _hitstop_until_ms:
		Engine.time_scale = 0.07
	elif not is_equal_approx(Engine.time_scale, 1.0):
		Engine.time_scale = 1.0

	if camera == null:
		return
	if _shake_time > 0.0:
		_shake_time -= delta
		var falloff := clampf(_shake_time / maxf(_shake_total, 0.001), 0.0, 1.0)
		var mag := _shake_amount * falloff
		camera.offset = Vector2(randf_range(-mag, mag), randf_range(-mag, mag))
		_shake_amount = maxf(0.0, _shake_amount - delta * 60.0)
	else:
		camera.offset = camera.offset.lerp(Vector2.ZERO, 0.35)


func shake(amount: float, duration: float = 0.25) -> void:
	_shake_amount = maxf(_shake_amount, amount)
	_shake_time = maxf(_shake_time, duration)
	_shake_total = maxf(_shake_total, duration)


func hitstop(duration: float) -> void:
	_hitstop_until_ms = maxi(_hitstop_until_ms, Time.get_ticks_msec() + int(duration * 1000.0))


func flash(color: Color) -> void:
	if hud and hud.has_method("flash_screen"):
		hud.flash_screen(color)


func damage_number(pos: Vector2, amount: float, crit: bool) -> void:
	if world == null:
		return
	var n := DamageNumber.new()
	world.add_child(n)
	n.boot(pos, amount, crit)


func spark(pos: Vector2, color: Color, count: int = 8, power: float = 1.0) -> void:
	if world == null:
		return
	var s := Spark.new()
	world.add_child(s)
	s.boot(pos, color, count, power)


func shockwave(pos: Vector2, color: Color = Color(0.2, 0.95, 1.0)) -> void:
	if world == null:
		return
	var w := Shockwave.new()
	world.add_child(w)
	w.boot(pos, color)


func portal(pos: Vector2, color: Color = Color(1.0, 0.25, 0.6)) -> void:
	if world == null:
		return
	var w := Shockwave.new()
	world.add_child(w)
	w.boot(pos + Vector2(0, -40), color, 0.55, 42.0)
