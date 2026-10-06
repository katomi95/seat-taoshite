class_name Cfg

# 車両の座標系：通路は x=0 、車両は z 方向に長い。座席は初期状態で +Z を向く。
# 敵は -Z 側の扉から来て +Z のプレイヤーへ向かう。
const ROW_PITCH := 1.3
const ROWS := 9
const ROW0_Z := 4.2
const UNIT_X := 1.05
const UNIT_W := 1.1
const AISLE_HALF := 0.5
const WALL_X := 1.75
const Z_MIN := -8.3
const Z_MAX := 6.6
const DOOR_Z := -9.0

const UP_ANGLE := 0.08
const RECLINE_ANGLE := 1.1

# 当たり判定（座席ローカル）：背もたれが倒れる範囲
const ZONE_HX := 0.82
const ZONE_Z0 := -1.17
const ZONE_Z1 := -0.10


static func row_z(i: int) -> float:
	return ROW0_Z - ROW_PITCH * float(i)


static func ease_out_back(x: float, c1: float = 1.70158) -> float:
	var c3 := c1 + 1.0
	var u := x - 1.0
	return 1.0 + c3 * u * u * u + c1 * u * u


static func ease_io(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)
