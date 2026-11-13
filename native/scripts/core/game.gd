extends Node
## A játék menete: lobby -> tábla -> minijáték -> ... -> végeredmény

var force_mg := ""
var test_start_node := 0     # --start-node=N: hegymászás teszteléséhez, a rajt helyett innen indul mindenki
var test_shots := false
var test_tiles := ""         # --tiles=F|P|X: teszthez a rajt utáni sima mezők mind ilyenek lesznek


func apply_args(args: PackedStringArray) -> void:
	for a in args:
		if a.begins_with("--rounds="):
			G.max_rounds = max(1, int(a.get_slice("=", 1)))
		elif a.begins_with("--mode="):
			var m := a.get_slice("=", 1)
			if G.MODES.any(func(x): return x.id == m):
				G.mode = m
		elif a.begins_with("--start-node="):
			test_start_node = int(a.get_slice("=", 1))
		elif a.begins_with("--tiles="):
			test_tiles = a.get_slice("=", 1)
		elif a.begins_with("--mg="):
			force_mg = a.get_slice("=", 1)
		elif a == "--small":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(Vector2i(960, 540))


func after_boot(args: PackedStringArray) -> void:
	var nb := 0
	var autostart := false
	var shots_dir := ""
	var shot_every := 3.0
	for a in args:
		if a.begins_with("--bots="):
			nb = clampi(int(a.get_slice("=", 1)), 0, 8)
		elif a == "--autostart":
			autostart = true
		elif a.begins_with("--speed="):
			Engine.time_scale = float(a.get_slice("=", 1))
		elif a.begins_with("--shots="):
			shots_dir = a.get_slice("=", 1)
		elif a.begins_with("--shot-every="):
			shot_every = float(a.get_slice("=", 1))
		elif a.begins_with("--portraits="):
			_render_portraits(a.get_slice("=", 1))
		elif a.begins_with("--join="):
			Sync.join(a.get_slice("=", 1))
		elif a == "--room":
			Sync.open_room()
		elif a == "--online-ui":
			Main.I.online.open.call_deferred()
		elif a == "--sync-log":
			Sync.verbose = true
		elif a.begins_with("--quit-at="):
			var q := float(a.get_slice("=", 1))
			get_tree().create_timer(q, true, false, true).timeout.connect(func(): get_tree().quit())
	for i in nb:
		Net.add_bot("Bot %d" % (i + 1))
	if autostart:
		get_tree().create_timer(1.5).timeout.connect(func(): Sync.submit({"k": "start"}))
	if shots_dir != "":
		DirAccess.make_dir_recursive_absolute(shots_dir)
		var n := [0]
		var tm := Timer.new()
		tm.wait_time = shot_every
		tm.ignore_time_scale = true
		add_child(tm)
		tm.timeout.connect(func():
			n[0] += 1
			var sc = Main.I.scene
			var nm: String = sc.get_script().get_global_name() if sc and sc.get_script() else "scene"
			if nm == "" and sc: nm = str(sc.get_script().resource_path.get_file().get_basename())
			Main.I.screenshot("%s/%03d_%s.png" % [shots_dir, n[0], nm]))
		tm.start()


## --portraits=id1,id2 (vagy all): a figurák portréit kirendereli a web/img/chars mappába, majd kilép.
func _render_portraits(which: String) -> void:
	var ids: Array = []
	for c in G.CHARS:
		if which == "all" or which.split(",").has(c.id):
			ids.append(c.id)
	var vp := SubViewport.new()
	vp.size = Vector2i(512, 512)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#dfe6ff")
	env.ambient_light_energy = 0.75
	we.environment = env
	vp.add_child(we)
	var cam := Camera3D.new()
	cam.fov = 26
	vp.add_child(cam)
	cam.position = Vector3(0, 0.95, 3.25)
	cam.look_at(Vector3(0, 0.6, 0))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, 28, 0)
	sun.light_energy = 1.25
	vp.add_child(sun)
	for id in ids:
		var m := Chars3D.build(id)
		m.rotation.y = -0.45
		vp.add_child(m)
		m.animate(0.016)
		for i in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.resize(256, 256, Image.INTERPOLATE_LANCZOS)
		img.save_png(ProjectSettings.globalize_path("res://web/img/chars/%s.png" % id))
		print("portré: ", id)
		m.queue_free()
		await get_tree().process_frame
	get_tree().quit()


func on_join(pid: String, pname: String, is_bot: bool) -> void:
	var p = G.by_pid(pid)
	var sc = Main.I.scene
	if p:
		p.connected = true
		if pname != "":
			p.name = pname
		Net.away.erase(pid)
		Net.resend_layout(pid)
		if sc: sc.players_changed()
		return
	if G.phase != "lobby" or G.players.size() >= G.MAX_PLAYERS:
		Net.set_ctrl(pid, {"mode": "wait", "icon": "⏳",
			"title": "A játék már folyik" if G.phase != "lobby" else "Megtelt a játék",
			"text": "Várd meg a következő játékot!"})
		return
	p = G.new_player(pid, pname, is_bot)
	G.players.append(p)
	update_vip()
	if sc: sc.players_changed()


func on_leave(pid: String) -> void:
	var p = G.by_pid(pid)
	if p == null:
		return
	p.connected = false
	if G.phase == "lobby":
		G.players.erase(p)
		update_vip()
	else:
		Net.mark_away(pid)
	var sc = Main.I.scene
	if sc: sc.players_changed()


func update_vip() -> void:
	for p in G.humans():
		if p.pid == G.vip:
			return
	var h := G.humans()
	G.vip = h[0].pid if h.size() else ""


func go_lobby() -> void:
	G.phase = "lobby"
	G.players = G.players.filter(func(p): return p.connected or p.is_bot)
	for p in G.players:
		p.ready = p.is_bot
	update_vip()
	Main.I.set_scene(LobbyScene.new())


func start_game() -> void:
	G.phase = "board"
	if G.board == null:
		G.board = BoardLayout.build()
	G.round = 1
	G.recent_mg = []
	G.players.shuffle()
	for p in G.players:
		p.reset()
		p.node = G.board.start
	G.crown_node = -1
	G.mtn_winner = null
	G.mountain = null
	G.team_split = []
	if G.is_mountain():
		G.mountain = MountainLayout.build()
		if test_tiles != "":
			for nd in G.mountain.nodes:
				if nd.type == "N" and nd.id > test_start_node and nd.id < test_start_node + 14:
					nd.type = test_tiles
					nd.val = 2
		G.mtn_order = G.players.duplicate()
		for p in G.players:
			p.node = clampi(test_start_node, 0, G.mountain.goal - 1)
		if force_mg != "":
			Main.I.set_scene(MgFlow.SelectScene.new(force_mg))
			return
		Main.I.set_scene(MountainScene.new(true))
		return
	G.hidden_blocks = BoardLayout.place_hidden_blocks(G.board)
	if force_mg != "":
		Main.I.set_scene(MgFlow.SelectScene.new(force_mg))
		return
	Main.I.set_scene(BoardScene.new(true))


func after_minigame() -> void:
	if G.is_mountain():
		# hegymászásnál a kör a minijátékkal kezdődik, utána jön a dobás
		Main.I.set_scene(MountainScene.new(false))
		return
	G.round += 1
	if G.round > G.max_rounds:
		G.phase = "final"
		Main.I.set_scene(FinalScene.new())
	else:
		Main.I.set_scene(BoardScene.new(false))
