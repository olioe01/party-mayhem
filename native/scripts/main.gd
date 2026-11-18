class_name Main
extends Node
## A játék gyökere: jelenetváltás (áttűnéssel), 2D átfedő réteg, részecske-effektek,
## globális billentyűk, és a hálózati események bekötése a jelenetekbe.

static var I: Node = null

var scene: GameScene = null
var _next: GameScene = null
var _fade := 0.0
var _fade_dir := 0
var time := 0.0
var particles: Array = []
var overlay: Control
var world_env: WorldEnvironment
var _shot_at := -1.0
var _graveyard: Array = []
var fps_show := false
var _esc_t := -10.0
var online: OnlineUI


func _ready() -> void:
	I = self
	randomize()
	world_env = WorldEnvironment.new()
	add_child(world_env)
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_overlay)
	layer.add_child(overlay)
	online = OnlineUI.new()
	layer.add_child(online)

	Net.player_joined.connect(Game.on_join)
	Net.player_left.connect(Game.on_leave)
	Net.player_input.connect(func(pid, msg): if scene and not scene.dead and _fade_dir == 0: scene.input(pid, msg))

	var args := OS.get_cmdline_user_args()
	Game.apply_args(args)
	set_scene(LobbyScene.new(), true)
	Game.after_boot(args)


## Jelenetváltás. Maga a csere mindig egy játéklépés elején történik (lásd step), mert ott
## készül az állapotmentés, amiből minden gép – a hoszt is – folytatja.
func set_scene(s: GameScene, instant := false) -> void:
	_next = s
	_fade_dir = 1
	if instant or scene == null:
		_fade = 1.0


func _swap(s: GameScene) -> void:
	if scene:
		scene.kill()
		scene.exit()
		remove_child(scene)
		_graveyard.append(scene)
		if _graveyard.size() > 3:
			_graveyard.pop_front().queue_free()
	particles.clear()
	Net.cancel_asks()
	Sync.clear_timers()
	scene = s
	add_child(s)
	s.enter()


func _process(dt: float) -> void:
	Sync.frame(min(dt, 0.1))    # ez hívja a step()-et annyiszor, ahány játéklépés esedékes
	overlay.queue_redraw()


## Egy játéklépés (fix 1/60 mp). Online játékban minden gép ugyanazokat a lépéseket futtatja.
func step(dt: float) -> void:
	time += dt
	if Sync.client:
		_step_fade_client(dt)
	elif _fade_dir == 1:
		_fade += dt * 4.0
		if _fade >= 1.0 and _next:
			var bytes := Snapshot.capture(_next)
			Sync.host_checkpoint(bytes)
			_resume_from(bytes)
	elif _fade_dir == -1:
		_fade_out(dt)
	if scene:
		scene._tick(dt)
		if not scene.dead:
			scene.update(dt)
	_update_particles(dt)


func _fade_out(dt: float) -> void:
	_fade -= dt * 4.0
	if _fade <= 0.0:
		_fade = 0.0
		_fade_dir = 0


## Vendég gépen a jelenetváltást a hoszt mentése vezérli: ha megjött erre a lépésre, abból
## folytatunk; ha a saját játékunk váltana, de a hoszté még nem, sötétben megvárjuk.
func _step_fade_client(dt: float) -> void:
	var ck = Sync.take_checkpoint()
	if ck == null:
		if _fade_dir == 1:
			_fade = min(1.0, _fade + dt * 4.0)
		elif _fade_dir == -1:
			_fade_out(dt)
		return
	if not Sync.is_init_checkpoint():
		var mine := PackedByteArray()
		if _fade_dir == 1 and _fade + dt * 4.0 >= 1.0 and _next:
			mine = Snapshot.capture(_next)
		Sync.note_checkpoint(mine == ck, mine, ck)
	_resume_from(ck)


func _resume_from(bytes: PackedByteArray) -> void:
	var s := Snapshot.restore(bytes)
	if s == null:
		if Sync.client:
			Sync.leave()
		return
	_fade = 1.0
	_fade_dir = -1
	_next = null
	_swap(s)


func _draw_overlay() -> void:
	var c := overlay
	if scene:
		scene.buttons.clear()
		scene.draw(c)
	_draw_particles(c)
	if _fade > 0.0:
		c.draw_rect(Rect2(-200, -200, 1680, 1120), Color(0.07, 0.04, 0.15, _fade))
	if time - _esc_t < 2.5:
		D.panel(c, 440, 300, 400, 90, {"r": 24, "fill": Color(0.08, 0.05, 0.19, 0.95), "stroke": Color("#ff6b6b")})
		D.text(c, "Kilépés? Nyomd meg újra az Esc-et!", 640, 345, {"size": 22})
	if fps_show:
		D.text(c, "%d FPS" % Engine.get_frames_per_second(), 1270, 710, {"size": 14, "align": "right", "color": Color(1, 1, 1, 0.7)})


## A játékra ható billentyűk és kattintások a közös eseménysoron mennek át (online játékban
## a hoszthoz), és a sim_key / sim_click hajtja végre őket minden gépen ugyanabban a lépésben.
func sim_key(code: int) -> void:
	if scene and not scene.dead and _fade_dir == 0:
		var e := InputEventKey.new()
		e.keycode = code as Key
		e.pressed = true
		scene.key(e)


func sim_click(pos: Vector2) -> void:
	if scene and not scene.dead and _fade_dir == 0:
		scene.click(pos)


func _unhandled_input(event: InputEvent) -> void:
	if online.is_open():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mp := overlay.get_local_mouse_position()
		Sync.submit({"k": "click", "x": mp.x, "y": mp.y})
		return
	if event is InputEventKey and not event.echo and _keyboard_stick(event):
		return
	if event is InputEventKey and not event.echo and _keyboard_lr(event):
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.keycode
		if k == KEY_M:
			Audio.toggle_mute()
		elif k == KEY_F or k == KEY_F11:
			var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif k == KEY_P:
			fps_show = not fps_show
		elif k == KEY_ESCAPE:
			if time - _esc_t < 2.5:
				get_tree().quit()
			_esc_t = time
		elif k == KEY_F12:
			screenshot("user://screenshot_%d.png" % Time.get_unix_time_from_system())
		else:
			Sync.submit({"k": "key", "c": k})


## Billentyűzetes irányítás az ezt kérő minijátékokban (Minigame.keyboard_lr): az A/D és a ←/→
## ugyanazt az „lr” bemenetet adja, mint a telefon ◀ ▶ gombja (lásd _kb_target).
## A bemenet a közös eseménysoron megy át, így a lépésütemet nem bontja meg.
var _kb_keys := {}
var _kb_dir := 0

func _keyboard_lr(event: InputEventKey) -> bool:
	var k: int = event.keycode
	var left := k == KEY_A or k == KEY_LEFT
	var right := k == KEY_D or k == KEY_RIGHT
	if not left and not right:
		return false
	var inst = scene.get("inst") if scene and not scene.dead else null
	if inst == null or not is_instance_valid(inst) or not (inst is Minigame) or not inst.keyboard_lr():
		_kb_keys.clear()
		_kb_dir = 0
		return false
	if event.pressed:
		_kb_keys[k] = 1 if right else -1
	else:
		_kb_keys.erase(k)
	var dir := 0
	for v in _kb_keys.values():
		dir += v
	dir = clampi(dir, -1, 1)
	if dir != _kb_dir:
		_kb_dir = dir
		var who := _kb_target(inst)
		if who != "":
			Sync.submit({"k": "in", "pid": who, "m": {"t": "lr", "v": dir, "kb": true}})
	return true


## Kit irányít a gép billentyűzete: fejlesztői tesztbotot, ha van, különben az első játékost
## (online vendéggépen senkit, hogy ne vehesse át a hoszt játékosát).
func _kb_target(inst) -> String:
	for p in inst.players:
		if Net.is_bot(p.pid):
			return p.pid
	if Sync.client or inst.players.is_empty():
		return ""
	return inst.players[0].pid


## Billentyűzetes joystick a futós minijátékokban (Minigame.keyboard_stick): WASD / nyilak = „stick”,
## szóköz = „btn”, a _kb_target játékos nevében, a közös eseménysoron át.
const _KS_DIRS := {KEY_W: Vector2.UP, KEY_UP: Vector2.UP, KEY_S: Vector2.DOWN, KEY_DOWN: Vector2.DOWN,
	KEY_A: Vector2.LEFT, KEY_LEFT: Vector2.LEFT, KEY_D: Vector2.RIGHT, KEY_RIGHT: Vector2.RIGHT}
var _ks_keys := {}
var _ks_vec := Vector2.ZERO

func _keyboard_stick(event: InputEventKey) -> bool:
	var k: int = event.keycode
	var act := k == KEY_SPACE
	if not act and not _KS_DIRS.has(k):
		return false
	var inst = scene.get("inst") if scene and not scene.dead else null
	if inst == null or not is_instance_valid(inst) or not (inst is Minigame) or not inst.keyboard_stick():
		_ks_keys.clear()
		_ks_vec = Vector2.ZERO
		return false
	var who := _kb_target(inst)
	if who == "":
		return false
	if act:
		if event.pressed:
			Sync.submit({"k": "in", "pid": who, "m": {"t": "btn", "kb": true}})
		return true
	if event.pressed:
		_ks_keys[k] = _KS_DIRS[k]
	else:
		_ks_keys.erase(k)
	var v := Vector2.ZERO
	for d in _ks_keys.values():
		v += d
	v = v.limit_length(1.0)
	if v != _ks_vec:
		_ks_vec = v
		Sync.submit({"k": "in", "pid": who, "m": {"t": "stick", "x": snappedf(v.x, 0.01), "y": snappedf(v.y, 0.01), "kb": true}})
	return true


func screenshot(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("screenshot: ", ProjectSettings.globalize_path(path))


# ------------------------------------------------------------------ részecskék
func burst(x: float, y: float, o := {}) -> void:
	var n: int = o.get("n", 20)
	var fk := 1.0
	if fx_rect.size.x > 0.0:
		fk = fx_rect.size.x / 1280.0
		x = fx_rect.position.x + x * fk
		y = fx_rect.position.y + y * fk
	var colors: Array = o.get("colors", ["#ffd43b", "#ff4d6d", "#4dabf7", "#51cf66"])
	var speed: float = o.get("speed", 320.0) * fk
	var life: float = o.get("life", 0.9)
	var size: float = o.get("size", 7.0) * fk
	var spread: float = o.get("spread", TAU)
	var angle: float = o.get("angle", -PI / 2)
	for i in n:
		var a := angle + (FX.f() - 0.5) * spread
		var s := speed * (0.35 + FX.f() * 0.65)
		particles.append({"x": x, "y": y, "vx": cos(a) * s, "vy": sin(a) * s, "life": life * (0.6 + FX.f() * 0.4), "max": life,
			"size": size * (0.6 + FX.f() * 0.7), "color": Color(str(FX.pick(colors))), "shape": o.get("shape", "circle"),
			"g": o.get("gravity", 700.0), "drag": o.get("drag", 0.6), "rot": FX.f() * 6.0, "vr": FX.fr(-10, 10)})


## Ha nem üres: a részecskék 1280×720-as koordinátái ebbe a téglalapba kerülnek (próbakör kis képernyője).
var fx_rect := Rect2()


func float_text(x: float, y: float, s: String, color := Color.WHITE, size := 34) -> void:
	if fx_rect.size.x > 0.0:
		var fk := fx_rect.size.x / 1280.0
		x = fx_rect.position.x + x * fk
		y = fx_rect.position.y + y * fk
		size = int(size * max(fk, 0.6))
	particles.append({"x": x, "y": y, "vx": 0.0, "vy": -70.0, "life": 1.4, "max": 1.4, "size": size, "color": color,
		"shape": "text", "text": s, "g": 0.0, "drag": 0.0, "rot": 0.0, "vr": 0.0})


func confetti(n := 120) -> void:
	var cols := ["#ffd43b", "#ff4d6d", "#4dabf7", "#51cf66", "#b197fc", "#ff922b"]
	for i in n:
		particles.append({"x": FX.fr(0, 1280), "y": FX.fr(-200, -10), "vx": FX.fr(-60, 60), "vy": FX.fr(80, 260),
			"life": 4.0, "max": 4.0, "size": FX.fr(6, 12), "color": Color(FX.pick(cols)), "shape": "rect",
			"g": 60.0, "drag": 0.0, "rot": FX.fr(0, 6), "vr": FX.fr(-8, 8)})


func _update_particles(dt: float) -> void:
	var keep: Array = []
	for p in particles:
		p.life -= dt
		if p.life <= 0.0:
			continue
		p.vy += p.g * dt
		p.vx *= 1.0 - p.drag * dt
		p.vy *= 1.0 - p.drag * dt
		p.x += p.vx * dt
		p.y += p.vy * dt
		p.rot += p.vr * dt
		keep.append(p)
	particles = keep


func _draw_particles(c: CanvasItem) -> void:
	for p in particles:
		var a: float = min(1.0, p.life / (p.max * 0.4))
		var col: Color = p.color
		col.a = a
		if p.shape == "text":
			D.text(c, p.text, p.x, p.y, {"size": p.size, "color": col, "stroke": D.DARK, "sw": 7, "alpha": a})
		elif p.shape == "rect":
			c.draw_set_transform(Vector2(p.x, p.y), p.rot, Vector2.ONE)
			c.draw_rect(Rect2(-p.size / 2, -p.size / 4, p.size, p.size / 2), col)
			c.draw_set_transform(Vector2.ZERO)
		else:
			c.draw_circle(Vector2(p.x, p.y), p.size / 2, col)
