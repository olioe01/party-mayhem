class_name Minigame
extends Node3D
## Minijáték-alaposztály. Az egyes minijátékok ezt bővítik.
## A META leírja a nevet, ikont, leírást, irányítást; a layout(p) a telefonos kontroller elrendezése.

var players: Array = []
var teams: Array = []        # [] = mindenki mindenki ellen, különben [[p..], [p..]]
var finished := false
var t := 0.0
var cam: Camera3D
var env: Environment


func setup(p_players: Array, p_teams: Array) -> void:
	players = p_players
	teams = p_teams


## csapat indexe (0 = kék, 1 = piros), vagy -1
func team_of(p) -> int:
	for i in teams.size():
		if teams[i].has(p):
			return i
	return -1


func meta() -> Dictionary: return {}
func layout(_p) -> Dictionary: return {"mode": "wait", "title": "Figyeld a képernyőt!"}
func start() -> void: pass
func idle(_dt: float) -> void: pass
func update(_dt: float) -> void: pass
func bot(_p, _dt: float) -> void: pass
func input(_p, _msg: Dictionary) -> void: pass
func draw(_c: CanvasItem) -> void: pass
## [{pid, score, label}] csökkenő sorrendben
func ranking() -> Array: return []


# ------------------------------------------------------------------ közös 3D segédek
func make_env(top := "#1e3a8a", horizon := "#93c5fd", ambient := 0.8) -> void:
	env = Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(top)
	sm.sky_horizon_color = Color(horizon)
	sm.ground_bottom_color = Color(top).darkened(0.4)
	sm.ground_horizon_color = Color(horizon)
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = ambient
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_hdr_threshold = 1.0
	env.ssao_enabled = true
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1
	Main.I.world_env.environment = env


func make_camera(pos: Vector3, look: Vector3, fov := 45.0) -> Camera3D:
	cam = Camera3D.new()
	cam.fov = fov
	add_child(cam)
	cam.position = pos
	cam.look_at(look, Vector3.UP)
	cam.make_current()
	return cam


func make_sun(rot := Vector3(-55, -30, 0), energy := 1.2, color := "#fff1d6") -> DirectionalLight3D:
	var s := DirectionalLight3D.new()
	s.rotation_degrees = rot
	s.light_energy = energy
	s.light_color = Color(color)
	s.shadow_enabled = true
	s.directional_shadow_max_distance = 60.0
	add_child(s)
	return s


func screen(p3: Vector3) -> Vector2:
	if cam == null or cam.is_position_behind(p3):
		return Vector2(-999, -999)
	return cam.unproject_position(p3)


func player_model(p, scale := 1.0) -> Chars3D.CharModel:
	var m := Chars3D.build(p.char_id)
	m.scale = Vector3.ONE * scale
	add_child(m)
	return m


func color_disc(p, r := 0.4) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = r
	cy.bottom_radius = r * 1.05
	cy.height = 0.06
	mi.mesh = cy
	mi.material_override = Chars3D.mat(p.color_hex, {"rough": 0.4})
	return mi


## egyszerű ranglista pontszám szerint
func rank_by(score_of: Callable, label_of: Callable) -> Array:
	var out: Array = []
	for p in players:
		out.append({"pid": p.pid, "score": score_of.call(p), "label": label_of.call(p)})
	out.sort_custom(func(a, b): return a.score > b.score)
	return out


func bg(c: CanvasItem, hue := 265.0) -> void:
	var top := Color.from_hsv(hue / 360.0, 0.6, 0.35)
	var bot := Color.from_hsv(fmod(hue + 30.0, 360.0) / 360.0, 0.7, 0.1)
	D.vgrad(c, top, bot)
	for i in 14:
		var x := fmod(i * 137.0 + Main.I.time * 30.0, 1480.0) - 100.0
		c.draw_circle(Vector2(x, fmod(i * 211.0, 720.0)), 40.0 + (i % 4) * 30.0, Color(1, 1, 1, 0.07))
