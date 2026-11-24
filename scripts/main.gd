extends Node2D
## Boots the game: world, camera, procedural districts, HUD, atmosphere and run flow.

var world: Node2D
var camera: Camera2D
var hud: HUD
var level: Level
var state := "title"
var district_timer := 0.0
var pending_district := 0
var rain_layer: CanvasLayer
var vignette_layer: CanvasLayer
var title_level: Level


func _ready() -> void:
	world = Node2D.new()
	world.name = "World"
	add_child(world)

	camera = Camera2D.new()
	camera.name = "Camera"
	camera.position = Vector2(640, 150)
	camera.enabled = true
	camera.position_smoothing_enabled = false
	add_child(camera)
	camera.make_current()

	hud = HUD.new()
	add_child(hud)
	hud.start_requested.connect(_on_start_requested)
	hud.restart_requested.connect(_on_restart_requested)

	Fx.setup(world, camera, hud)
	_add_atmosphere()

	_build_level()
	state = "title"
	hud.show_title()
	hud.bind(level.player, level)
	level.player.control_enabled = false


func _add_atmosphere() -> void:
	rain_layer = CanvasLayer.new()
	rain_layer.layer = 5
	add_child(rain_layer)
	var rain := Rain.new()
	rain_layer.add_child(rain)

	vignette_layer = CanvasLayer.new()
	vignette_layer.layer = 6
	add_child(vignette_layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float vignette_strength : hint_range(0.0, 2.0) = 0.95;
uniform float scan_strength : hint_range(0.0, 0.5) = 0.05;
void fragment() {
	vec2 uv = SCREEN_UV;
	float d = distance(uv, vec2(0.5, 0.46));
	float v = smoothstep(0.34, 0.98, d) * vignette_strength;
	float scan = (sin(uv.y * 820.0) * 0.5 + 0.5) * scan_strength;
	float a = clamp(v + scan, 0.0, 0.9);
	vec3 col = mix(vec3(0.0), vec3(0.05, 0.0, 0.09), clamp(v * 1.6, 0.0, 1.0));
	COLOR = vec4(col, a);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	rect.material = mat
	vignette_layer.add_child(rect)


func _build_level() -> void:
	if level != null:
		if is_instance_valid(level):
			world.remove_child(level)
			level.queue_free()
		level = null
	level = Level.new()
	world.add_child(level)
	level.district_cleared.connect(_on_district_cleared)
	level.player_died.connect(_on_player_died)
	level.announce.connect(_on_announce)
	var seed_value := Game.run_seed + Game.district * 7919
	level.build(Game.district, seed_value, camera)
	if hud != null:
		hud.bind(level.player, level)
	camera.position = Vector2(maxf(640.0, level.player.position.x), 150.0)


func _on_start_requested() -> void:
	if state != "title":
		return
	Game.reset_run()
	Game.district = 1
	Game.run_seed = int(Time.get_unix_time_from_system()) + randi() % 99991
	_build_level()
	state = "playing"
	hud.show_playing()
	level.player.control_enabled = true
	Sfx.play_ui("ui_start", 0.0)
	Game.notify("SIGNAL ACQUIRED // WELCOME TO THE SPRAWL", Color(0.25, 0.95, 1.0))
	Game.notify("MOVE RIGHT. CLEAR THE SECTORS. TAKE THEIR CHROME.", Color(0.8, 0.85, 0.95))


func _on_restart_requested() -> void:
	if state != "dead":
		return
	Game.lose_xp_percent(0.25)
	rebuild_district()
	state = "playing"
	hud.show_playing()
	level.player.control_enabled = true
	hud.banner("REBOOT", "SIGNAL RESTORED // 25% XP BURNED", Color(0.25, 0.95, 1.0))
	Sfx.play_ui("ui_start", -1.0)


func rebuild_district() -> void:
	_build_level()
	level.player.control_enabled = true


func _on_player_died() -> void:
	if state != "playing":
		return
	state = "dead"
	hud.show_death()


func _on_district_cleared() -> void:
	if state != "playing":
		return
	state = "cleared"
	district_timer = 2.6
	level.player.control_enabled = false


func _on_announce(title: String, subtitle: String, color: Color) -> void:
	hud.banner(title, subtitle, color)


func _advance_district() -> void:
	Game.district += 1
	Game.district_changed.emit(Game.district)
	_build_level()
	state = "playing"
	hud.show_playing()
	level.player.control_enabled = true
	Game.notify("NEW DISTRICT // THREAT LEVEL RISING", Color(1.0, 0.35, 0.6))


func _process(delta: float) -> void:
	if state == "cleared":
		district_timer -= delta
		if district_timer <= 0.0:
			_advance_district()
	_update_camera(delta)


func _update_camera(delta: float) -> void:
	if level == null or not is_instance_valid(level):
		return
	var target_x: float = level.camera_target_x()
	var upper := maxf(640.0, level.total_width - 180.0)
	target_x = clampf(target_x, 640.0, upper)
	var target := Vector2(target_x, 150.0)
	var speed := 6.0 if state == "playing" else 2.2
	camera.position = camera.position.lerp(target, 1.0 - exp(-speed * delta))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return
		if key.keycode == KEY_ESCAPE:
			get_tree().quit()
		elif key.keycode == KEY_F11:
			var fs := Settings.toggle_fullscreen()
			get_viewport().set_input_as_handled()
			Sfx.play_ui("ui_click", -4.0)
			if state != "title":
				hud.banner("FULLSCREEN %s" % ("ON" if fs else "OFF"), Settings.current_description(), Color(0.2, 0.95, 1.0))
		elif key.keycode == KEY_F10:
			Settings.cycle_resolution()
			get_viewport().set_input_as_handled()
			Sfx.play_ui("ui_click", -4.0)
			if state != "title":
				hud.banner("WINDOW SIZE", Settings.current_description(), Color(1.0, 0.76, 0.22))
		elif key.keycode == KEY_M:
			var muted := Sfx.toggle_mute()
			hud.banner("AUDIO %s" % ("MUTED" if muted else "ON"),
				"PRESS M TO TOGGLE SOUND", Color(0.2, 0.95, 1.0))
			if not muted:
				Sfx.play_ui("ui_click", -4.0)
