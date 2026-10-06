class_name Models

static var _cache := {}


static func mat(c: Color, rough: float = 0.85, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


static func cmat(c: Color, rough: float = 0.85, metal: float = 0.0) -> StandardMaterial3D:
	var k := str(c) + str(rough) + str(metal)
	if not _cache.has(k):
		_cache[k] = mat(c, rough, metal)
	return _cache[k]


static func glow(c: Color, e: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = e
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


static func box(parent: Node, size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


static func ball(parent: Node, r: float, pos: Vector3, m: Material, sc: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 14
	sm.rings = 8
	mi.mesh = sm
	mi.material_override = m
	mi.position = pos
	mi.scale = sc
	parent.add_child(mi)
	return mi


static func cyl(parent: Node, r: float, h: float, pos: Vector3, m: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 20
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


# ---------------------------------------------------------------- 座席

static func build_seat(s: Seat) -> void:
	var blue := cmat(Color(0.13, 0.27, 0.62), 0.9)
	var cream := cmat(Color(0.95, 0.91, 0.78), 0.9)
	var grey := cmat(Color(0.62, 0.64, 0.7), 0.35, 0.6)
	var orange := cmat(Color(1.0, 0.5, 0.08), 0.35, 0.3)
	var yellow := cmat(Color(0.78, 0.62, 0.12), 0.7)
	var white := cmat(Color(0.97, 0.97, 1.0), 0.7)
	# 回転台（回転軸の見える化）
	cyl(s, 0.62, 0.03, Vector3(0, 0.015, 0), yellow)
	box(s, Vector3(0.14, 0.04, 0.2), Vector3(0, 0.03, 0.52), orange)
	box(s, Vector3(0.14, 0.04, 0.2), Vector3(0, 0.03, -0.52), white)
	cyl(s, 0.2, 0.3, Vector3(0, 0.17, 0), grey)
	# 座面とひじ掛け
	box(s, Vector3(1.1, 0.14, 0.52), Vector3(0, 0.4, 0.02), blue)
	for sx in [-0.56, 0.0, 0.56]:
		box(s, Vector3(0.07, 0.2, 0.46), Vector3(sx, 0.57, -0.02), grey)
	# 背もたれ（ヒンジを中心に倒れる）
	var pv := Node3D.new()
	pv.position = Vector3(0, 0.5, -0.22)
	pv.rotation.x = -Cfg.UP_ANGLE
	s.add_child(pv)
	s.back = pv
	box(pv, Vector3(1.1, 0.78, 0.12), Vector3(0, 0.39, 0), blue)
	box(pv, Vector3(0.95, 0.22, 0.14), Vector3(0, 0.64, 0.0), cream)
	box(pv, Vector3(1.1, 0.05, 0.14), Vector3(0, 0.78, 0), white)
	cyl(pv, 0.055, 1.16, Vector3.ZERO, orange, Vector3(0, 0, PI / 2.0))
	# 倒れる範囲の床表示
	var zm := StandardMaterial3D.new()
	zm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	zm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	zm.cull_mode = BaseMaterial3D.CULL_DISABLED
	zm.albedo_color = Color(1.0, 0.85, 0.2, 0.3)
	var pm := PlaneMesh.new()
	pm.size = Vector2(1.5, Cfg.ZONE_Z1 - Cfg.ZONE_Z0)
	var zone := MeshInstance3D.new()
	zone.mesh = pm
	zone.material_override = zm
	zone.position = Vector3(0, 0.045, (Cfg.ZONE_Z0 + Cfg.ZONE_Z1) * 0.5)
	zone.visible = false
	s.add_child(zone)
	s.zone = zone


# ---------------------------------------------------------------- 人物

static func _pm(mats: Array, c: Color) -> StandardMaterial3D:
	var m := mat(c, 0.8)
	mats.append(m)
	return m


static func person(shirt: Color, pants: Color, hair: Color, angry: bool = false, sc: float = 1.0, shades: bool = false) -> Dictionary:
	var mats: Array = []
	var m_shirt := _pm(mats, shirt)
	var m_pants := _pm(mats, pants)
	var m_skin := _pm(mats, Color(0.97, 0.79, 0.63))
	var m_hair := _pm(mats, hair)
	var m_shoe := _pm(mats, Color(0.12, 0.1, 0.1))
	var m_tie := _pm(mats, Color(0.85, 0.15, 0.15))
	var m_black := mat(Color(0.05, 0.05, 0.06), 0.5)
	var root := Node3D.new()
	root.scale = Vector3.ONE * sc
	var thighs: Array = []
	var shins: Array = []
	for sx in [-1.0, 1.0]:
		var th := Node3D.new()
		th.position = Vector3(sx * 0.1, 0.45, 0)
		root.add_child(th)
		box(th, Vector3(0.15, 0.24, 0.16), Vector3(0, -0.12, 0), m_pants)
		var sh := Node3D.new()
		sh.position = Vector3(0, -0.24, 0)
		th.add_child(sh)
		box(sh, Vector3(0.14, 0.21, 0.15), Vector3(0, -0.105, 0), m_pants)
		box(sh, Vector3(0.15, 0.06, 0.26), Vector3(0, -0.18, 0.05), m_shoe)
		thighs.append(th)
		shins.append(sh)
	var up := Node3D.new()
	up.position = Vector3(0, 0.45, 0)
	root.add_child(up)
	box(up, Vector3(0.42, 0.5, 0.24), Vector3(0, 0.25, 0), m_shirt)
	box(up, Vector3(0.07, 0.3, 0.02), Vector3(0, 0.27, 0.125), m_tie)
	var head := Node3D.new()
	head.position = Vector3(0, 0.68, 0)
	up.add_child(head)
	ball(head, 0.18, Vector3.ZERO, m_skin)
	ball(head, 0.19, Vector3(0, 0.09, -0.02), m_hair, Vector3(1.0, 0.6, 1.0))
	if shades:
		box(head, Vector3(0.32, 0.06, 0.04), Vector3(0, 0.02, 0.16), m_black)
	else:
		for ex in [-0.07, 0.07]:
			ball(head, 0.03, Vector3(ex, 0.02, 0.165), m_black)
		if angry:
			for k in [-1.0, 1.0]:
				var b := box(head, Vector3(0.1, 0.025, 0.02), Vector3(k * 0.07, 0.085, 0.17), m_black)
				b.rotation.z = -k * 0.45
	if angry:
		box(head, Vector3(0.09, 0.02, 0.02), Vector3(0, -0.08, 0.17), m_black)
	var arms: Array = []
	for sx in [-1.0, 1.0]:
		var ar := Node3D.new()
		ar.position = Vector3(sx * 0.27, 0.44, 0)
		up.add_child(ar)
		box(ar, Vector3(0.1, 0.4, 0.1), Vector3(0, -0.19, 0), m_shirt)
		ball(ar, 0.06, Vector3(0, -0.4, 0), m_skin)
		arms.append(ar)
	return {
		"root": root, "upper": up, "head": head,
		"legL": thighs[0], "legR": thighs[1], "shinL": shins[0], "shinR": shins[1],
		"armL": arms[0], "armR": arms[1], "mats": mats,
	}


static func pose_sit(p: Dictionary) -> void:
	for k in ["legL", "legR"]:
		var n: Node3D = p[k]
		n.rotation.x = -PI / 2.0
	for k in ["shinL", "shinR"]:
		var n: Node3D = p[k]
		n.rotation.x = PI / 2.0


static func pose_stand(p: Dictionary) -> void:
	for k in ["legL", "legR", "shinL", "shinR"]:
		var n: Node3D = p[k]
		n.rotation = Vector3.ZERO


# 人物を座席に座らせる。上半身は背もたれにぶら下げ、倒れる動きについてくる。
static func sit(p: Dictionary, seat: Seat, lx: float) -> void:
	var root: Node3D = p.root
	var up: Node3D = p.upper
	if root.get_parent() != null:
		root.get_parent().remove_child(root)
	seat.add_child(root)
	root.position = Vector3(lx, 0.07, -0.04)
	root.rotation = Vector3.ZERO
	pose_sit(p)
	up.get_parent().remove_child(up)
	seat.back.add_child(up)
	up.position = Vector3(lx, 0.02, 0.18)
	up.rotation = Vector3.ZERO


static func stand(p: Dictionary, parent: Node) -> void:
	var root: Node3D = p.root
	var up: Node3D = p.upper
	up.get_parent().remove_child(up)
	root.add_child(up)
	up.position = Vector3(0, 0.45, 0)
	up.rotation = Vector3.ZERO
	root.get_parent().remove_child(root)
	parent.add_child(root)
	root.rotation = Vector3.ZERO
	pose_stand(p)


# ---------------------------------------------------------------- 車両

static func build_car(parent: Node3D) -> Dictionary:
	var floor_m := cmat(Color(0.34, 0.36, 0.43), 0.95)
	var aisle_m := cmat(Color(0.62, 0.22, 0.24), 0.95)
	var wall_m := cmat(Color(0.93, 0.9, 0.8), 0.9)
	var dark := cmat(Color(0.12, 0.12, 0.16), 0.9)
	var steel := cmat(Color(0.72, 0.74, 0.8), 0.4, 0.5)
	var z0 := Cfg.DOOR_Z
	var z1 := 7.2
	var len := z1 - z0
	var zc := (z0 + z1) * 0.5
	# 床（断面が見える厚み）
	box(parent, Vector3(3.5, 0.3, len), Vector3(0, -0.15, zc), floor_m)
	box(parent, Vector3(1.0, 0.012, len), Vector3(0, 0.006, zc), aisle_m)
	# 手前側の帯（カットモデル）
	box(parent, Vector3(0.06, 0.34, len), Vector3(1.78, -0.15, zc), cmat(Color(0.1, 0.55, 0.9), 0.5))
	box(parent, Vector3(0.06, 0.08, len), Vector3(1.78, -0.02, zc), cmat(Color(0.95, 0.95, 0.95), 0.5))
	# 奥側の壁（窓は抜く）
	var wx := -Cfg.WALL_X - 0.05
	box(parent, Vector3(0.1, 0.9, len), Vector3(wx, 0.45, zc), wall_m)
	box(parent, Vector3(0.1, 0.5, len), Vector3(wx, 2.15, zc), wall_m)
	var pz := z1 - 0.6
	while pz > z0:
		box(parent, Vector3(0.1, 1.0, 0.28), Vector3(wx, 1.4, pz), wall_m)
		pz -= 2.6
	box(parent, Vector3(0.14, 0.05, len), Vector3(wx + 0.02, 0.93, zc), steel)
	# 天井側の荷棚（奥だけ）
	box(parent, Vector3(0.5, 0.04, len), Vector3(-1.5, 2.0, zc), steel)
	# 後方の壁と扉（敵の入口）
	box(parent, Vector3(1.28, 2.4, 0.2), Vector3(-1.11, 1.2, z0), wall_m)
	box(parent, Vector3(1.28, 2.4, 0.2), Vector3(1.11, 1.2, z0), wall_m)
	box(parent, Vector3(1.0, 0.35, 0.2), Vector3(0, 2.225, z0), wall_m)
	box(parent, Vector3(1.4, 2.4, 1.5), Vector3(0, 1.2, z0 - 0.9), dark)
	var dl := box(parent, Vector3(0.5, 2.05, 0.06), Vector3(-0.25, 1.025, z0 + 0.13), steel)
	var dr := box(parent, Vector3(0.5, 2.05, 0.06), Vector3(0.25, 1.025, z0 + 0.13), steel)
	box(dl, Vector3(0.3, 0.5, 0.02), Vector3(0, 0.4, 0.04), cmat(Color(0.5, 0.75, 0.95), 0.2))
	box(dr, Vector3(0.3, 0.5, 0.02), Vector3(0, 0.4, 0.04), cmat(Color(0.5, 0.75, 0.95), 0.2))
	# 前方の壁
	box(parent, Vector3(3.5, 2.4, 0.2), Vector3(0, 1.2, z1), wall_m)
	# 窓の外の景色
	var scenery: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 34:
		var h := rng.randf_range(1.0, 6.0)
		var w := rng.randf_range(1.2, 3.0)
		var c := Color(rng.randf_range(0.35, 0.62), rng.randf_range(0.42, 0.66), rng.randf_range(0.55, 0.78))
		var b := box(parent, Vector3(w, h, rng.randf_range(1.2, 3.0)),
			Vector3(-rng.randf_range(4.0, 9.0), h * 0.5 - 0.5, rng.randf_range(-16.0, 16.0)), cmat(c, 0.9))
		scenery.append(b)
	# 線路（車体の下に見える）
	box(parent, Vector3(40.0, 0.2, 60.0), Vector3(2.0, -1.3, 0), cmat(Color(0.42, 0.4, 0.37), 1.0))
	for rx in [-0.75, 0.75]:
		box(parent, Vector3(0.12, 0.14, 60.0), Vector3(rx, -1.1, 0), steel)
	var slp := cmat(Color(0.3, 0.22, 0.16), 1.0)
	for i in 40:
		scenery.append(box(parent, Vector3(2.6, 0.1, 0.3), Vector3(0, -1.15, -17.0 + 0.85 * float(i)), slp))
	return {"scenery": scenery, "doorL": dl, "doorR": dr}
