extends Node
## Hangeffektek (indításkor szintetizálva) és zene (a tools/make_music.mjs által renderelt saját dalok).

const RATE := 22050
var _players := {}
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_name := ""
var muted := false
var quiet := false      # online felzárkózás közben nem szólnak az effektek
var _noise := PackedFloat32Array()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Music", "SFX"]:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus)
		AudioServer.set_bus_send(idx, "Master")
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), -5.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), -1.0)
	var comp := AudioEffectLimiter.new()
	comp.ceiling_db = -0.5
	AudioServer.add_bus_effect(0, comp)
	_music_a = _mk_music_player()
	_music_b = _mk_music_player()
	seed(7)
	_noise.resize(RATE)
	for i in RATE:
		_noise[i] = randf() * 2.0 - 1.0
	randomize()
	_build_sfx()


func _mk_music_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Music"
	add_child(p)
	return p


func toggle_mute() -> bool:
	muted = not muted
	AudioServer.set_bus_mute(0, muted)
	return muted


# ------------------------------------------------------------------ zene
func music(name: String, fade := 0.8) -> void:
	if name == _music_name:
		return
	_music_name = name
	var path := "res://music/%s.wav" % name
	var old := _music_a if _music_a.playing else null
	var nxt := _music_b if old == _music_a else _music_a
	if old:
		var tw := create_tween()
		tw.tween_property(old, "volume_db", -40.0, fade)
		tw.tween_callback(old.stop)
	if name == "" or not ResourceLoader.exists(path):
		return
	nxt.stream = load(path)
	nxt.volume_db = -30.0
	nxt.play()
	create_tween().tween_property(nxt, "volume_db", 0.0, fade * 0.7)


func jingle(name: String) -> void:
	## rövid, nem ismétlődő zenei betét (a háttérzene halkul alatta)
	var path := "res://music/%s.wav" % name
	if quiet or not ResourceLoader.exists(path):
		return
	var p := AudioStreamPlayer.new()
	p.bus = "Music"
	p.stream = load(path)
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	for m in [_music_a, _music_b]:
		if m.playing:
			var tw := create_tween()
			tw.tween_property(m, "volume_db", -18.0, 0.2)
			tw.tween_interval(max(0.5, p.stream.get_length() - 0.6))
			tw.tween_property(m, "volume_db", 0.0, 0.8)


# ------------------------------------------------------------------ effektek
func play(name: String, pitch := 1.0) -> void:
	var p: AudioStreamPlayer = _players.get(name)
	if p == null or quiet:
		return
	p.pitch_scale = pitch
	p.play()


func pad(i: int) -> void: play("pad%d" % i)
func pad_soft(i: int) -> void: play("padsoft%d" % i)


func _store(name: String, buf: PackedFloat32Array, poly := 4) -> void:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clamp(buf[i], -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.bus = "SFX"
	p.max_polyphony = poly
	add_child(p)
	_players[name] = p


## Egyszerű hangszintézis egy pufferbe.
## kind: square, triangle, sine, saw. slide: frekvenciaváltozás a hang végéig (exponenciális).
func _tone(buf: PackedFloat32Array, f: float, d: float, kind := "square", v := 0.15, slide := 0.0, at := 0.0, attack := 0.005) -> void:
	var start := int(at * RATE)
	var n := int(d * RATE)
	if buf.size() < start + n + 10:
		buf.resize(start + n + 10)
	var ph := 0.0
	var f2: float = max(30.0, f + slide)
	for i in n:
		var k := float(i) / n
		var freq := f * pow(f2 / f, k) if slide != 0.0 else f
		ph = fmod(ph + freq / RATE, 1.0)
		var s := 0.0
		match kind:
			"square": s = 1.0 if ph < 0.5 else -1.0
			"triangle": s = 4.0 * abs(ph - 0.5) - 1.0
			"saw": s = 2.0 * ph - 1.0
			_: s = sin(ph * TAU)
		var t := float(i) / RATE
		var env: float = min(1.0, t / attack) * pow(0.0005, k)
		buf[start + i] += s * v * env


func _noise_burst(buf: PackedFloat32Array, d: float, v := 0.3, at := 0.0, cutoff := 1500.0) -> void:
	var start := int(at * RATE)
	var n := int(d * RATE)
	if buf.size() < start + n + 10:
		buf.resize(start + n + 10)
	var a: float = clamp(cutoff / RATE * TAU, 0.01, 1.0)
	var lp := 0.0
	for i in n:
		var k := float(i) / n
		lp += (_noise[i % _noise.size()] - lp) * a
		buf[start + i] += lp * v * pow(0.0005, k) * 1.6


func _build_sfx() -> void:
	var b: PackedFloat32Array
	b = PackedFloat32Array(); _tone(b, 880, 0.035, "square", 0.05); _store("tick", b, 6)
	b = PackedFloat32Array(); _tone(b, 988, 0.07, "square", 0.1); _tone(b, 1319, 0.22, "square", 0.1, 0, 0.07); _store("coin", b, 6)
	b = PackedFloat32Array(); _tone(b, 330, 0.3, "saw", 0.12, -170); _store("bad", b)
	b = PackedFloat32Array(); _tone(b, 520, 0.07, "triangle", 0.15, 260); _store("step", b, 6)
	b = PackedFloat32Array(); _tone(b, 200, 0.12, "triangle", 0.28, -80); _store("land", b, 6)
	b = PackedFloat32Array(); _tone(b, 150, 0.12, "triangle", 0.35, -60); _noise_burst(b, 0.08, 0.2, 0, 3000); _store("hit", b, 6)
	b = PackedFloat32Array(); _tone(b, 620, 0.08, "sine", 0.3, 380); _store("pop", b, 6)
	b = PackedFloat32Array(); _tone(b, 660, 0.08, "triangle", 0.18); _store("select", b, 4)
	b = PackedFloat32Array(); _tone(b, 440, 0.18, "triangle", 0.3); _store("count", b)
	b = PackedFloat32Array(); _tone(b, 880, 0.45, "triangle", 0.3); _tone(b, 1320, 0.45, "square", 0.05); _store("count_go", b)
	b = PackedFloat32Array(); _tone(b, 523, 0.1, "square", 0.12); _tone(b, 784, 0.25, "square", 0.12, 0, 0.1); _store("go", b)
	b = PackedFloat32Array()
	for i in 4: _tone(b, [523, 659, 784, 1047][i], 0.22, "triangle", 0.24, 0, i * 0.1)
	_store("win", b)
	b = PackedFloat32Array()
	for i in 4: _tone(b, [392, 349, 311, 262][i], 0.24, "triangle", 0.2, 0, i * 0.13)
	_store("lose", b)
	b = PackedFloat32Array()
	for i in 5: _tone(b, [784, 988, 1175, 1568, 1976][i], 0.3, "square", 0.07, 0, i * 0.08)
	_store("crown", b)
	b = PackedFloat32Array()
	var fan := [[523, 0.0], [523, 0.12], [523, 0.24], [659, 0.36], [784, 0.6], [659, 0.78], [784, 0.9]]
	for fa in fan:
		_tone(b, fa[0], 0.22, "square", 0.08, 0, fa[1]); _tone(b, fa[0] / 2.0, 0.22, "triangle", 0.14, 0, fa[1])
	_store("fanfare", b, 2)
	b = PackedFloat32Array(); _noise_burst(b, 0.28, 0.32, 0, 2600); _store("whoosh", b)
	b = PackedFloat32Array(); _noise_burst(b, 0.75, 0.6, 0, 700); _tone(b, 100, 0.5, "sine", 0.5, -60); _store("boom", b)
	b = PackedFloat32Array(); _noise_burst(b, 0.5, 0.4, 0, 1200); _store("splash", b)
	b = PackedFloat32Array(); _tone(b, 450, 0.03, "square", 0.05); _store("roll", b, 4)
	b = PackedFloat32Array(); _tone(b, 300, 0.05, "square", 0.08, 400); _tone(b, 900, 0.05, "square", 0.05, 300, 0.05); _store("jump", b, 6)
	b = PackedFloat32Array()
	for i in 6: _tone(b, 1200 + i * 180, 0.06, "sine", 0.12, 0, i * 0.03)
	_store("sparkle", b)
	b = PackedFloat32Array(); _tone(b, 180, 0.6, "saw", 0.12, -120); _tone(b, 120, 0.6, "square", 0.06, -60); _store("fail", b)
	b = PackedFloat32Array()
	for i in 3: _tone(b, [392, 523, 659][i], 0.12, "square", 0.08, 0, i * 0.06)
	_store("ally", b)
	b = PackedFloat32Array(); _noise_burst(b, 0.12, 0.25, 0, 5000); _tone(b, 1600, 0.05, "square", 0.05); _store("clap", b, 8)
	b = PackedFloat32Array(); _tone(b, 1046, 0.6, "sine", 0.18); _tone(b, 1568, 0.6, "sine", 0.08); _tone(b, 2093, 0.4, "sine", 0.05); _store("bell", b)
	var pads := [329.63, 261.63, 392.0, 523.25]
	for i in 4:
		b = PackedFloat32Array(); _tone(b, pads[i], 0.4, "triangle", 0.3); _store("pad%d" % i, b)
		b = PackedFloat32Array(); _tone(b, pads[i], 0.15, "sine", 0.1); _store("padsoft%d" % i, b)
