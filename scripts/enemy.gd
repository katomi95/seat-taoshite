class_name Enemy
extends Node3D

enum S { WALK, WINDUP, LUNGE, RECOVER, STUN, PINNED, DEAD, SIT, STAND_FINAL }

var game
var rig: Dictionary
var st: int = S.WALK
var hp := 3
var max_hp := 3
var radius := 0.32
var vel := Vector3.ZERO
var is_boss := false
var speed := 1.4
var t := 0.0
var landed := true
var stun_dur := 1.0
var pinned_by: Seat = null
var pin_pos := Vector3.ZERO
var lunge_dir := Vector3.ZERO
var phase := 0.0
var flash := 0.0
var spin := 0.0
var cd := {}
var stars: Node3D
var face_yaw := 0.0
var sc := 1.0
var sq_front := -99.0
var sq_back := -99.0
var final_ready := false
var final_flight := false
var stand_pos := Vector3.ZERO
var token := false
var lie_sign := 1.0
var counted := false


func setup(g, boss: bool, variant: int) -> void:
	game = g
	is_boss = boss
	if boss:
		sc = 1.45
		hp = 14
		max_hp = 14
		radius = 0.6
		rig = Models.person(Color(0.75, 0.1, 0.12), Color(0.15, 0.15, 0.2), Color(0.08, 0.08, 0.08), true, sc, true)
	else:
		var suits := [
			[Color(0.25, 0.27, 0.34), Color(0.18, 0.19, 0.24)],
			[Color(0.45, 0.3, 0.22), Color(0.28, 0.2, 0.16)],
			[Color(0.22, 0.38, 0.32), Color(0.16, 0.25, 0.22)],
			[Color(0.4, 0.22, 0.42), Color(0.25, 0.15, 0.28)],
		]
		var hairs := [Color(0.1, 0.08, 0.06), Color(0.35, 0.2, 0.1), Color(0.6, 0.6, 0.62), Color(0.05, 0.05, 0.08)]
		var v: int = variant % suits.size()
		rig = Models.person(suits[v][0], suits[v][1], hairs[v], true, 1.0)
	add_child(rig.root)
	lie_sign = 1.0 if randf() < 0.5 else -1.0
	stars = Node3D.new()
	stars.position = Vector3(0, 1.75 * sc, 0)
	var gm := Models.glow(Color(1.0, 0.9, 0.2), 1.5)
	for i in 3:
		var b := Models.ball(stars, 0.05, Vector3(0.28 * sc, 0, 0).rotated(Vector3.UP, TAU * float(i) / 3.0), gm)
		b.scale = Vector3.ONE
	stars.visible = false
	add_child(stars)


func alive() -> bool:
	return hp > 0 and st != S.DEAD


# 座席の当たり判定に入りうる状態か（ボスは出番のときだけ）
func targetable() -> bool:
	if hp <= 0:
		return false
	if st == S.DEAD:
		return false
	if is_boss:
		return game.boss_active and (st == S.SIT or st == S.STAND_FINAL)
	if st == S.SIT:
		return false
	return true


func base_y() -> float:
	if is_boss:
		return 0.0
	return 0.5 if absf(position.x) > 0.56 else 0.0


func take_damage(d: int) -> bool:
	hp -= d
	flash = 0.16
	return hp <= 0


func _release_token() -> void:
	if token:
		token = false
		game.attackers = maxi(0, game.attackers - 1)


func knock(v: Vector3, dur: float = 1.0, tumble: bool = true) -> void:
	_release_token()
	pinned_by = null
	st = S.STUN
	t = 0.0
	stun_dur = dur
	vel = v
	landed = false
	spin = (randf_range(7.0, 11.0) * (1.0 if randf() < 0.5 else -1.0)) if tumble else 0.0


func pin(seat: Seat, tgt: Vector3) -> void:
	_release_token()
	pinned_by = seat
	pin_pos = Vector3(tgt.x, base_y(), tgt.z)
	st = S.PINNED
	t = 0.0
	vel = Vector3.ZERO


func die() -> void:
	_release_token()
	st = S.DEAD
	pinned_by = null
	vel = Vector3.ZERO
	stars.visible = false


func stand_up(pos: Vector3) -> void:
	st = S.STAND_FINAL
	t = 0.0
	stand_pos = pos
	final_ready = false


func tick(dt: float) -> void:
	phase += dt
	if flash > 0.0:
		flash -= dt
		_flash_apply()
	match st:
		S.WALK:
			_walk(dt)
		S.WINDUP:
			_windup(dt)
		S.LUNGE:
			_lunge(dt)
		S.RECOVER:
			t += dt
			position.y = lerpf(position.y, base_y(), minf(1.0, dt * 12.0))
			if t > 0.8:
				st = S.WALK
		S.STUN:
			_stun(dt)
		S.PINNED:
			_pinned(dt)
		S.STAND_FINAL:
			t += dt
			position = position.lerp(stand_pos, minf(1.0, dt * 7.0))
			position.y = lerpf(position.y, 0.0, minf(1.0, dt * 8.0))
			if t > 0.5:
				final_ready = true
	_clamp()
	_pose(dt)


func _clamp() -> void:
	if final_flight:
		position.z = clampf(position.z, -14.0, Cfg.Z_MAX)
		return
	if st == S.SIT or st == S.PINNED:
		return
	var lim := Cfg.WALL_X - 0.25
	if absf(position.x) > lim:
		position.x = clampf(position.x, -lim, lim)
		vel.x *= -0.4
	if position.z < Cfg.Z_MIN or position.z > Cfg.Z_MAX:
		position.z = clampf(position.z, Cfg.Z_MIN, Cfg.Z_MAX)
		vel.z *= -0.4


func _walk(dt: float) -> void:
	var hp_pos: Vector3 = game.hero_pos
	var to := Vector3(hp_pos.x - position.x, 0.0, hp_pos.z - position.z)
	var d := to.length()
	var dir := to / maxf(d, 0.001)
	face_yaw = lerp_angle(face_yaw, atan2(dir.x, dir.z), minf(1.0, dt * 10.0))
	position.y = lerpf(position.y, base_y(), minf(1.0, dt * 12.0))
	if d > 1.0:
		position += dir * speed * dt
	elif game.attackers < game.max_attackers and not game.hero_down:
		game.attackers += 1
		token = true
		st = S.WINDUP
		t = 0.0
		lunge_dir = dir
		Sfx.play("tick", 1.6, -6.0)
		game.pop_text("！", position + Vector3(0, 1.9, 0), Color(1, 0.3, 0.2), 54)


func _windup(dt: float) -> void:
	t += dt
	var hp_pos: Vector3 = game.hero_pos
	var to := Vector3(hp_pos.x - position.x, 0.0, hp_pos.z - position.z)
	if to.length() > 0.01 and t < 0.4:
		lunge_dir = to.normalized()
	face_yaw = lerp_angle(face_yaw, atan2(lunge_dir.x, lunge_dir.z), minf(1.0, dt * 12.0))
	if t > 0.7:
		st = S.LUNGE
		t = 0.0
		Sfx.play("whoosh", 1.5, -10.0)


func _lunge(dt: float) -> void:
	t += dt
	position += lunge_dir * 7.0 * dt
	var hp_pos: Vector3 = game.hero_pos
	var d := Vector2(hp_pos.x - position.x, hp_pos.z - position.z).length()
	if d < 0.6 and game.hero_inv <= 0.0:
		game.hero_hurt(lunge_dir)
	if t > 0.22:
		_release_token()
		st = S.RECOVER
		t = 0.0


func _stun(dt: float) -> void:
	vel.y -= 22.0 * dt
	position += vel * dt
	var by := base_y()
	if position.y <= by and vel.y <= 0.0:
		position.y = by
		if absf(vel.y) > 3.5:
			vel.y = -vel.y * 0.3
			vel.x *= 0.6
			vel.z *= 0.6
			spin *= 0.5
			Sfx.play("thud", randf_range(0.9, 1.1), -4.0)
		else:
			vel.y = 0.0
			landed = true
	if landed:
		var f := pow(0.003, dt)
		vel.x *= f
		vel.z *= f
		t += dt
		if hp <= 0 and Vector2(vel.x, vel.z).length() < 1.5:
			die()
			if final_flight:
				game.on_boss_down()
		elif t > stun_dur and hp > 0:
			st = S.WALK
			t = 0.0
	elif final_flight and position.z <= -13.9:
		position.z = -13.9
		vel = Vector3.ZERO
		hp = 0
		die()
		game.on_boss_down()


func _pinned(dt: float) -> void:
	t += dt
	position = position.lerp(pin_pos, minf(1.0, dt * 14.0))
	if t > 2.4:
		# 抜け出す
		var seat: Seat = pinned_by
		var out := Vector3(0, 2.5, 0)
		if seat != null:
			out += seat.global_transform.basis * Vector3(0, 0, -1.5)
		knock(out, 0.9, false)


func _flash_apply() -> void:
	var on := flash > 0.0
	for m in rig.mats:
		var sm: StandardMaterial3D = m
		sm.emission_enabled = on
		if on:
			sm.emission = Color(1, 1, 1)
			sm.emission_energy_multiplier = 1.4


func _pose(dt: float) -> void:
	var r: Node3D = rig.root
	var up: Node3D = rig.upper
	var armL: Node3D = rig.armL
	var armR: Node3D = rig.armR
	var legL: Node3D = rig.legL
	var legR: Node3D = rig.legR
	var base_scale := Vector3.ONE * sc
	r.rotation.y = face_yaw
	stars.visible = (st == S.PINNED and hp > 0) or (st == S.STUN and landed and hp > 0)
	if stars.visible:
		stars.rotation.y += dt * 6.0
	var k := minf(1.0, dt * 10.0)
	match st:
		S.WALK, S.RECOVER:
			var w := sin(phase * 8.0 * maxf(speed, 1.0) / 1.4) * 0.6
			legL.rotation.x = w
			legR.rotation.x = -w
			armL.rotation.x = -w * 0.8
			armR.rotation.x = w * 0.8
			armL.rotation.z = 0.0
			armR.rotation.z = 0.0
			up.rotation.x = lerpf(up.rotation.x, 0.0, k)
			up.rotation.z = lerpf(up.rotation.z, 0.0, k)
			r.rotation.x = lerp_angle(r.rotation.x, 0.0, k)
			r.scale = r.scale.lerp(base_scale, k)
			r.position.y = absf(sin(phase * 8.0)) * 0.04
		S.WINDUP:
			armL.rotation.x = -2.8
			armR.rotation.x = -2.8
			up.rotation.z = sin(phase * 55.0) * 0.08
			r.scale = r.scale.lerp(base_scale * Vector3(1.0, 1.0 + 0.1 * sin(phase * 30.0), 1.0), k)
		S.LUNGE:
			up.rotation.x = 0.5
			armL.rotation.x = -1.5
			armR.rotation.x = -1.5
			legL.rotation.x = 0.7
			legR.rotation.x = -0.7
		S.STUN:
			if not landed:
				r.rotation.x += spin * dt
				armL.rotation.z = 1.3
				armR.rotation.z = -1.3
				armL.rotation.x = 0.0
				armR.rotation.x = 0.0
				legL.rotation.z = 0.4
				legR.rotation.z = -0.4
			else:
				r.rotation.x = lerp_angle(r.rotation.x, 0.0, k)
				up.rotation.x = lerpf(up.rotation.x, 0.5, k)
				armL.rotation.x = 0.4
				armR.rotation.x = 0.4
				armL.rotation.z = 0.2
				armR.rotation.z = -0.2
				up.rotation.z = sin(phase * 7.0) * 0.12
			r.scale = r.scale.lerp(base_scale, k)
		S.PINNED:
			r.scale = r.scale.lerp(base_scale * Vector3(1.35, 0.45, 1.0), minf(1.0, dt * 18.0))
			r.rotation.x = lerp_angle(r.rotation.x, 0.0, k)
			armL.rotation.z = 1.6 + sin(phase * 25.0) * 0.3
			armR.rotation.z = -1.6 - sin(phase * 25.0) * 0.3
			armL.rotation.x = 0.0
			armR.rotation.x = 0.0
		S.DEAD:
			r.scale = r.scale.lerp(base_scale, k)
			r.rotation.x = lerp_angle(r.rotation.x, -PI / 2.0 * lie_sign, minf(1.0, dt * 14.0))
			r.position.y = lerpf(r.position.y, 0.1 * sc, k)
			position.y = lerpf(position.y, base_y(), k)
			armL.rotation.z = 0.5
			armR.rotation.z = -0.5
			armL.rotation.x = 0.0
			armR.rotation.x = 0.0
			legL.rotation.x = 0.0
			legR.rotation.x = 0.0
			up.rotation.x = 0.0
			up.rotation.z = 0.0
		S.SIT:
			Models.pose_sit(rig)
			armL.rotation.x = -0.9
			armR.rotation.x = -0.9
			armL.rotation.z = -0.5
			armR.rotation.z = 0.5
			up.position.x = 0.0
			if flash > 0.0:
				up.position.x = randf_range(-0.03, 0.03)
		S.STAND_FINAL:
			Models.pose_stand(rig)
			var prev := phase
			armL.rotation.x = -2.9
			armR.rotation.x = -2.9
			r.scale = r.scale.lerp(base_scale, k)
			r.position.y = absf(sin(phase * 5.0)) * 0.03
			up.rotation.z = sin(prev * 14.0) * 0.05
			face_yaw = lerp_angle(face_yaw, PI * 0.5 * -1.0 * 0.0, k)
