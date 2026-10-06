class_name Seat
extends Node3D

# 座席ユニット（2人掛け）。背もたれの倒す／起こす、ユニット全体の180度回転を持つ。

var game
var side := 1
var row := 0
var locked := false
var back: Node3D
var zone: MeshInstance3D
var home := Vector3.ZERO

var reclined := false
var ang := Cfg.UP_ANGLE
var ang_from := Cfg.UP_ANGLE
var ang_to := Cfg.UP_ANGLE
var ang_t := 1.0
var ang_dur := 0.2
var ang_back := true
var recl_time := 0.0
var pending := 0
var pending_t := 0.0

var yaw_from := 0.0
var yaw_to := 0.0
var yaw_t := 1.0
var yaw_dur := 0.42
var rot_sign := -1.0
var rot_pending := false
var rot_pending_t := 0.0

var shake_t := 0.0


func setup(g, s: int, r: int) -> void:
	game = g
	side = s
	row = r
	# 回転の向き：通路側の縁が「後ろ向き（-Z）」へ動くように
	rot_sign = -1.0 if s > 0 else 1.0
	home = Vector3(float(s) * Cfg.UNIT_X, 0.0, Cfg.row_z(r))
	position = home
	Models.build_seat(self)


func busy_back() -> bool:
	return ang_t < 1.0


func busy_yaw() -> bool:
	return yaw_t < 1.0


func recline(slow: bool = false) -> void:
	reclined = true
	ang_from = ang
	ang_to = Cfg.RECLINE_ANGLE
	ang_t = 0.0
	ang_back = not slow
	ang_dur = 1.1 if slow else 0.2
	recl_time = 0.0
	if not slow:
		pending = 1
		pending_t = 0.07


func raise(slow: bool = false) -> void:
	reclined = false
	ang_from = ang
	ang_to = Cfg.UP_ANGLE
	ang_t = 0.0
	ang_back = not slow
	ang_dur = 0.7 if slow else 0.17
	if not slow:
		pending = 2
		pending_t = 0.06


func rotate_unit() -> void:
	yaw_from = rotation.y
	yaw_to = yaw_to + rot_sign * PI
	yaw_t = 0.0
	rot_pending = true
	rot_pending_t = 0.08


func bump() -> void:
	shake_t = 0.3


func reset_now() -> void:
	reclined = false
	ang = Cfg.UP_ANGLE
	ang_from = ang
	ang_to = ang
	ang_t = 1.0
	pending = 0
	rot_pending = false
	yaw_t = 1.0
	rotation.y = 0.0
	yaw_from = 0.0
	yaw_to = 0.0
	back.rotation.x = -ang
	position = home


func tick(dt: float) -> void:
	if ang_t < 1.0:
		ang_t = minf(1.0, ang_t + dt / ang_dur)
		var k := Cfg.ease_out_back(ang_t) if ang_back else Cfg.ease_io(ang_t)
		ang = lerpf(ang_from, ang_to, k)
		back.rotation.x = -ang
	if reclined:
		recl_time += dt
	if pending != 0:
		pending_t -= dt
		if pending_t <= 0.0:
			var p := pending
			pending = 0
			game.seat_impact(self, p)
	if yaw_t < 1.0:
		yaw_t = minf(1.0, yaw_t + dt / yaw_dur)
		rotation.y = lerpf(yaw_from, yaw_to, Cfg.ease_out_back(yaw_t, 1.3))
	if rot_pending:
		rot_pending_t -= dt
		if rot_pending_t <= 0.0:
			rot_pending = false
			game.rot_impact(self)
	if shake_t > 0.0:
		shake_t -= dt
		var a := maxf(shake_t, 0.0) / 0.3
		position = home + Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * 0.05 * a
		if shake_t <= 0.0:
			position = home
