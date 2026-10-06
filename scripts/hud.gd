class_name Hud
extends CanvasLayer

var root: Control
var l_enemy: Label
var l_score: Label
var l_combo: Label
var l_hp: Label
var l_hint: Label
var l_tip: Label
var l_sub_name: Label
var l_sub: Label
var l_banner: Label
var l_banner_sub: Label
var l_start: Label
var l_ctrl: Label
var l_title: Label
var l_end: Label
var boss_root: Control
var boss_fill: ColorRect
var boss_name: Label
var fade: ColorRect
var hurt: ColorRect
var fade_a := 1.0
var fade_to_a := 1.0
var fade_speed := 1.0
var sub_t := 0.0
var tip_t := 0.0
var banner_t := 0.0
var combo_punch := 0.0
var hurt_a := 0.0
var pops: Array = []
var hint_phase := 0.0


func _label(size: int, col: Color, halign: int, valign: int, outline: int = 8) -> Label:
	var l := Label.new()
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.offset_left = 28
	l.offset_right = -28
	l.offset_top = 18
	l.offset_bottom = -18
	l.horizontal_alignment = halign as HorizontalAlignment
	l.vertical_alignment = valign as VerticalAlignment
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	l.add_theme_constant_override("outline_size", outline)
	root.add_child(l)
	return l


func setup() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var C := HORIZONTAL_ALIGNMENT_CENTER
	var L := HORIZONTAL_ALIGNMENT_LEFT
	var R := HORIZONTAL_ALIGNMENT_RIGHT
	var T := VERTICAL_ALIGNMENT_TOP
	var B := VERTICAL_ALIGNMENT_BOTTOM
	var M := VERTICAL_ALIGNMENT_CENTER
	l_enemy = _label(40, Color(1, 1, 1), C, T)
	l_score = _label(30, Color(1, 0.95, 0.6), R, T)
	l_combo = _label(56, Color(1, 0.85, 0.15), R, M, 12)
	l_combo.offset_top = -120
	l_hp = _label(30, Color(1, 0.4, 0.45), L, B)
	l_hint = _label(30, Color(1, 1, 1), C, B)
	l_hint.offset_bottom = -22
	l_tip = _label(30, Color(1, 0.95, 0.7), C, T)
	l_tip.offset_top = 78
	l_sub_name = _label(24, Color(0.7, 0.9, 1.0), C, B)
	l_sub_name.offset_bottom = -170
	l_sub = _label(40, Color(1, 1, 1), C, B, 10)
	l_sub.offset_bottom = -110
	l_banner = _label(110, Color(1, 0.9, 0.3), C, M, 16)
	l_banner.offset_bottom = -40
	l_banner_sub = _label(38, Color(1, 1, 1), C, M)
	l_banner_sub.offset_top = 90
	l_start = _label(46, Color(1, 1, 1), C, M, 10)
	l_start.text = "ある日の電車で…\n\nクリックではじめる"
	l_ctrl = _label(24, Color(0.9, 0.9, 0.95), C, B)
	l_ctrl.offset_bottom = -26
	l_ctrl.text = "A / D：歩く　W / S：上の席・下の席　E：倒す／起こす　R：回す（左クリック＝E、右クリック＝R）"
	# ボスのHPバー
	boss_root = Control.new()
	boss_root.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	boss_root.offset_left = -320
	boss_root.offset_right = 320
	boss_root.offset_top = 70
	boss_root.offset_bottom = 120
	boss_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_root.visible = false
	root.add_child(boss_root)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.position = Vector2(0, 26)
	bg.size = Vector2(640, 22)
	boss_root.add_child(bg)
	boss_fill = ColorRect.new()
	boss_fill.color = Color(0.9, 0.2, 0.2)
	boss_fill.position = Vector2(3, 29)
	boss_fill.size = Vector2(634, 16)
	boss_root.add_child(boss_fill)
	boss_name = Label.new()
	boss_name.text = "絶対に席を動かさない男"
	boss_name.add_theme_font_size_override("font_size", 24)
	boss_name.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	boss_name.add_theme_constant_override("outline_size", 6)
	boss_name.position = Vector2(0, -6)
	boss_root.add_child(boss_name)
	hurt = ColorRect.new()
	hurt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hurt.color = Color(1, 0.1, 0.1, 0)
	hurt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hurt)
	fade = ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0, 0, 0, 1)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)
	l_title = _label(84, Color(1, 1, 1), C, M, 0)
	l_title.offset_bottom = -30
	l_end = _label(30, Color(0.8, 0.8, 0.85), C, M, 0)
	l_end.offset_top = 150
	for l in [l_enemy, l_score, l_combo, l_hp, l_hint, l_tip, l_sub_name, l_sub, l_banner, l_banner_sub, l_start, l_ctrl]:
		var lb: Label = l
		if lb != l_start and lb != l_ctrl:
			lb.text = ""
	l_title.text = ""
	l_end.text = ""
	l_title.visible = false
	l_end.visible = false
	l_start.visible = false
	l_ctrl.visible = false


func set_enemies(n: int, show: bool = true) -> void:
	l_enemy.text = ("のこり  " + str(n)) if show else ""


func set_score(v: int) -> void:
	l_score.text = "SCORE  " + str(v).pad_zeros(6)


func set_hp(n: int) -> void:
	var s := "HP  "
	for i in 5:
		s += "●" if i < n else "○"
	l_hp.text = s


func hp_visible(b: bool) -> void:
	l_hp.visible = b


func set_combo(n: int) -> void:
	if n >= 2:
		l_combo.text = "SEAT COMBO ×" + str(n)
		combo_punch = 1.0
	else:
		l_combo.text = ""


func hint(s: String) -> void:
	l_hint.text = s


func tip(s: String, secs: float = 5.0) -> void:
	l_tip.text = s
	tip_t = secs


func subtitle(who: String, s: String, secs: float = 2.5) -> void:
	l_sub_name.text = who
	l_sub.text = s
	sub_t = secs


func banner(s: String, sub: String = "", secs: float = 1.6) -> void:
	l_banner.text = s
	l_banner_sub.text = sub
	banner_t = secs


func fade_to(a: float, secs: float) -> void:
	fade_to_a = a
	fade_speed = absf(a - fade_a) / maxf(secs, 0.01)


func show_start(b: bool) -> void:
	l_start.visible = b
	l_ctrl.visible = b


func title_card(b: bool, end_text: String = "") -> void:
	l_title.visible = b
	l_end.visible = b
	l_title.text = "シート倒してもいいですか？" if b else ""
	l_end.text = end_text


func boss_bar(show: bool, frac: float = 1.0) -> void:
	boss_root.visible = show
	l_tip.offset_top = 128 if show else 78
	boss_fill.size.x = 634.0 * clampf(frac, 0.0, 1.0)


func flash_hurt() -> void:
	hurt_a = 0.45


func pop(s: String, wpos: Vector3, col: Color, size: int = 48) -> void:
	var l := Label.new()
	l.text = s
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	l.add_theme_constant_override("outline_size", 12)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(l)
	pops.append({"l": l, "p": wpos, "t": 0.0, "rot": randf_range(-0.2, 0.2)})


func clear_pops() -> void:
	for d in pops:
		var l: Label = d.l
		l.queue_free()
	pops.clear()


func tick(dt: float, cam: Camera3D) -> void:
	fade_a = move_toward(fade_a, fade_to_a, fade_speed * dt)
	fade.color.a = fade_a
	if hurt_a > 0.0:
		hurt_a = maxf(0.0, hurt_a - dt * 1.4)
		hurt.color.a = hurt_a
	if sub_t > 0.0:
		sub_t -= dt
		if sub_t <= 0.0:
			l_sub.text = ""
			l_sub_name.text = ""
	if tip_t > 0.0:
		tip_t -= dt
		if tip_t <= 0.0:
			l_tip.text = ""
	if banner_t > 0.0:
		banner_t -= dt
		var a := clampf(banner_t / 0.4, 0.0, 1.0)
		l_banner.modulate.a = a
		l_banner_sub.modulate.a = a
		if banner_t <= 0.0:
			l_banner.text = ""
			l_banner_sub.text = ""
	hint_phase += dt
	l_hint.modulate.a = 0.75 + 0.25 * sin(hint_phase * 6.0)
	if combo_punch > 0.0:
		combo_punch = maxf(0.0, combo_punch - dt * 4.0)
	var s := 1.0 + 0.35 * combo_punch
	l_combo.pivot_offset = Vector2(l_combo.size.x - 28.0, l_combo.size.y * 0.5)
	l_combo.scale = Vector2(s, s)
	# ポップアップ（オノマトペ）
	var keep: Array = []
	for d in pops:
		var l: Label = d.l
		d.t += dt
		var life := 0.85
		if d.t >= life or cam == null:
			l.queue_free()
			continue
		var sp := cam.unproject_position(d.p)
		var u: float = d.t / life
		var pop_s := 1.0 + 0.8 * maxf(0.0, 1.0 - u * 6.0)
		l.pivot_offset = l.size * 0.5
		l.scale = Vector2(pop_s, pop_s)
		l.rotation = d.rot
		l.position = sp - l.size * 0.5 + Vector2(0, -60.0 * u)
		l.modulate.a = 1.0 - maxf(0.0, (u - 0.6) / 0.4)
		keep.append(d)
	pops = keep
