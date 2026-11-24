extends Node
## Persistent display settings: fullscreen, windowed resolution and centring.
## Defaults to fullscreen on first launch; saved to user://neon_carnage.cfg.

signal changed

const CONFIG_PATH := "user://neon_carnage.cfg"
const BASE_RESOLUTIONS := [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

var fullscreen := true
var resolution_index := 0
var resolutions: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_resolution_list()
	_load()
	call_deferred("_apply")


func _build_resolution_list() -> void:
	resolutions.clear()
	var screen := DisplayServer.window_get_current_screen()
	var native := DisplayServer.screen_get_size(screen)
	for res in BASE_RESOLUTIONS:
		if res.x <= native.x and res.y <= native.y:
			resolutions.append(res)
	if resolutions.is_empty():
		resolutions.append(Vector2i(1280, 720))
	if native.x > 0 and native.y > 0 and not resolutions.has(native):
		resolutions.append(native)
	resolution_index = clampi(resolution_index, 0, resolutions.size() - 1)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	fullscreen = bool(cfg.get_value("display", "fullscreen", true))
	resolution_index = int(cfg.get_value("display", "resolution_index", 0))
	resolution_index = clampi(resolution_index, 0, maxi(resolutions.size() - 1, 0))


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "resolution_index", resolution_index)
	cfg.save(CONFIG_PATH)


func _apply() -> void:
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var res: Vector2i = resolutions[clampi(resolution_index, 0, resolutions.size() - 1)]
	DisplayServer.window_set_size(res)
	_center(res)


func _center(res: Vector2i) -> void:
	var screen := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	DisplayServer.window_set_position(usable.position + (usable.size - res) / 2)


func toggle_fullscreen() -> bool:
	fullscreen = not _is_fullscreen()
	if not fullscreen and not resolutions.is_empty():
		# Restore the saved windowed size when leaving fullscreen.
		resolution_index = clampi(resolution_index, 0, resolutions.size() - 1)
	_apply()
	_save()
	changed.emit()
	return fullscreen


func cycle_resolution() -> Vector2i:
	fullscreen = false
	resolution_index = (resolution_index + 1) % resolutions.size()
	_apply()
	_save()
	changed.emit()
	return resolutions[resolution_index]


func _is_fullscreen() -> bool:
	var mode := DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


func current_description() -> String:
	if fullscreen:
		var size := DisplayServer.window_get_size()
		return "FULLSCREEN · %d×%d" % [size.x, size.y]
	var res: Vector2i = resolutions[clampi(resolution_index, 0, resolutions.size() - 1)]
	return "%d×%d WINDOWED" % [res.x, res.y]
