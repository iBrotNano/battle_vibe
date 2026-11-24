extends Node
## Procedurally synthesized cyberpunk SFX. No audio files required.
## Sounds are generated into AudioStreamWAV buffers at boot and played through
## pooled 2D/UI players (2D sounds pan/attenuate relative to the camera).

const MIX_RATE := 22050
const POOL_2D := 24
const POOL_UI := 8

var streams: Dictionary = {}
var muted := false

var _players_2d: Array = []
var _players_ui: Array = []
var _idx_2d := 0
var _idx_ui := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_generate_all()
	for i in POOL_2D:
		var p := AudioStreamPlayer2D.new()
		p.max_distance = 1700.0
		p.attenuation = 1.1
		p.panning_strength = 1.0
		add_child(p)
		_players_2d.append(p)
	for i in POOL_UI:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players_ui.append(p)


## Play a sound. Pass a world position for positional audio, or null for UI audio.
func play(sound: String, pos: Variant = null, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if muted:
		return
	var stream: AudioStream = streams.get(sound)
	if stream == null:
		return
	if pos is Vector2:
		var p: AudioStreamPlayer2D = _take(_players_2d, true)
		p.stream = stream
		p.position = pos
		p.volume_db = volume_db - 2.0
		p.pitch_scale = clampf(pitch, 0.25, 4.0)
		p.play()
	else:
		var p: AudioStreamPlayer = _take(_players_ui, false)
		p.stream = stream
		p.volume_db = volume_db - 2.0
		p.pitch_scale = clampf(pitch, 0.25, 4.0)
		p.play()


func play_ui(sound: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	play(sound, null, volume_db, pitch)


func toggle_mute() -> bool:
	muted = not muted
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), muted)
	return muted


func _take(pool: Array, is_2d: bool) -> Node:
	for p in pool:
		if not p.playing:
			return p
	var idx: int
	if is_2d:
		idx = _idx_2d % pool.size()
		_idx_2d += 1
	else:
		idx = _idx_ui % pool.size()
		_idx_ui += 1
	var old = pool[idx]
	old.stop()
	return old


# ---------------------------------------------------------------------------
# Synthesis
# ---------------------------------------------------------------------------

func _generate_all() -> void:
	streams["swing_light"] = _whoosh(0.14, 1500.0, 380.0, 0.70)
	streams["swing_heavy"] = _whoosh(0.30, 900.0, 160.0, 0.95)
	streams["dash"] = _whoosh(0.22, 1800.0, 260.0, 0.75)
	streams["hit_light"] = _impact(0.18, 170.0, 48.0, 0.95, 0.0)
	streams["hit_heavy"] = _impact(0.34, 120.0, 32.0, 1.05, 0.30)
	streams["hurt"] = _impact(0.26, 220.0, 70.0, 0.85, 0.04)
	streams["gunshot"] = _gunshot()
	streams["overclock"] = _overclock()
	streams["die_player"] = _player_death()
	streams["die_enemy"] = _enemy_death()
	streams["loot"] = _chime([880.0, 1174.66, 1567.98], 0.055, 0.55, 0.55)
	streams["salvage"] = _salvage()
	streams["levelup"] = _chime([523.25, 659.25, 783.99, 1046.5], 0.085, 1.10, 0.62)
	streams["ui_start"] = _ui_start()
	streams["ui_click"] = _click()
	streams["stat"] = _chime([987.77, 1318.51], 0.035, 0.22, 0.40)
	streams["arena_clear"] = _chime([392.0, 523.25, 659.25], 0.085, 0.85, 0.55)
	streams["district_clear"] = _chime([261.63, 392.0, 523.25, 659.25], 0.11, 1.30, 0.60)
	streams["alert"] = _alert()
	streams["portal"] = _portal()
	streams["step"] = _step()
	streams["aim"] = _beep(0.18, 1500.0, 0.30)


func _buf(duration: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(maxi(1, int(duration * MIX_RATE)))
	return samples


func _finish(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v := samples[i]
		if v > 1.0:
			v = 1.0
		elif v < -1.0:
			v = -1.0
		bytes.encode_s16(i * 2, int(round(v * 32000.0)))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes
	return wav


func _whoosh(duration: float, f0: float, f1: float, amp: float) -> AudioStreamWAV:
	var samples := _buf(duration)
	var n := samples.size()
	var phase := 0.0
	var lp := 0.0
	for i in n:
		var p := float(i) / float(n)
		var freq := lerpf(f0, f1, pow(p, 0.7))
		phase += TAU * freq / MIX_RATE
		var nz := _rng.randf_range(-1.0, 1.0)
		lp = lerpf(lp, nz, 0.16)
		var air := nz - lp
		var env := pow(sin(PI * p), 1.2)
		samples[i] = (air * 0.55 + lp * 0.38 + sin(phase) * 0.13) * env * amp
	return _finish(samples)


func _impact(duration: float, f0: float, f1: float, amp: float, metal: float) -> AudioStreamWAV:
	var samples := _buf(duration)
	var n := samples.size()
	var phase := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		var p := float(i) / float(n)
		var freq := lerpf(f0, f1, pow(p, 0.35))
		phase += TAU * freq / MIX_RATE
		var attack := minf(t / 0.003, 1.0)
		var env: float = attack * exp(-t * 15.0) * pow(1.0 - p, 1.4)
		var body := sin(phase) * 0.95 + sin(phase * 2.01) * 0.28 + sin(phase * 0.5) * 0.18
		var crack := _rng.randf_range(-1.0, 1.0) * exp(-t * 55.0)
		var mtl := sin(TAU * 1180.0 * t) * exp(-t * 20.0) * metal
		samples[i] = (body * 0.8 + crack * 0.55 + mtl) * env * amp
	return _finish(samples)


func _gunshot() -> AudioStreamWAV:
	var duration := 0.26
	var samples := _buf(duration)
	var n := samples.size()
	for i in n:
		var t := float(i) / MIX_RATE
		var p := float(i) / float(n)
		var attack := minf(t / 0.001, 1.0)
		var crack := _rng.randf_range(-1.0, 1.0) * exp(-t * 58.0)
		var body := sin(TAU * lerpf(190.0, 55.0, p) * t) * exp(-t * 12.0)
		var hiss := _rng.randf_range(-1.0, 1.0) * 0.25 * exp(-t * 16.0)
		samples[i] = (crack * 0.7 + body * 0.75 + hiss) * attack * pow(1.0 - p, 1.2) * 0.9
	return _finish(samples)


func _overclock() -> AudioStreamWAV:
	var duration := 0.9
	var samples := _buf(duration)
	var n := samples.size()
	var rise_phase := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		var p := float(i) / float(n)
		var rise_len := 0.35
		var value := 0.0
		if t < rise_len:
			var rp := t / rise_len
			var freq := lerpf(90.0, 1300.0, rp * rp)
			rise_phase += TAU * freq / MIX_RATE
			value = (sin(rise_phase) + sin(rise_phase * 1.5) * 0.35) * rp * 0.65
		else:
			var bp := (t - rise_len) / (duration - rise_len)
			var boom := sin(TAU * lerpf(70.0, 34.0, bp) * t) * exp(-bp * 5.5)
			var nz := _rng.randf_range(-1.0, 1.0) * exp(-bp * 9.0)
			var ring := sin(TAU * 660.0 * t) * exp(-bp * 7.0) * 0.18
			value = (boom * 0.9 + nz * 0.35 + ring) * (1.0 - bp) * 0.9
		samples[i] = value
	return _finish(samples)


func _player_death() -> AudioStreamWAV:
	var duration := 1.15
	var samples := _buf(duration)
	var n := samples.size()
	var phase := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		var p := float(i) / float(n)
		var freq := lerpf(240.0, 34.0, pow(p, 0.7))
		phase += TAU * freq / MIX_RATE
		var tone := sin(phase) * 0.7 + sin(phase * 0.5) * 0.25
		var grit := (1.0 if sin(phase * 3.0) >= 0.0 else -1.0) * 0.08
		var nz := _rng.randf_range(-1.0, 1.0) * 0.18 * exp(-t * 1.6)
		var env := minf(t / 0.01, 1.0) * exp(-t * 1.1) * pow(1.0 - p, 0.8)
		samples[i] = (tone + grit + nz) * env * 0.85
	return _finish(samples)


func _enemy_death() -> AudioStreamWAV:
	var duration := 0.45
	var samples := _buf(duration)
	var n := samples.size()
	var phase := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		var p := float(i) / float(n)
		var freq := lerpf(560.0, 65.0, pow(p, 0.6))
		phase += TAU * freq / MIX_RATE
		var square := 1.0 if sin(phase) >= 0.0 else -1.0
		var glitch := 1.0 if int(t * 34.0) % 4 != 0 else 0.15
		var nz := _rng.randf_range(-1.0, 1.0) * 0.35 * exp(-t * 7.0)
		var env := minf(t / 0.004, 1.0) * exp(-t * 4.5) * pow(1.0 - p, 1.1)
		samples[i] = (square * 0.32 * glitch + nz + sin(phase * 0.5) * 0.25) * env * 0.9
	return _finish(samples)


func _chime(notes: Array, spacing: float, duration: float, amp: float) -> AudioStreamWAV:
	var samples := _buf(duration)
	var n := samples.size()
	for ni in notes.size():
		var freq: float = notes[ni]
		var start := int(ni * spacing * MIX_RATE)
		for i in range(start, n):
			var t := float(i - start) / MIX_RATE
			var env := minf(t / 0.005, 1.0) * exp(-t * 3.6)
			var tone := sin(TAU * freq * t) + sin(TAU * freq * 2.004 * t) * 0.22
			samples[i] += tone * env * amp / (1.0 + ni * 0.22)
	return _finish(samples)


func _chord(freqs: Array, duration: float, amp: float) -> AudioStreamWAV:
	var samples := _buf(duration)
	var n := samples.size()
	for i in n:
		var t := float(i) / MIX_RATE
		var p := float(i) / float(n)
		var env := minf(t / 0.05, 1.0) * exp(-t * 1.2) * pow(1.0 - p, 1.2)
		var value := 0.0
		for f in freqs:
			value += sin(TAU * float(f) * t) * 0.5 + sin(TAU * float(f) * 1.004 * t) * 0.25
		samples[i] = value * env * amp / maxf(1.0, freqs.size() * 0.7)
	return _finish(samples)


func _ui_start() -> AudioStreamWAV:
	var base := _chord([110.0, 164.81, 220.0], 0.9, 0.55)
	var bytes: PackedByteArray = base.data
	# overlay a rising digital sweep on top of the chord
	var sweep := _whoosh(0.9, 260.0, 1400.0, 0.32)
	var other: PackedByteArray = sweep.data
	var out := PackedByteArray()
	out.resize(bytes.size())
	for i in range(0, bytes.size(), 2):
		if i + 1 >= other.size():
			break
		var a := bytes.decode_s16(i) + other.decode_s16(i)
		out.encode_s16(i, clampi(a, -32000, 32000))
	return _wav_from_bytes(out)


func _salvage() -> AudioStreamWAV:
	var duration := 0.24
	var samples := _buf(duration)
	var n := samples.size()
	var phase := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		var p := float(i) / float(n)
		var freq := lerpf(1700.0, 520.0, p)
		phase += TAU * freq / MIX_RATE
		var env := minf(t / 0.002, 1.0) * exp(-t * 18.0)
		var clink := sin(phase) * 0.6 + sin(phase * 2.7) * 0.3
		var nz := _rng.randf_range(-1.0, 1.0) * 0.2 * exp(-t * 60.0)
		samples[i] = (clink + nz) * env * 0.7
	return _finish(samples)


func _click() -> AudioStreamWAV:
	var samples := _buf(0.06)
	var n := samples.size()
	for i in n:
		var t := float(i) / MIX_RATE
		var env := minf(t / 0.001, 1.0) * exp(-t * 70.0)
		samples[i] = (sin(TAU * 1350.0 * t) * 0.4 + _rng.randf_range(-1.0, 1.0) * 0.2) * env
	return _finish(samples)


func _alert() -> AudioStreamWAV:
	var duration := 0.5
	var samples := _buf(duration)
	var n := samples.size()
	for i in n:
		var t := float(i) / MIX_RATE
		var value := 0.0
		if t >= 0.0 and t < 0.16:
			value = _square(880.0, t) * minf(t / 0.005, 1.0) * exp(-t * 6.0)
		elif t >= 0.22 and t < 0.40:
			var lt := t - 0.22
			value = _square(660.0, lt) * minf(lt / 0.005, 1.0) * exp(-lt * 6.0)
		samples[i] = value * 0.32
	return _finish(samples)


func _portal() -> AudioStreamWAV:
	var duration := 0.55
	var samples := _buf(duration)
	var n := samples.size()
	var phase := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		var p := float(i) / float(n)
		var freq := lerpf(70.0, 480.0, p * p)
		phase += TAU * freq / MIX_RATE
		var env := pow(sin(PI * p), 1.4)
		var nz := _rng.randf_range(-1.0, 1.0) * 0.25
		samples[i] = (sin(phase) * 0.55 + nz) * env * 0.55
	return _finish(samples)


func _step() -> AudioStreamWAV:
	var samples := _buf(0.07)
	var n := samples.size()
	var lp := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		var nz := _rng.randf_range(-1.0, 1.0)
		lp = lerpf(lp, nz, 0.25)
		var env := minf(t / 0.002, 1.0) * exp(-t * 55.0)
		samples[i] = lp * env * 0.5
	return _finish(samples)


func _beep(duration: float, freq: float, amp: float) -> AudioStreamWAV:
	var samples := _buf(duration)
	var n := samples.size()
	for i in n:
		var t := float(i) / MIX_RATE
		var env := minf(t / 0.004, 1.0) * exp(-t * 9.0)
		samples[i] = sin(TAU * freq * t) * env * amp
	return _finish(samples)


func _square(freq: float, t: float) -> float:
	return 1.0 if sin(TAU * freq * t) >= 0.0 else -1.0


func _wav_from_bytes(bytes: PackedByteArray) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes
	return wav
