class_name OnlineUI
extends Control
## Az online játék kezelőfelülete: gomb a lobbyban, panel a szoba megnyitásához / csatlakozáshoz,
## és egy kis állapotjelző játék közben. Ez gépenként külön él, nem része a közös játékállapotnak.

const CFG := "user://online.cfg"
const YELLOW := Color("#ffd43b")
const SOFT := Color("#cfc6f5")

var _btn: Button
var _badge: Label
var _dim: ColorRect
var _host_info: RichTextLabel
var _open_btn: Button
var _edit: LineEdit
var _join_btn: Button
var _leave_btn: Button
var _join_info: Label
var _err_t := -100.0
var _last_err := ""
var _saved := ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS

	_btn = _button("", Rect2(50, 636, 380, 32), Color("#4b3a8a"), 16)
	_btn.pressed.connect(open)
	add_child(_btn)

	_badge = _label("", Rect2(340, 6, 600, 30), 18, YELLOW, true)
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge.add_theme_color_override("font_outline_color", D.DARK)
	_badge.add_theme_constant_override("outline_size", 8)
	_badge.visible = false
	add_child(_badge)

	_dim = ColorRect.new()
	_dim.color = Color(0.03, 0.02, 0.1, 0.8)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.visible = false
	add_child(_dim)

	var panel := Panel.new()
	panel.position = Vector2(170, 70)
	panel.size = Vector2(940, 580)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.06, 0.25, 0.98)
	sb.border_color = YELLOW
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(30)
	panel.add_theme_stylebox_override("panel", sb)
	_dim.add_child(panel)

	var title := _label("🌐 Online játék", Rect2(0, 16, 940, 54), 40, Color.WHITE, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)
	var sub := _label("Mindenki a saját gépén futtatja és látja a játékot – nincs képernyőmegosztás, nincs késés. "
		+ "A telefonját mindenki a saját képernyőjén lévő QR-kóddal csatlakoztatja.", Rect2(50, 74, 840, 56), 17, SOFT)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.size = Vector2(840, 56)     # a tördelés bekapcsolása után újra, különben a szöveg szélességére nyúlik
	panel.add_child(sub)

	# bal oldal: szoba nyitása
	panel.add_child(_label("🏠 Én nyitom a szobát", Rect2(40, 142, 410, 34), 25, YELLOW, true))
	_host_info = RichTextLabel.new()
	_host_info.bbcode_enabled = true
	_host_info.position = Vector2(40, 182)
	_host_info.size = Vector2(410, 262)
	_host_info.scroll_active = false
	_host_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_host_info.add_theme_font_size_override("normal_font_size", 17)
	_host_info.add_theme_font_size_override("bold_font_size", 17)
	_host_info.add_theme_font_override("bold_font", D.font)
	_host_info.add_theme_color_override("default_color", Color("#e9e4ff"))
	panel.add_child(_host_info)
	_open_btn = _button("", Rect2(40, 452, 410, 50), Color("#51cf66"), 21)
	_open_btn.add_theme_color_override("font_color", Color("#12331a"))
	_open_btn.add_theme_color_override("font_hover_color", Color("#12331a"))
	_open_btn.add_theme_color_override("font_pressed_color", Color("#12331a"))
	_open_btn.pressed.connect(_on_open_pressed)
	panel.add_child(_open_btn)

	var sep := ColorRect.new()
	sep.color = Color(1, 1, 1, 0.14)
	sep.position = Vector2(469, 146)
	sep.size = Vector2(2, 356)
	panel.add_child(sep)

	# jobb oldal: csatlakozás
	panel.add_child(_label("🚪 Csatlakozom egy szobához", Rect2(490, 142, 410, 34), 25, YELLOW, true))
	panel.add_child(_label("Szobakód vagy IP-cím:", Rect2(490, 186, 410, 26), 17, SOFT))
	_edit = LineEdit.new()
	_edit.position = Vector2(490, 216)
	_edit.size = Vector2(410, 56)
	_edit.placeholder_text = "pl. ABC-DEFG"
	_edit.max_length = 80
	_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_edit.add_theme_font_size_override("font_size", 28)
	_edit.add_theme_font_override("font", D.font)
	var eb := StyleBoxFlat.new()
	eb.bg_color = Color(1, 1, 1, 0.1)
	eb.border_color = Color(1, 1, 1, 0.35)
	eb.set_border_width_all(2)
	eb.set_corner_radius_all(16)
	_edit.add_theme_stylebox_override("normal", eb)
	var ef: StyleBoxFlat = eb.duplicate()
	ef.border_color = YELLOW
	_edit.add_theme_stylebox_override("focus", ef)
	_edit.text_submitted.connect(func(_t): _on_join_pressed())
	panel.add_child(_edit)
	_join_btn = _button("Csatlakozás", Rect2(490, 284, 410, 50), Color("#4dabf7"), 21)
	_join_btn.pressed.connect(_on_join_pressed)
	panel.add_child(_join_btn)
	_join_info = _label("", Rect2(490, 344, 410, 100), 17, Color("#e9e4ff"))
	_join_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_join_info.size = Vector2(410, 100)
	panel.add_child(_join_info)
	_leave_btn = _button("Kilépés a szobából", Rect2(490, 452, 410, 50), Color("#ff6b6b"), 21)
	_leave_btn.pressed.connect(func(): Sync.leave())
	panel.add_child(_leave_btn)

	var close_btn := _button("Bezárás (Esc)", Rect2(370, 518, 200, 44), Color("#4b3a8a"), 18)
	close_btn.pressed.connect(close)
	panel.add_child(close_btn)

	var cfg := ConfigFile.new()
	if cfg.load(CFG) == OK:
		_saved = str(cfg.get_value("online", "last", ""))
		_edit.text = _saved
	Sync.changed.connect(_refresh)
	_refresh()


func _label(text: String, r: Rect2, size: int, color: Color, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.position = r.position
	l.size = r.size
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", D.font)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, r: Rect2, color: Color, size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.position = r.position
	b.size = r.size
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = true
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_font_override("font", D.font)
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = color
		if st == "hover": sb.bg_color = D.shade(color, 0.18)
		elif st == "pressed": sb.bg_color = D.shade(color, -0.2)
		elif st == "disabled": sb.bg_color = Color(color.r, color.g, color.b, 0.35)
		sb.set_corner_radius_all(int(r.size.y / 2))
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		b.add_theme_stylebox_override(st, sb)
	return b


func is_open() -> bool:
	return _dim.visible


func open() -> void:
	_dim.visible = true
	_refresh()
	if not Sync.client:
		_edit.grab_focus()


func close() -> void:
	_edit.release_focus()
	_dim.visible = false


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if is_open():
		if event.keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()
	elif event.keycode == KEY_O:
		open()
		get_viewport().set_input_as_handled()


func _on_open_pressed() -> void:
	if Sync.upnp_state == "ok":
		DisplayServer.clipboard_set(Sync.make_code(Sync.public_ip, Sync.port()))
		_open_btn.text = "✔ Kimásolva!"
		get_tree().create_timer(1.2, true, false, true).timeout.connect(_refresh)
	else:
		Sync.open_room()


func _on_join_pressed() -> void:
	if Sync.join(_edit.text):
		_edit.release_focus()


func _process(_dt: float) -> void:
	_btn.visible = G.phase == "lobby" and not is_open()
	if _btn.visible:
		if Sync.client:
			_btn.text = "🌐 Vendég vagy egy szobában – beállítás"
		elif Sync.pc_count() > 0:
			_btn.text = "🌐 Online szoba: %d gép csatlakozva" % Sync.pc_count()
		else:
			_btn.text = "🌐 Online játék másik géppel"
	if Sync.error != _last_err:
		_last_err = Sync.error
		if _last_err != "":
			_err_t = Main.I.time if Main.I else 0.0
	var badge := ""
	if Sync.state() == "retry":
		badge = "🔌 Megszakadt a kapcsolat – újracsatlakozás…"
	elif Sync.client and Sync.catching:
		badge = "⏩ Felzárkózás a játékhoz…"
	elif Sync.state() == "connecting" and not is_open():
		badge = "⏳ Csatlakozás a szobához…"
	elif _last_err != "" and not is_open() and Main.I and Main.I.time - _err_t < 8.0:
		badge = "❌ " + _last_err
	_badge.text = badge
	_badge.visible = badge != ""
	if is_open():
		_refresh()
	if Sync.state() == "online" and _edit.text != "" and _edit.text != _saved:
		_saved = _edit.text
		var cfg := ConfigFile.new()
		cfg.set_value("online", "last", _saved)
		cfg.save(CFG)


func _refresh() -> void:
	if _host_info == null:
		return
	var port := Sync.port()
	var port_txt := "" if port == Sync.DEFAULT_PORT else ":%d" % port
	var t := ""
	if Sync.client:
		t = "Most vendég vagy egy másik szobában, ezért hozzád nem lehet csatlakozni."
	else:
		var lan := Sync.lan_ip()
		if lan != "":
			t += "[b]Egy hálózaton vagy VPN-nel[/b] (Radmin VPN, Tailscale, Hamachi) elég a géped címe:\n[color=#ffd43b][b]%s%s[/b][/color]\n\n" % [lan, port_txt]
		match Sync.upnp_state:
			"working":
				t += "[b]Interneten át:[/b] ⏳ egyeztetés a routerrel…"
			"ok":
				t += "[b]Interneten át:[/b] ✅ a szoba nyitva! Ezt a kódot mondd be a barátaidnak:\n[font_size=46][color=#ffd43b][b]%s[/b][/color][/font_size]\n[color=#a99fd6](cím: %s:%d)[/color]" % [
					Sync.make_code(Sync.public_ip, port), Sync.public_ip, port]
			"fail":
				t += "[b]Interneten át:[/b] ❌ %s\n[color=#a99fd6]Megoldás: a routeren irányítsd a %d-es TCP portot erre a gépre, vagy használjatok ingyenes VPN-t, és a fenti helyett a VPN-ben látott címedet add meg.[/color]" % [Sync.upnp_msg, port]
			_:
				t += "[b]Interneten át:[/b] nyomd meg a lenti gombot – a játék megkéri a routert, hogy engedje be a barátaidat, és kapsz egy szobakódot."
		if Sync.pc_count() > 0:
			t += "\n\n[color=#69db7c]🖥️ Csatlakozott gépek: %d[/color]" % Sync.pc_count()
	_host_info.text = t
	_open_btn.visible = not Sync.client
	_open_btn.disabled = Sync.upnp_state == "working"
	match Sync.upnp_state:
		"working": _open_btn.text = "Egy pillanat…"
		"ok": _open_btn.text = "📋 Kód másolása"
		"fail": _open_btn.text = "Újrapróbálom"
		_: _open_btn.text = "Szoba megnyitása az interneten"

	var j := ""
	match Sync.state():
		"connecting": j = "⏳ Csatlakozás ide: %s…" % Sync.address()
		"retry": j = "🔌 Megszakadt a kapcsolat, újrapróbálkozás…"
		"online":
			j = "✅ Csatlakozva: %s\nA játékot a szoba gazdája indítja. A telefonodat a saját képernyőd QR-kódjával csatlakoztasd." % Sync.address()
			if Sync.catching:
				j += "\n⏩ Felzárkózás a játékhoz…"
		_:
			if Sync.error != "":
				j = "❌ " + Sync.error
			else:
				j = "Kérd el a szoba gazdájától a kódot vagy a címét. Mindenkinek ugyanaz a játékverzió kell (a tiéd: %s)." % Sync.version
	_join_info.text = j
	var busy := Sync.state() != ""
	_join_btn.disabled = Sync.state() == "connecting"
	_leave_btn.visible = busy
	_leave_btn.text = "Mégse" if Sync.state() == "connecting" else "Kilépés a szobából"
