class_name Backdrop
extends Node2D
## Static, parallaxed, procedurally drawn cyberpunk street.

var camera: Camera2D
var sky: Node2D
var far: Node2D
var mid: Node2D
var street: Node2D
var props: Node2D


func configure(width: float, seed_value: int, district: int, cam: Camera2D) -> void:
	camera = cam
	for c in get_children():
		remove_child(c)
		c.queue_free()
	z_as_relative = false
	z_index = -200

	sky = _make_layer(SkyLayer, width, seed_value, district)
	far = _make_layer(FarLayer, width, seed_value + 17, district)
	mid = _make_layer(MidLayer, width, seed_value + 31, district)
	street = _make_layer(StreetLayer, width, seed_value + 53, district)
	props = _make_layer(PropsLayer, width, seed_value + 71, district)


func _make_layer(layer_class, width: float, seed_value: int, district: int) -> Node2D:
	var layer = layer_class.new()
	layer.width = width
	layer.seed_value = seed_value
	layer.district = district
	add_child(layer)
	return layer


func _process(_delta: float) -> void:
	if camera == null or not is_instance_valid(camera):
		return
	var cx := camera.global_position.x
	if sky:
		sky.position.x = cx * 0.94
	if far:
		far.position.x = cx * 0.84
	if mid:
		mid.position.x = cx * 0.58


# ---------------------------------------------------------------------------
# Shared drawing helpers
# ---------------------------------------------------------------------------

class BaseLayer extends Node2D:
	var width := 4000.0
	var seed_value := 1
	var district := 1

	func _draw() -> void:
		pass

	func make_rng(salt: int) -> RandomNumberGenerator:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value + salt * 7919
		return rng

	func neon_palette() -> Array:
		return [
			Color(1.0, 0.20, 0.55),
			Color(0.15, 0.95, 1.0),
			Color(0.65, 0.30, 1.0),
			Color(1.0, 0.66, 0.12),
			Color(0.25, 1.0, 0.65),
		]

	func sign_text(pos: Vector2, text: String, color: Color, size: int, rot: float = 0.0) -> void:
		var font := ThemeDB.fallback_font
		var glow := color
		glow.a = 0.16
		draw_set_transform(pos, rot, Vector2.ONE)
		draw_string(font, Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_CENTER, 0, size, glow)
		draw_string(font, Vector2(0, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 0, size, color)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


class SkyLayer extends BaseLayer:
	func _draw() -> void:
		var top := Color(0.02, 0.01, 0.06)
		var horizon := Color(0.23, 0.06, 0.29)
		var bands := 30
		for i in bands:
			var t := float(i) / float(bands - 1)
			var c := top.lerp(horizon, pow(t, 1.8))
			draw_rect(Rect2(-1400, -760.0 + t * 760.0, width + 2800, 760.0 / bands + 1.0), c)

		# moon / neon sun
		var moon_x := width * 0.28
		for i in 5:
			var r := 140.0 - i * 22.0
			draw_circle(Vector2(moon_x, -330), r, Color(0.75, 0.22, 0.55, 0.03 + i * 0.012))
		draw_circle(Vector2(moon_x, -330), 58.0, Color(0.96, 0.58, 0.78, 0.42))
		draw_circle(Vector2(moon_x, -330), 52.0, Color(0.10, 0.03, 0.12, 0.6))
		draw_arc(Vector2(moon_x, -330), 53.0, 0.0, TAU, 48, Color(1.0, 0.5, 0.8, 0.35), 2.0, true)

		# clouds
		var rng := make_rng(1)
		for i in 14:
			var x := rng.randf_range(-600, width + 600)
			var y := rng.randf_range(-560, -160)
			var w := rng.randf_range(180, 520)
			draw_rect(Rect2(x, y, w, rng.randf_range(8, 26)), Color(0.4, 0.15, 0.4, 0.05))

		# distant megatowers
		var x := -900.0
		while x < width + 900.0:
			var w := rng.randf_range(40, 120)
			var h := rng.randf_range(120, 420)
			var shade := rng.randf_range(0.02, 0.055)
			draw_rect(Rect2(x, -h, w, h), Color(shade, shade * 0.7, shade * 1.4))
			# windows
			var cols := int(w / 13.0)
			var rows := int(h / 16.0)
			for cx in cols:
				for cy in rows:
					if rng.randf() < 0.13:
						var wc := Color(0.8, 0.3, 0.9, rng.randf_range(0.15, 0.45))
						draw_rect(Rect2(x + 5 + cx * 13, -h + 8 + cy * 16, 4, 5), wc)
			if rng.randf() < 0.18:
				draw_line(Vector2(x + w * 0.5, -h), Vector2(x + w * 0.5, -h - 40), Color(0.3, 0.2, 0.4, 0.6), 2.0)
			x += w + rng.randf_range(8, 40)


class FarLayer extends BaseLayer:
	func _draw() -> void:
		var rng := make_rng(2)
		var pal := neon_palette()
		var x := -500.0
		while x < width + 500.0:
			var w := rng.randf_range(110, 280)
			var h := rng.randf_range(220, 560)
			var base := Color(0.052, 0.050, 0.105)
			var rect := Rect2(x, -h, w, h)
			draw_rect(rect, base)
			draw_rect(Rect2(x, -h, w, 3), Color(0.15, 0.17, 0.26))
			# window grid
			var cols := maxi(2, int(w / 22.0))
			var rows := maxi(3, int(h / 26.0))
			for cx in cols:
				for cy in rows:
					if rng.randf() < 0.30:
						var c: Color = pal[rng.randi() % pal.size()]
						c.a = rng.randf_range(0.18, 0.62)
						draw_rect(Rect2(x + 10 + cx * (w - 20) / cols, -h + 16 + cy * (h - 20) / rows, 7, 9), c)
			# rooftop details
			if rng.randf() < 0.5:
				draw_rect(Rect2(x + w * 0.2, -h - 20, w * 0.18, 20), base.lightened(0.03))
			if rng.randf() < 0.35:
				draw_line(Vector2(x + w * 0.7, -h), Vector2(x + w * 0.7, -h - 80), Color(0.25, 0.22, 0.3), 3.0)
				draw_circle(Vector2(x + w * 0.7, -h - 80), 3.0, Color(1.0, 0.2, 0.3, 0.8))
			# vertical neon strip
			if rng.randf() < 0.55:
				var c2: Color = pal[rng.randi() % pal.size()]
				var sx := x + rng.randf_range(6, w - 10)
				draw_line(Vector2(sx, -h + 18), Vector2(sx, -20), Color(c2, 0.62), 2.0)
				draw_line(Vector2(sx, -h + 18), Vector2(sx, -20), Color(c2, 0.08), 8.0)
			# billboard
			if rng.randf() < 0.30:
				var bw := rng.randf_range(50, 110)
				var bh := rng.randf_range(30, 60)
				var bx := x + rng.randf_range(10, maxf(10, w - bw - 10))
				var by := -h + rng.randf_range(60, maxf(60, h - 100))
				var c3: Color = pal[rng.randi() % pal.size()]
				draw_rect(Rect2(bx, by, bw, bh), Color(0.02, 0.02, 0.04))
				draw_rect(Rect2(bx, by, bw, bh), Color(c3, 0.5), false, 1.5)
				draw_rect(Rect2(bx + 4, by + 4, bw - 8, bh - 8), Color(c3, 0.10))
				for i in 3:
					draw_rect(Rect2(bx + 6, by + 8 + i * 9, bw * rng.randf_range(0.3, 0.8), 3), Color(c3, 0.5))
			x += w + rng.randf_range(4, 24)

		# atmospheric haze over the skyline
		draw_rect(Rect2(-1400, -220, width + 2800, 220), Color(0.30, 0.05, 0.30, 0.06))


class MidLayer extends BaseLayer:
	func _draw() -> void:
		var rng := make_rng(3)
		var pal := neon_palette()
		# overhead cables
		for i in 5:
			var y := -260.0 + i * 26.0
			var pts := PackedVector2Array()
			var x := -600.0
			while x < width + 600.0:
				var sag := sin(x * 0.006 + i) * 14.0
				pts.append(Vector2(x, y + sag))
				x += 60.0
			draw_polyline(pts, Color(0.03, 0.03, 0.06, 0.85), 2.0, true)
			if i % 2 == 0:
				var lx := fmod(width * 0.3 + i * 411.0, width)
				draw_circle(Vector2(lx, y + 2), 3.0, Color(1.0, 0.5, 0.2, 0.4))

		var x := -400.0
		while x < width + 400.0:
			var w := rng.randf_range(200, 420)
			var h := rng.randf_range(300, 620)
			var base := Color(0.042, 0.040, 0.085)
			draw_rect(Rect2(x, -h, w, h + 30), base)
			draw_rect(Rect2(x, -h, w, 6), Color(0.10, 0.12, 0.20))
			# sign bands
			if rng.randf() < 0.85:
				var c: Color = pal[rng.randi() % pal.size()]
				var sy := -h + rng.randf_range(30, maxf(30, h * 0.55))
				draw_rect(Rect2(x + 12, sy, w - 24, 3), Color(c, 0.72))
				draw_rect(Rect2(x + 12, sy - 1, w - 24, 5), Color(c, 0.08))
			# big vertical neon sign
			if rng.randf() < 0.65:
				var c2: Color = pal[rng.randi() % pal.size()]
				var sign_w := rng.randf_range(28, 52)
				var sign_h := rng.randf_range(120, 240)
				var sx := x + rng.randf_range(10, maxf(10, w - sign_w - 10))
				var sy2 := -h + rng.randf_range(55, maxf(55, h - sign_h - 40))
				draw_rect(Rect2(sx, sy2, sign_w, sign_h), Color(0.015, 0.015, 0.03))
				draw_rect(Rect2(sx, sy2, sign_w, sign_h), Color(c2, 0.6), false, 2.0)
				var glyphs := ["ネ", "オ", "ン", "電", "脳", "薬", "銃", "罪"]
				for gi in int(sign_h / 30.0):
					var ch: String = glyphs[rng.randi() % glyphs.size()]
					var gc: Color = c2
					gc.a = 0.75
					draw_string(ThemeDB.fallback_font, Vector2(sx + 6, sy2 + 26 + gi * 29), ch,
						HORIZONTAL_ALIGNMENT_LEFT, -1, 18, gc)
			# horizontal sign with text
			if rng.randf() < 0.5:
				var c3: Color = pal[rng.randi() % pal.size()]
				var words := ["SOMA", "BLACK ICE", "NO GODS", "CHROME", "NIGHT CITY", "SYNTH", "PAIN", "LOVE"]
				var word: String = words[rng.randi() % words.size()]
				var wx := x + 18
				var wy := -h + rng.randf_range(40, maxf(40, h - 60))
				sign_text(Vector2(wx, wy), word, Color(c3, 0.95), 16)
				draw_rect(Rect2(wx - 4, wy + 4, word.length() * 9.0, 2), Color(c3, 0.3))
			# windows
			for cx in int(w / 34.0):
				for cy in int(h / 44.0):
					if rng.randf() < 0.22:
						var wc: Color = pal[rng.randi() % pal.size()]
						wc.a = rng.randf_range(0.14, 0.42)
						draw_rect(Rect2(x + 14 + cx * 34, -h + 30 + cy * 44, 12, 16), wc)
			x += w + rng.randf_range(10, 60)

		# ambient neon wash and ground fog
		draw_rect(Rect2(-1400, -240, width + 2800, 280), Color(0.55, 0.10, 0.45, 0.035))
		draw_rect(Rect2(-1400, -150, width + 2800, 190), Color(0.10, 0.45, 0.65, 0.035))
		draw_rect(Rect2(-1400, -50, width + 2800, 60), Color(0.35, 0.08, 0.38, 0.13))


class StreetLayer extends BaseLayer:
	func _draw() -> void:
		var rng := make_rng(4)
		var pal := neon_palette()
		# sidewalk / curb
		draw_rect(Rect2(-1400, -8, width + 2800, 30), Color(0.055, 0.05, 0.08))
		draw_rect(Rect2(-1400, 16, width + 2800, 5), Color(0.12, 0.12, 0.18))
		# asphalt
		draw_rect(Rect2(-1400, 21, width + 2800, 330), Color(0.047, 0.046, 0.068))
		# wet sheen bands
		for i in 8:
			var y := 40.0 + i * 34.0
			draw_rect(Rect2(-1400, y, width + 2800, 10), Color(0.16, 0.08, 0.24, 0.08))
		# lane markings
		var x := -200.0
		while x < width + 400.0:
			draw_rect(Rect2(x, 176, 70, 5), Color(0.72, 0.58, 0.24, 0.30))
			x += 150.0
		# manholes and grates
		x = 120.0
		while x < width + 300.0:
			if rng.randf() < 0.6:
				var gy := 90.0 + rng.randf() * 220.0
				draw_rect(Rect2(x, gy, 46, 10), Color(0.015, 0.015, 0.025))
				for i in 5:
					draw_line(Vector2(x + 4 + i * 8, gy + 1), Vector2(x + 4 + i * 8, gy + 9), Color(0.14, 0.14, 0.2, 0.5), 1.0)
			x += rng.randf_range(250, 520)
		# puddles with neon reflections
		for i in int(width / 210.0) + 4:
			var px := rng.randf_range(-200, width + 200)
			var py := rng.randf_range(55, 315)
			var pw := rng.randf_range(40, 120)
			var c: Color = pal[rng.randi() % pal.size()]
			draw_set_transform(Vector2(px, py), 0.0, Vector2(1.0, 0.20))
			draw_circle(Vector2.ZERO, pw * 0.5, Color(0.02, 0.02, 0.04, 0.7))
			draw_arc(Vector2.ZERO, pw * 0.5, 0.0, TAU, 24, Color(c, 0.32), 2.0, true)
			draw_line(Vector2(-pw * 0.35, 0), Vector2(pw * 0.35, 0), Color(c, 0.24), 4.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# vertical neon bleed on wet asphalt
		for i in int(width / 150.0) + 8:
			var rx := rng.randf_range(-100.0, width + 100.0)
			var rc: Color = pal[rng.randi() % pal.size()]
			for k in 9:
				var yy := 22.0 + k * 14.0
				var a := 0.16 * (1.0 - k * 0.10)
				draw_rect(Rect2(rx + sin(k * 0.7) * 3.0, yy, rng.randf_range(2.0, 6.0), 15.0), Color(rc, a * 0.5))
		# road hazard paint
		x = 0.0
		while x < width:
			if rng.randf() < 0.4:
				var hy := rng.randf_range(60.0, 320.0)
				for k in 3:
					draw_line(Vector2(x + k * 12.0, hy), Vector2(x + 10.0 + k * 12.0, hy - 14.0),
						Color(0.85, 0.66, 0.2, 0.16), 3.0, true)
			x += rng.randf_range(300.0, 700.0)
		# curb neon
		draw_line(Vector2(-1400, 17), Vector2(width + 1400, 17), Color(0.2, 0.9, 1.0, 0.45), 2.0)
		draw_line(Vector2(-1400, 19), Vector2(width + 1400, 19), Color(0.2, 0.9, 1.0, 0.12), 7.0)
		# bottom sidewalk / foreground
		draw_rect(Rect2(-1400, 351, width + 2800, 240), Color(0.04, 0.035, 0.06))
		draw_rect(Rect2(-1400, 351, width + 2800, 4), Color(0.15, 0.14, 0.22))
		for i in int(width / 90.0) + 6:
			var sx := rng.randf_range(-200, width + 200)
			draw_line(Vector2(sx, 358), Vector2(sx + rng.randf_range(-18, 18), 430), Color(0.02, 0.02, 0.03, 0.6), 2.0)

		# street lamps
		x = 200.0
		while x < width:
			draw_line(Vector2(x, 20), Vector2(x, -170), Color(0.10, 0.11, 0.16), 5.0)
			draw_line(Vector2(x, -170), Vector2(x + 34, -170), Color(0.10, 0.11, 0.16), 4.0)
			var c2: Color = pal[rng.randi() % pal.size()]
			draw_circle(Vector2(x + 36, -168), 5.0, Color(c2, 0.95))
			draw_circle(Vector2(x + 36, -168), 20.0, Color(c2, 0.10))
			# light cone
			draw_colored_polygon(PackedVector2Array([
				Vector2(x + 31, -168), Vector2(x + 41, -168),
				Vector2(x + 110, 170), Vector2(x - 40, 170),
			]), Color(c2, 0.035))
			# light pool on the asphalt
			draw_set_transform(Vector2(x + 36, 130), 0.0, Vector2(1.0, 0.4))
			draw_circle(Vector2.ZERO, 70.0, Color(c2, 0.035))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			x += rng.randf_range(380, 620)


class PropsLayer extends BaseLayer:
	func _draw() -> void:
		var rng := make_rng(5)
		var pal := neon_palette()
		var x := 80.0
		while x < width:
			var roll := rng.randf()
			if roll < 0.28:
				# crate stack
				var cy := rng.randf_range(40, 300)
				var csize := rng.randf_range(26, 44)
				draw_rect(Rect2(x, cy - csize, csize, csize), Color(0.08, 0.07, 0.10))
				draw_rect(Rect2(x, cy - csize, csize, csize), Color(0.24, 0.20, 0.16), false, 2.0)
				draw_line(Vector2(x + 4, cy - csize + 4), Vector2(x + csize - 4, cy - 4), Color(0.20, 0.16, 0.12), 2.0)
				if rng.randf() < 0.5:
					draw_rect(Rect2(x + csize * 0.3, cy - csize - 18, csize * 0.55, 18), Color(0.07, 0.06, 0.09))
			elif roll < 0.48:
				# barrel
				var by := rng.randf_range(60, 290)
				var c2: Color = pal[rng.randi() % pal.size()]
				draw_rect(Rect2(x, by - 30, 20, 30), Color(0.12, 0.12, 0.16))
				draw_line(Vector2(x, by - 24), Vector2(x + 20, by - 24), Color(c2, 0.5), 2.0)
				draw_line(Vector2(x, by - 8), Vector2(x + 20, by - 8), Color(c2, 0.5), 2.0)
			elif roll < 0.62:
				# neon bollards
				for i in 3:
					draw_rect(Rect2(x + i * 18, 320, 8, 26), Color(0.10, 0.10, 0.14))
					draw_rect(Rect2(x + i * 18 + 2, 318, 4, 5), Color(0.2, 0.9, 1.0, 0.7))
			elif roll < 0.78:
				# vent with steam glow
				var vy := rng.randf_range(120, 320)
				draw_rect(Rect2(x, vy, 58, 12), Color(0.02, 0.02, 0.04))
				for i in 6:
					draw_line(Vector2(x + 4 + i * 9, vy + 1), Vector2(x + 4 + i * 9, vy + 11), Color(0.2, 0.2, 0.28, 0.5), 1.5)
				draw_circle(Vector2(x + 29, vy - 26), 26.0, Color(0.5, 0.3, 0.6, 0.035))
			elif roll < 0.90:
				# dumpster
				var dy := rng.randf_range(180, 300)
				draw_rect(Rect2(x, dy - 34, 62, 34), Color(0.06, 0.10, 0.10))
				draw_rect(Rect2(x - 3, dy - 40, 68, 8), Color(0.09, 0.14, 0.14))
				draw_line(Vector2(x + 6, dy - 20), Vector2(x + 40, dy - 20), Color(0.2, 0.9, 0.7, 0.2), 2.0)
				draw_circle(Vector2(x + 12, dy - 3), 5.0, Color(0.02, 0.02, 0.03))
				draw_circle(Vector2(x + 50, dy - 3), 5.0, Color(0.02, 0.02, 0.03))
			else:
				# holographic ad pillar
				var hy := rng.randf_range(190, 300)
				var c3: Color = pal[rng.randi() % pal.size()]
				draw_rect(Rect2(x, hy - 90, 34, 90), Color(0.02, 0.02, 0.05))
				for i in 7:
					var alpha := 0.08 + 0.07 * sin(i * 1.7)
					draw_rect(Rect2(x + 4, hy - 84 + i * 11, 26, 7), Color(c3, alpha))
				draw_rect(Rect2(x, hy - 90, 34, 90), Color(c3, 0.35), false, 1.5)
				draw_circle(Vector2(x + 17, hy + 2), 16.0, Color(c3, 0.06))
			x += rng.randf_range(140, 300)
