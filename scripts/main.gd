extends Node3D

const PLAYER_SPEED := 3.8
const STAGES := {
	1: {"speed": 1.25, "att": 1, "spawns": [0.8]},
	2: {"speed": 1.5, "att": 1, "spawns": [0.8, 3.2, 5.8]},
	3: {"speed": 1.7, "att": 2, "spawns": [0.8, 1.7, 2.6, 8.0, 8.9, 15.0, 15.9]},
}
const BOSS_ROW := 5

var args := {}
var autoplay := false
var fast := 1
var sim_time := 0.0
var hit_stop_t := 0.0
var slow_t := 0.0
var slow_scale := 1.0
var any_press := false
var mode := "title"
var gate := ""

var cam: Camera3D
var hud: Hud
var seats: Array[Seat] = []
var enemies: Array[Enemy] = []
var car := {}
var hero := {}
var hero_pos := Vector3(0.77, 0.0, 2.9)
var hero_hp := 5
var hero_inv := 0.0
var hero_vel := Vector3.ZERO
var hero_down := false
var hero_seated := true
var hero_goal := Vector3.ZERO
var hero_auto := false
var hero_face := 0.0
var hero_phase := 0.0
var hero_seat: Seat
var passenger := {}
var nod_t := 0.0
var boss: Enemy
var boss_seat: Seat
var boss_active := false
var boss_down := false
var boss_sit_pos := Vector3.ZERO
var target: Seat = null
var side_pref := 1
var marker: Label3D
var score := 0
var combo := 0
var combo_t := 0.0
var rotate_unlocked := false
var shake := 0.0
var look_z := 0.3
var cam_fov := 33.0
var attackers := 0
var max_attackers := 1
var spawn_queue: Array = []
var enemy_speed := 1.4
var door_t := 0.0
var door_open := 0.0
var stage := 0
var kills := 0
var variant_i := 0
var bot_next := 0.0
var shot_i := 0
var dbg_i := 0
var cam_pan_t := 0.0
var shot_times: Array = []
var shot_dir := ""
var max_t := 0.0

var hit_texts := ["ドン！", "ゴン！", "ガン！", "ボコッ！"]


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.lstrip("-").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	autoplay = args.has("autoplay")
	fast = int(args.get("fast", "1"))
	if args.has("shots"):
		shot_dir = args["shots"]
		for s in String(args.get("at", "1")).split(","):
			shot_times.append(float(s))
	max_t = float(args.get("maxt", "0"))
	_setup_input()
	_build_world()
	hud = Hud.new()
	add_child(hud)
	hud.setup()
	hud.set_score(0)
	hud.set_hp(5)
	hud.hp_visible(false)
	hud.set_enemies(0, false)
	run_game()


func _setup_input() -> void:
	_act("mv_l", [KEY_A, KEY_LEFT])
	_act("mv_r", [KEY_D, KEY_RIGHT])
	_act("mv_u", [KEY_W, KEY_UP])
	_act("mv_d", [KEY_S, KEY_DOWN])
	_act("use", [KEY_E, KEY_SPACE], [MOUSE_BUTTON_LEFT])
	_act("rot", [KEY_R, KEY_SHIFT], [MOUSE_BUTTON_RIGHT])


func _act(n: String, keys: Array, mouse: Array = []) -> void:
	if not InputMap.has_action(n):
		InputMap.add_action(n)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(n, ev)
	for b in mouse:
		var m := InputEventMouseButton.new()
		m.button_index = b
		InputMap.action_add_event(n, m)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		any_press = true
	elif event is InputEventMouseButton and event.pressed:
		any_press = true


# ---------------------------------------------------------------- ワールド構築

func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.6, 0.8, 0.96)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.8, 0.9)
	env.ambient_light_energy = 0.75
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58.0, 35.0, 0.0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 22.0
	add_child(sun)
	cam = Camera3D.new()
	cam.fov = cam_fov
	cam.far = 80.0
	add_child(cam)
	car = Models.build_car(self)
	for s in [-1, 1]:
		for r in Cfg.ROWS:
			var st := Seat.new()
			add_child(st)
			st.setup(self, s, r)
			seats.append(st)
	hero_seat = seat_at(1, 1)
	boss_seat = seat_at(-1, BOSS_ROW)
	boss_seat.locked = true
	# 乗客
	var spots := [
		[-1, 0, 0.28], [-1, 0, -0.28], [1, 0, -0.28], [1, 1, 0.28], [1, 2, 0.28],
		[-1, 2, -0.28], [1, 3, 0.28], [-1, 3, -0.28], [1, 5, 0.28], [-1, 7, 0.28],
		[1, 7, -0.28], [1, 8, 0.28], [-1, 8, -0.28], [-1, 4, 0.28],
	]
	var shirts := [Color(0.9, 0.7, 0.75), Color(0.75, 0.85, 0.7), Color(0.95, 0.9, 0.6), Color(0.8, 0.75, 0.9), Color(0.7, 0.85, 0.9)]
	var i := 0
	for sp in spots:
		var p := Models.person(shirts[i % shirts.size()], Color(0.3, 0.3, 0.38), Color(0.15 + 0.1 * float(i % 3), 0.1, 0.08))
		Models.sit(p, seat_at(sp[0], sp[1]), sp[2])
		i += 1
	var pas := Models.person(Color(0.55, 0.55, 0.6), Color(0.25, 0.25, 0.3), Color(0.12, 0.1, 0.1))
	Models.sit(pas, seat_at(1, 2), -0.28)
	passenger = pas
	hero = Models.person(Color(0.35, 0.9, 0.3), Color(0.22, 0.24, 0.34), Color(0.22, 0.12, 0.06))
	add_child(hero.root)
	Models.sit(hero, hero_seat, -0.28)
	# ボス（最初から座っている）
	boss = Enemy.new()
	add_child(boss)
	boss.setup(self, true, 0)
	boss_sit_pos = Vector3(boss_seat.position.x, -0.08, boss_seat.position.z + 0.02)
	_boss_to_seat()
	# 狙っている席の目印
	marker = Label3D.new()
	marker.text = "▼"
	marker.font = load("res://fonts/NotoSansJP-Bold-subset.ttf")
	marker.font_size = 120
	marker.pixel_size = 0.006
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.no_depth_test = true
	marker.modulate = Color(1.0, 0.9, 0.15)
	marker.outline_size = 24
	marker.outline_modulate = Color(0, 0, 0)
	marker.shaded = false
	marker.visible = false
	add_child(marker)


func _boss_to_seat() -> void:
	boss.position = boss_sit_pos
	boss.st = Enemy.S.SIT
	boss.hp = boss.max_hp
	boss.final_ready = false
	boss.final_flight = false
	boss.vel = Vector3.ZERO
	boss.face_yaw = 0.0
	boss.sq_front = -99.0
	boss.sq_back = -99.0
	boss.counted = false
	boss.rig.root.rotation = Vector3.ZERO
	boss.rig.root.position = Vector3.ZERO
	boss.rig.root.scale = Vector3.ONE * boss.sc
	boss.stars.visible = false
	boss_seat.locked = true
	boss_active = false
	boss_down = false


func seat_at(side: int, row: int) -> Seat:
	return seats[(0 if side < 0 else 1) * Cfg.ROWS + row]


# ---------------------------------------------------------------- メインループ

func _process(delta: float) -> void:
	var rd := minf(delta, 0.05)
	hud.tick(rd, cam)
	if hit_stop_t > 0.0:
		hit_stop_t -= rd
		slow_scale = 0.03
	elif slow_t > 0.0:
		slow_t -= rd
		slow_scale = clampf(slow_scale, 0.05, 1.0)
	else:
		slow_scale = 1.0
	var inp := _bot() if autoplay else _read_input()
	for i in fast:
		if i > 0:
			inp.use = false
			inp.rot = false
		_sim_step(rd * (slow_scale if (hit_stop_t > 0.0 or slow_t > 0.0) else 1.0), inp)
	if shot_times.size() > 0 and shot_i < shot_times.size() and sim_time >= float(shot_times[shot_i]):
		var img := get_viewport().get_texture().get_image()
		img.save_png(shot_dir + "/shot_" + str(shot_i) + ".png")
		shot_i += 1
	if max_t > 0.0 and sim_time > max_t:
		print("maxt reached mode=", mode, " stage=", stage, " score=", score, " hp=", hero_hp)
		get_tree().quit()


func _read_input() -> Dictionary:
	var mv := Vector2.ZERO
	mv.y = Input.get_action_strength("mv_l") - Input.get_action_strength("mv_r")
	mv.x = Input.get_action_strength("mv_d") - Input.get_action_strength("mv_u")
	return {"mv": mv, "use": Input.is_action_just_pressed("use"), "rot": Input.is_action_just_pressed("rot")}


func _sim_step(dt: float, inp: Dictionary) -> void:
	sim_time += dt
	if combo_t > 0.0:
		combo_t -= dt
		if combo_t <= 0.0:
			combo = 0
			hud.set_combo(0)
	for s in seats:
		s.tick(dt)
	_update_hero(dt, inp)
	for e in enemies:
		e.tick(dt)
	if boss != null and not boss_active:
		boss.tick(dt)
	_enemy_interactions()
	_update_world(dt)
	_update_target()
	if inp.use:
		handle_use()
	if inp.rot:
		handle_rot()
	_update_camera(dt)
	if nod_t > 0.0:
		nod_t -= dt
		var hd: Node3D = passenger.head
		hd.rotation.x = sin(PI * (1.0 - clampf(nod_t / 0.7, 0.0, 1.0))) * 0.45
	shake = maxf(0.0, shake - dt * 1.8)
	if mode == "fight":
		hud.set_enemies(alive_count() + spawn_queue.size())
		if boss_active:
			hud.boss_bar(true, float(maxi(boss.hp, 0)) / float(boss.max_hp))


func _update_world(dt: float) -> void:
	var sc: Array = car.scenery
	for b in sc:
		var n: Node3D = b
		n.position.z -= 16.0 * dt
		if n.position.z < -17.0:
			n.position.z += 34.0
	var want := 1.0 if door_t > 0.0 else 0.0
	door_t = maxf(0.0, door_t - dt)
	door_open = move_toward(door_open, want, dt * 3.0)
	var dl: Node3D = car.doorL
	var dr: Node3D = car.doorR
	dl.position.x = -0.25 - 0.5 * door_open
	dr.position.x = 0.25 + 0.5 * door_open


func _update_camera(dt: float) -> void:
	var want := clampf(hero_pos.z - 2.0, -3.2, 0.3)
	if cam_pan_t > 0.0:
		cam_pan_t -= dt
		want = -3.6
	if mode == "title" or mode == "opening":
		want = 0.3
	look_z = lerpf(look_z, want, minf(1.0, dt * 3.0))
	var fov_t := 33.0
	if boss_active and boss.final_flight:
		fov_t = 27.0
	cam_fov = lerpf(cam_fov, fov_t, minf(1.0, dt * 4.0))
	cam.fov = cam_fov
	var off := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake * 0.1
	cam.position = Vector3(5.4, 8.8, look_z) + off
	cam.look_at(Vector3(0.1, 0.2, look_z) + off * 0.5, Vector3.UP)


# ---------------------------------------------------------------- ヒーロー

func _update_hero(dt: float, inp: Dictionary) -> void:
	var r: Node3D = hero.root
	if hero_inv > 0.0:
		hero_inv -= dt
	if hero_seated:
		return
	var moving := false
	var v := Vector3.ZERO
	if hero_auto:
		var d := hero_goal - hero_pos
		d.y = 0.0
		if d.length() < 0.06:
			hero_auto = false
		else:
			v = d.normalized() * 3.0
			hero_pos += v * dt
			moving = true
	elif mode == "fight" and not hero_down:
		var mv: Vector2 = inp.mv
		v = Vector3(mv.x, 0.0, mv.y)
		if v.length() > 1.0:
			v = v.normalized()
		v *= PLAYER_SPEED
		hero_pos += v * dt
		moving = v.length() > 0.1
	hero_pos += hero_vel * dt
	hero_vel *= pow(0.0005, dt)
	if not hero_auto:
		hero_pos.x = clampf(hero_pos.x, -0.42, 0.42)
		hero_pos.z = clampf(hero_pos.z, -7.4, 5.9)
	if moving:
		hero_face = lerp_angle(hero_face, atan2(v.x, v.z), minf(1.0, dt * 12.0))
		hero_phase += dt * 11.0
	elif mode == "fight":
		var near := _nearest_enemy()
		var fy := PI
		if near != null:
			fy = atan2(near.position.x - hero_pos.x, near.position.z - hero_pos.z)
		hero_face = lerp_angle(hero_face, fy, minf(1.0, dt * 8.0))
	r.position = hero_pos
	r.rotation.y = hero_face
	var w := sin(hero_phase) * 0.6 if moving else 0.0
	var lL: Node3D = hero.legL
	var lR: Node3D = hero.legR
	var aL: Node3D = hero.armL
	var aR: Node3D = hero.armR
	lL.rotation.x = w
	lR.rotation.x = -w
	aL.rotation.x = -w * 0.8
	aR.rotation.x = w * 0.8
	r.position.y = absf(sin(hero_phase)) * 0.04 if moving else 0.0
	if hero_down:
		r.rotation.x = lerp_angle(r.rotation.x, -PI / 2.0, minf(1.0, dt * 10.0))
	else:
		r.rotation.x = lerp_angle(r.rotation.x, 0.0, minf(1.0, dt * 10.0))
	# 被弾の点滅
	r.visible = hero_inv <= 0.0 or int(sim_time * 20.0) % 2 == 0


func _nearest_enemy() -> Enemy:
	var best: Enemy = null
	var bd := 99.0
	for e in enemies:
		if not e.alive() or e.st == Enemy.S.SIT:
			continue
		var d := Vector2(e.position.x - hero_pos.x, e.position.z - hero_pos.z).length()
		if d < bd:
			bd = d
			best = e
	return best


func hero_hurt(dir: Vector3) -> void:
	if hero_inv > 0.0 or hero_down:
		return
	hero_hp -= 1
	hero_inv = 1.4
	hero_vel = dir * 7.0
	hud.set_hp(hero_hp)
	hud.flash_hurt()
	Sfx.play("hurt")
	shake = maxf(shake, 0.8)
	pop_text("いてっ！", hero_pos + Vector3(0, 1.7, 0), Color(1, 0.5, 0.5), 50)
	if hero_hp <= 0:
		hero_down = true


# ---------------------------------------------------------------- 席の選択と操作

func _update_target() -> void:
	target = null
	if mode == "fight" and not hero_seated:
		var row := clampi(roundi((Cfg.ROW0_Z - hero_pos.z) / Cfg.ROW_PITCH), 0, Cfg.ROWS - 1)
		if absf(hero_pos.x) > 0.1:
			side_pref = 1 if hero_pos.x > 0.0 else -1
		target = seat_at(side_pref, row)
		if boss_active and boss.st == Enemy.S.STAND_FINAL:
			var d := Vector2(hero_pos.x - boss_seat.position.x, hero_pos.z - boss_seat.position.z).length()
			if d < 2.7:
				target = boss_seat
	elif mode == "opening" and gate != "" and gate != "done":
		target = hero_seat
	for s in seats:
		s.zone.visible = (s == target and mode == "fight" and not s.locked)
	if target != null:
		marker.visible = true
		marker.position = Vector3(target.position.x, 1.95 + 0.08 * sin(sim_time * 8.0), target.position.z)
		if target.zone.visible:
			var hot := false
			for e in enemies:
				if e.targetable() and _in_recline_zone(target, e):
					hot = true
					break
			var zm: StandardMaterial3D = target.zone.material_override
			zm.albedo_color = Color(1.0, 0.25, 0.15, 0.5) if hot else Color(1.0, 0.85, 0.2, 0.28 + 0.06 * sin(sim_time * 6.0))
		if mode == "fight":
			var s := ""
			if boss_active and boss.st == Enemy.S.STAND_FINAL and target == boss_seat:
				s = "いまだ！　R：ボスの席を回せ！"
			elif target.locked:
				s = "この席は…動かない"
			else:
				s = "E：" + ("起こす" if target.reclined else "倒す")
				if rotate_unlocked:
					s += "　　R：回す"
			hud.hint(s)
	else:
		marker.visible = false
		if mode == "fight":
			hud.hint("")


func handle_use() -> void:
	if mode == "opening":
		if gate == "recline":
			hero_seat.recline(true)
			Sfx.play("bata", 0.6, -10.0)
			gate = "done"
		elif gate == "raise":
			hero_seat.raise(true)
			Sfx.play("gakon", 0.9, -10.0)
			gate = "done"
		return
	if mode != "fight" or target == null or hero_down:
		return
	if target.locked:
		target.bump()
		Sfx.play("gatsu")
		shake = maxf(shake, 0.4)
		pop_text("ガッ！", Vector3(target.position.x, 1.5, target.position.z), Color(0.8, 0.8, 0.85), 56)
		if not boss_active:
			hud.tip("この席だけ、なぜか動かない…", 3.0)
		return
	if target.busy_back():
		return
	if target.reclined:
		target.raise()
		Sfx.play("gakon", 1.35, -4.0)
	else:
		target.recline()
		Sfx.play("gakon", 1.0, -4.0)


func handle_rot() -> void:
	if mode != "fight" or target == null or hero_down or not rotate_unlocked:
		return
	if target.locked:
		target.bump()
		Sfx.play("gatsu")
		pop_text("ガッ！", Vector3(target.position.x, 1.5, target.position.z), Color(0.8, 0.8, 0.85), 56)
		return
	if target.busy_yaw():
		return
	target.rotate_unit()
	Sfx.play("whoosh", 1.0, -2.0)


# ---------------------------------------------------------------- 当たり判定

func _circ_rect(l: Vector3, r: float, x0: float, x1: float, z0: float, z1: float) -> bool:
	var dx := l.x - clampf(l.x, x0, x1)
	var dz := l.z - clampf(l.z, z0, z1)
	return dx * dx + dz * dz <= r * r


func _in_recline_zone(s: Seat, e: Enemy) -> bool:
	var l := s.to_local(e.global_position)
	return _circ_rect(l, e.radius, -Cfg.ZONE_HX, Cfg.ZONE_HX, Cfg.ZONE_Z0, Cfg.ZONE_Z1)


func _in_core(s: Seat, e: Enemy) -> bool:
	var l := s.to_local(e.global_position)
	return absf(l.x) < 1.12 and l.z > -1.07 and l.z < -0.2


func _in_raise_zone(s: Seat, e: Enemy) -> bool:
	var l := s.to_local(e.global_position)
	return _circ_rect(l, e.radius, -1.12, 1.12, -1.25, 0.45)


func seat_impact(seat: Seat, kind: int) -> void:
	var bwd: Vector3 = seat.global_transform.basis * Vector3(0, 0, -1)
	var fwd := -bwd
	var aisle := Vector3(-float(seat.side), 0, 0)
	var any := false
	if kind == 1:
		for e in enemies:
			if not e.targetable() or not _in_recline_zone(seat, e):
				continue
			any = true
			if e.is_boss:
				_boss_squeeze(e, seat, bwd)
			elif _in_core(seat, e) and e.st != Enemy.S.PINNED:
				var l := seat.to_local(e.global_position)
				var tgt := seat.to_global(Vector3(clampf(l.x, -0.35, 0.35), 0.0, -0.7))
				e.pin(seat, tgt)
				e.take_damage(3)
				Sfx.play("squish")
				register_hit(e, 200, "ぎゅむっ！", 1.0)
			else:
				e.take_damage(1)
				e.knock(bwd * 5.5 + Vector3(0, 3.0, 0), 0.8, false)
				register_hit(e, 80, hit_texts[randi() % hit_texts.size()], 0.5)
		Sfx.play("bata", 1.0, -2.0 if any else -8.0)
		if any:
			Sfx.play("gon")
		else:
			shake = maxf(shake, 0.15)
	elif kind == 2:
		for e in enemies:
			var mine: bool = e.pinned_by == seat
			if not mine:
				if e.st == Enemy.S.PINNED or e.st == Enemy.S.SIT or e.st == Enemy.S.STAND_FINAL and not e.is_boss:
					continue
				if e.is_boss and not e.targetable():
					continue
				if not _in_raise_zone(seat, e):
					continue
			any = true
			if e.is_boss:
				e.take_damage(1)
				boss_hit(e)
				register_hit(e, 150, "ドスン！", 0.6)
				continue
			var was_dead := e.hp <= 0
			if not was_dead:
				e.take_damage(2)
			e.knock(fwd * 3.0 + aisle * 1.3 + Vector3(0, 8.0, 0), 1.0, true)
			if was_dead:
				pop_text("ぼよーん！", e.global_position + Vector3(0, 1.4, 0), Color(0.6, 1, 0.7), 48)
				shake = maxf(shake, 0.4)
			else:
				register_hit(e, 150, "ぼよーん！", 0.9, Color(0.6, 1, 0.7))
		if any:
			Sfx.play("boing", randf_range(0.9, 1.15))
			Sfx.play("bata", 1.3, -4.0)
		else:
			Sfx.play("bata", 1.5, -9.0)
			shake = maxf(shake, 0.12)


func rot_impact(seat: Seat) -> void:
	var any := false
	for e in enemies:
		if e.is_boss:
			if boss_active and e.st == Enemy.S.STAND_FINAL and seat == boss_seat:
				var d0 := Vector2(e.position.x - seat.position.x, e.position.z - seat.position.z).length()
				if d0 < 1.4:
					_final_blow(seat)
					return
			continue
		if e.st == Enemy.S.SIT or (e.st == Enemy.S.PINNED and e.pinned_by != seat):
			continue
		var dx := e.position.x - seat.position.x
		var dz := e.position.z - seat.position.z
		var dist := Vector2(dx, dz).length()
		if dist > 1.1:
			continue
		any = true
		var tang := Vector3(dz, 0, -dx) * seat.rot_sign * -1.0
		# 座席の回転方向：yaw が rot_sign 方向に増えるとき、点の速度は (dz,-dx)*sign
		tang = Vector3(dz, 0, -dx) * seat.rot_sign
		if tang.length() < 0.05:
			tang = Vector3(0, 0, -1)
		tang = tang.normalized()
		var outv := Vector3(dx, 0, dz)
		outv = outv.normalized() if outv.length() > 0.05 else Vector3(-float(seat.side), 0, 0)
		var dead := e.hp <= 0
		if not dead:
			e.take_damage(1)
		e.knock(tang * 6.5 + outv * 2.0 + Vector3(0, 3.2, 0), 1.0, true)
		if not dead:
			register_hit(e, 70, "ぐるん！", 0.6, Color(0.6, 0.85, 1.0))
	if any:
		Sfx.play("gon", 1.2)
	else:
		shake = maxf(shake, 0.12)


func _boss_squeeze(e: Enemy, seat: Seat, bwd: Vector3) -> void:
	var from_front := bwd.z < 0.0
	if from_front:
		e.sq_front = sim_time
	else:
		e.sq_back = sim_time
	var dmg := 2
	var txt := "ぎゅむっ！"
	if absf(e.sq_front - e.sq_back) < 4.0:
		dmg += 4
		txt = "前後サンドイッチ！"
		e.sq_front = -99.0
		e.sq_back = -99.0
	e.take_damage(dmg)
	Sfx.play("squish", 0.8)
	boss_hit(e)
	register_hit(e, 300 if dmg > 2 else 150, txt, 1.0)


func boss_hit(e: Enemy) -> void:
	e.flash = 0.2
	if e.hp <= 0 and e.st == Enemy.S.SIT:
		_boss_stand()


func _boss_stand() -> void:
	var side := -1
	var sx := 0.55 * float(-side)
	boss.stand_up(Vector3(sx - 0.65, 0.0, boss_seat.position.z))
	boss_seat.locked = false
	Sfx.play("sting")
	Sfx.play("boing", 0.7)
	pop_text("ガタッ！", Vector3(boss_seat.position.x, 2.4, boss_seat.position.z), Color(1, 0.4, 0.3), 70)
	hud.tip("ボスが立った！　席を回してぶつけろ！", 9.0)
	slowmo(0.7, 0.3)
	shake = 1.0


func _final_blow(seat: Seat) -> void:
	boss.hp = 0
	boss.final_flight = true
	boss.knock(Vector3(0.0, 11.0, -10.5), 4.0, true)
	boss.face_yaw = 0.0
	door_t = 6.0
	Sfx.play("don")
	Sfx.play("boing", 0.6)
	Sfx.play("gakon", 0.7)
	score += 5000
	hud.set_score(score)
	pop_text("ドーーーン！！", Vector3(boss.position.x, 2.2, boss.position.z), Color(1, 0.85, 0.2), 110)
	slowmo(1.8, 0.2)
	shake = 1.6
	hit_stop_t = 0.25


func on_boss_down() -> void:
	boss_down = true
	Sfx.play("thud", 0.6)


func _enemy_interactions() -> void:
	var n := enemies.size()
	for i in n:
		var a := enemies[i]
		for j in range(i + 1, n):
			var b := enemies[j]
			var dx := b.position.x - a.position.x
			var dz := b.position.z - a.position.z
			var d := sqrt(dx * dx + dz * dz)
			if d < 0.0001:
				continue
			var min_d := a.radius + b.radius
			var fa := _fast(a)
			var fb := _fast(b)
			if (fa or fb) and d < min_d + 0.1:
				var dir := Vector3(dx, 0, dz) / d
				if fa and a.cd.get(b.get_instance_id(), 0.0) < sim_time:
					a.cd[b.get_instance_id()] = sim_time + 0.7
					_collide(a, b, dir)
				if fb and b.cd.get(a.get_instance_id(), 0.0) < sim_time:
					b.cd[a.get_instance_id()] = sim_time + 0.7
					_collide(b, a, -dir)
			elif d < min_d * 0.9 and _walkish(a) and _walkish(b):
				var push := (min_d * 0.9 - d) * 0.5
				var dir2 := Vector3(dx, 0, dz) / d
				if not (a.is_boss or b.is_boss):
					a.position -= dir2 * push
					b.position += dir2 * push


func _fast(e: Enemy) -> bool:
	return e.st == Enemy.S.STUN and Vector2(e.vel.x, e.vel.z).length() > 3.0


func _walkish(e: Enemy) -> bool:
	return e.st == Enemy.S.WALK or e.st == Enemy.S.WINDUP or e.st == Enemy.S.RECOVER or e.st == Enemy.S.LUNGE


func _collide(src: Enemy, dst: Enemy, dir: Vector3) -> void:
	if dst.hp <= 0 or not (dst.targetable() or dst.st == Enemy.S.STUN):
		return
	if dst.st == Enemy.S.PINNED:
		return
	var dmg := 2 if dst.is_boss else 1
	dst.take_damage(dmg)
	src.vel.x *= 0.35
	src.vel.z *= 0.35
	if dst.is_boss:
		boss_hit(dst)
	else:
		dst.knock(dir * 4.0 + Vector3(0, 3.5, 0), 0.9, true)
	Sfx.play("gon", 1.1)
	register_hit(dst, 120, "ゴツン！", 0.8, Color(1, 0.6, 0.3))


# ---------------------------------------------------------------- スコア・演出

func register_hit(e: Enemy, pts: int, text: String, power: float, col: Color = Color(1, 0.9, 0.2)) -> void:
	if combo_t > 0.0:
		combo += 1
	else:
		combo = 1
	combo_t = 2.4
	score += pts * combo
	var killed := e.hp <= 0
	var label := text
	if killed and not e.counted:
		e.counted = true
		kills += 1
		score += 300 * combo
		label += "  KO!"
		if not e.is_boss:
			slowmo(0.45, 0.3)
	hud.set_combo(combo)
	hud.set_score(score)
	pop_text(label, e.global_position + Vector3(0, 1.5 * e.sc, 0), col, 50 + int(power * 26.0))
	hit_stop_t = maxf(hit_stop_t, 0.04 + 0.07 * power)
	shake = maxf(shake, 0.3 + 0.5 * power)
	if combo >= 2:
		Sfx.play("tick", 0.8 + 0.08 * float(mini(combo, 12)), -2.0)


func pop_text(s: String, wpos: Vector3, col: Color, size: int = 48) -> void:
	hud.pop(s, wpos, col, size)


func slowmo(secs: float, scale: float) -> void:
	slow_t = maxf(slow_t, secs)
	slow_scale = scale


func alive_count() -> int:
	var n := 0
	for e in enemies:
		if e.alive():
			n += 1
	return n


# ---------------------------------------------------------------- 進行（コルーチン）

func wait(sec: float) -> void:
	var end := sim_time + sec
	while sim_time < end:
		await get_tree().process_frame


func wait_press() -> void:
	any_press = false
	var t0 := sim_time
	while not any_press:
		if autoplay and sim_time - t0 > 0.5:
			break
		await get_tree().process_frame
	any_press = false


func run_game() -> void:
	await get_tree().process_frame
	Sfx.start_rumble()
	var start_stage := int(args.get("stage", "0"))
	if start_stage == 0:
		mode = "title"
		hud.fade_to(0.55, 0.01)
		hud.show_start(true)
		await wait_press()
		hud.show_start(false)
		await opening()
	else:
		hud.fade_to(0.0, 0.5)
		_reset_stage()
		_hero_stand_now()
	if start_stage <= 1:
		await run_stage(1)
	if start_stage <= 2:
		await run_stage(2)
	if start_stage <= 3:
		await run_stage(3)
	if start_stage <= 4:
		await run_boss()
	await ending()


func opening() -> void:
	mode = "opening"
	_reset_stage()
	hero_seated = true
	hud.fade_to(0.0, 1.5)
	await wait(1.6)
	Sfx.play("pinpon", 1.0, -6.0)
	await wait(1.0)
	hud.subtitle("あなた", "「シート、倒してもいいですか？」", 3.0)
	await wait(2.6)
	hud.subtitle("後ろの乗客", "「どうぞ」", 2.0)
	nod_t = 0.7
	await wait(1.8)
	hud.hint("E / 左クリック：シートを倒す")
	gate = "recline"
	while gate != "done":
		await get_tree().process_frame
	hud.hint("")
	await wait(1.6)
	hud.subtitle("", "ふぅ…", 1.5)
	await wait(1.4)
	hud.hint("E / 左クリック：シートを戻してください")
	gate = "raise"
	while gate != "done":
		await get_tree().process_frame
	hud.hint("")
	gate = ""
	await wait(1.8)
	# 突然、後方の扉が開く
	door_t = 3.5
	cam_pan_t = 3.2
	Sfx.play("door")
	await wait(0.4)
	shake = 1.0
	Sfx.play("sting")
	await wait(0.6)
	hud.hp_visible(true)
	_hero_stand_now()
	hero_auto = true
	hero_goal = Vector3(0.25, 0.0, hero_pos.z)


func _hero_stand_now() -> void:
	if hero_seated:
		Models.stand(hero, self)
		hero_seated = false
	hero.root.visible = true
	hero_pos = Vector3(0.3, 0.0, 2.9)
	hero_face = PI
	hero_auto = false
	hero.root.position = hero_pos
	hud.hp_visible(true)


func _reset_stage() -> void:
	for e in enemies:
		e.queue_free()
	enemies.clear()
	attackers = 0
	spawn_queue.clear()
	hud.clear_pops()
	for s in seats:
		s.reset_now()
	_boss_to_seat()
	hero_hp = 5
	hero_down = false
	hero_inv = 0.0
	hero_vel = Vector3.ZERO
	combo = 0
	combo_t = 0.0
	hud.set_combo(0)
	hud.set_hp(5)
	hud.boss_bar(false)
	hero.root.rotation = Vector3.ZERO
	hero.root.visible = true
	if not hero_seated:
		hero_pos = Vector3(0.3, 0.0, 2.9)
		hero.root.position = hero_pos


func run_stage(n: int) -> void:
	while true:
		stage = n
		var ok: bool = await fight(n)
		if ok:
			break
		await game_over()


func game_over() -> void:
	mode = "over"
	Sfx.bgm(false)
	hud.banner("やられた…", "クリックでやり直し", 30.0)
	hud.hint("")
	await wait(0.8)
	await wait_press()
	hud.banner("", "", 0.01)
	_reset_stage()


func fight(n: int) -> bool:
	var cfg: Dictionary = STAGES[n]
	_reset_stage()
	mode = "fight"
	rotate_unlocked = n >= 2
	enemy_speed = cfg.speed
	max_attackers = cfg.att
	hud.set_enemies(0)
	Sfx.bgm(true)
	hud.banner("STAGE " + str(n), "", 1.5)
	cam_pan_t = 1.8
	Sfx.play("ding")
	if n == 1:
		hud.tip("シートを使って敵を倒してください", 7.0)
	elif n == 2:
		hud.tip("座席を回転できます　R：回す　（敵を別の席の前へ！）", 8.0)
	else:
		hud.tip("倒す・起こす・回す　好きに組み合わせろ！", 6.0)
	await wait(1.4 if n > 1 else 0.6)
	var spawns: Array = cfg.spawns
	for t in spawns:
		spawn_queue.append(float(t))
	var t0 := sim_time
	while true:
		await get_tree().process_frame
		while spawn_queue.size() > 0 and sim_time - t0 >= float(spawn_queue[0]):
			spawn_queue.pop_front()
			_spawn()
		if hero_hp <= 0:
			return false
		if spawn_queue.size() == 0 and alive_count() == 0:
			break
	await wait(0.6)
	Sfx.play("ding", 1.3)
	hud.banner("CLEAR!", "", 1.4)
	await wait(2.0)
	return true


func _spawn() -> void:
	var e := Enemy.new()
	add_child(e)
	e.setup(self, false, variant_i)
	variant_i += 1
	e.speed = enemy_speed
	e.position = Vector3(randf_range(-0.2, 0.2), 0.0, Cfg.DOOR_Z + 0.5)
	e.face_yaw = 0.0
	enemies.append(e)
	door_t = 2.0
	Sfx.play("door", 1.0, -6.0)


func run_boss() -> void:
	while true:
		stage = 4
		var ok: bool = await fight_boss()
		if ok:
			break
		await game_over()


func fight_boss() -> bool:
	_reset_stage()
	mode = "fight"
	rotate_unlocked = true
	enemy_speed = 1.7
	max_attackers = 2
	Sfx.bgm(true)
	hud.banner("BOSS", "絶対に席を動かさない男", 2.2)
	cam_pan_t = 0.6
	Sfx.play("sting")
	hud.tip("あの席は動かない。周りの席と手下を使え！", 7.0)
	boss_active = true
	boss_down = false
	enemies.append(boss)
	hud.boss_bar(true, 1.0)
	await wait(1.6)
	var t0 := sim_time
	var calm := 0.0
	var wave_t := 1.0
	var spawned_first := false
	while true:
		await get_tree().process_frame
		var minions := alive_count() - (1 if boss.alive() else 0)
		if not spawned_first and sim_time - t0 > wave_t:
			spawned_first = true
			_spawn()
			spawn_queue.append(sim_time - t0 + 1.2)
		while spawn_queue.size() > 0 and sim_time - t0 >= float(spawn_queue[0]):
			spawn_queue.pop_front()
			_spawn()
		if not boss.alive() and boss.st != Enemy.S.STAND_FINAL and boss.st != Enemy.S.STUN and not boss_down:
			pass
		if boss.hp > 0 and spawned_first and spawn_queue.size() == 0 and minions <= 0:
			calm += 1.0 / 60.0
			if calm > 2.5:
				calm = 0.0
				spawn_queue.append(sim_time - t0 + 0.1)
				spawn_queue.append(sim_time - t0 + 1.2)
		if args.has("dbg") and int(sim_time * 2.0) != dbg_i:
			dbg_i = int(sim_time * 2.0)
			print("t=", snappedf(sim_time, 0.1), " bosshp=", boss.hp, " st=", boss.st, " hero=", hero_pos, " hp=", hero_hp, " minions=", minions, " tgt=", target.row if target else -1, target.side if target else 0)
		if hero_hp <= 0:
			return false
		if boss_down:
			break
	# 決着：残りの手下もへたり込む
	for e in enemies:
		if e.alive() and not e.is_boss:
			e.die()
	hud.boss_bar(false)
	spawn_queue.clear()
	await wait(1.6)
	hud.banner("戦闘終了", "", 2.0)
	Sfx.play("ding", 0.8)
	await wait(2.4)
	return true


func ending() -> void:
	mode = "ending"
	Sfx.bgm(false)
	hud.hint("")
	hud.tip("", 0.01)
	hud.set_enemies(0, false)
	boss_active = false
	hero_hp = 5
	hero_inv = 0.0
	hero_down = false
	hero.root.visible = true
	hero.root.rotation = Vector3.ZERO
	hero_seat.reset_now()
	hero_goal = Vector3(0.42, 0.0, hero_seat.position.z)
	hero_auto = true
	var guard := 0.0
	while hero_auto and guard < 12.0:
		await get_tree().process_frame
		guard += 1.0 / 60.0
	hero_auto = false
	hero_face = 0.0
	hero.root.rotation.y = 0.0
	await wait(0.5)
	Models.sit(hero, hero_seat, -0.28)
	hero_seated = true
	hud.hp_visible(false)
	await wait(1.8)
	# 振り返る
	var up: Node3D = hero.upper
	var t := 0.0
	while t < 1.0:
		await get_tree().process_frame
		t += 1.0 / 60.0
		up.rotation.y = lerpf(0.0, PI * 0.85, Cfg.ease_io(clampf(t, 0.0, 1.0)))
	await wait(0.5)
	hud.subtitle("あなた", "「シート、倒してもいいですか？」", 3.2)
	await wait(3.6)
	hud.fade_to(1.0, 1.2)
	await wait(1.6)
	hud.title_card(true, "THE END")
	hud.hint("")
	Sfx.play("pinpon", 0.9, -4.0)
	await wait(4.0)
	hud.title_card(true, "SCORE  " + str(score).pad_zeros(6) + "\n\nクリックでもう一度")
	print("ENDING reached score=", score, " kills=", kills)
	if autoplay:
		get_tree().quit()
		return
	await wait_press()
	get_tree().reload_current_scene()


# ---------------------------------------------------------------- 自動プレイ（検証用）

func _bot() -> Dictionary:
	var d := {"mv": Vector2.ZERO, "use": false, "rot": false}
	if mode == "opening" and (gate == "recline" or gate == "raise") and sim_time > bot_next:
		d.use = true
		bot_next = sim_time + 1.0
		return d
	if mode != "fight" or hero_seated or hero_down or hero_hp <= 0:
		return d
	# 狙う敵
	var tgt: Enemy = null
	var bd := 99.0
	for e in enemies:
		if not e.alive() or e.st == Enemy.S.SIT or e.is_boss:
			continue
		var dd := Vector2(e.position.x - hero_pos.x, e.position.z - hero_pos.z).length()
		if dd < bd:
			bd = dd
			tgt = e
	var want_z := hero_pos.z
	var want_x := 0.3
	var row := -1
	if boss_active and boss.st == Enemy.S.STAND_FINAL:
		row = BOSS_ROW
		want_x = -0.3
	elif tgt != null and bd < 5.0:
		var rf := (Cfg.ROW0_Z - (tgt.position.z + 0.7)) / Cfg.ROW_PITCH
		row = clampi(roundi(rf), 0, Cfg.ROWS - 1)
	elif boss_active and boss.alive():
		row = BOSS_ROW - 1
		want_x = -0.3
	if row >= 0:
		want_z = Cfg.row_z(row)
	var dz := want_z - hero_pos.z
	if absf(dz) > 0.03:
		d.mv.y = clampf(dz * 2.5, -1.0, 1.0)
	d.mv.x = clampf((want_x - hero_pos.x) * 6.0, -1.0, 1.0)
	if sim_time < bot_next or target == null or absf(dz) > 0.3:
		return d
	if boss_active and boss.st == Enemy.S.STAND_FINAL:
		if target == boss_seat and d.mv.length() < 0.2 and not target.busy_yaw():
			d.rot = true
			bot_next = sim_time + 0.6
		return d
	if target.locked or target.busy_back():
		return d
	if not target.reclined:
		var hit := false
		for e in enemies:
			if e.targetable() and _in_recline_zone(target, e):
				hit = true
				break
		if hit:
			d.use = true
			bot_next = sim_time + 0.35
		elif rotate_unlocked and bd < 1.3 and randf() < 0.01 and not target.busy_yaw():
			d.rot = true
			bot_next = sim_time + 0.7
	else:
		var go := target.recl_time > 1.2
		for e in enemies:
			if e.pinned_by == target or (e.targetable() and _in_raise_zone(target, e) and e.st != Enemy.S.PINNED):
				go = true
		if go and target.recl_time > 0.35:
			d.use = true
			bot_next = sim_time + 0.3
	return d
