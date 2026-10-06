extends Node

# 効果音はすべて起動時に数式で合成する（音源ファイルなし）。
const RATE := 16000

var snd := {}
var players: Array[AudioStreamPlayer] = []
var idx := 0
var rng := RandomNumberGenerator.new()
var rumble_p: AudioStreamPlayer
var bgm_p: AudioStreamPlayer


func _ready() -> void:
	rng.seed = 5
	for i in 14:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	snd["gakon"] = _gakon()
	snd["bata"] = _bata()
	snd["gon"] = _gon(0.35, 150.0, 55.0)
	snd["don"] = _gon(0.6, 90.0, 28.0)
	snd["thud"] = _gon(0.18, 110.0, 50.0)
	snd["whoosh"] = _whoosh()
	snd["gatsu"] = _gatsu()
	snd["ding"] = _tone(0.45, [880.0, 1318.0], 7.0)
	snd["tick"] = _tone(0.1, [1200.0], 30.0)
	snd["boing"] = _boing()
	snd["sting"] = _sting()
	snd["door"] = _door()
	snd["pinpon"] = _pinpon()
	snd["hurt"] = _hurt()
	snd["squish"] = _squish()
	rumble_p = AudioStreamPlayer.new()
	rumble_p.stream = _rumble()
	rumble_p.volume_db = -20.0
	add_child(rumble_p)
	bgm_p = AudioStreamPlayer.new()
	bgm_p.stream = _bgm()
	bgm_p.volume_db = -13.0
	add_child(bgm_p)


func start_rumble() -> void:
	if not rumble_p.playing:
		rumble_p.play()


func bgm(on: bool) -> void:
	if on and not bgm_p.playing:
		bgm_p.play()
	elif not on:
		bgm_p.stop()


func play(n: String, pitch: float = 1.0, vol: float = 0.0) -> void:
	if not snd.has(n):
		return
	var p := players[idx]
	idx = (idx + 1) % players.size()
	p.stream = snd[n]
	p.pitch_scale = pitch
	p.volume_db = vol
	p.play()


func _wav(f: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	var b := PackedByteArray()
	b.resize(f.size() * 2)
	for i in f.size():
		b.encode_s16(i * 2, int(clampf(f[i], -1.0, 1.0) * 30000.0))
	s.data = b
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = f.size()
	return s


func _buf(dur: float) -> PackedFloat32Array:
	var f := PackedFloat32Array()
	f.resize(int(dur * float(RATE)))
	return f


func _gakon() -> AudioStreamWAV:
	var f := _buf(0.35)
	for i in f.size():
		var t := float(i) / float(RATE)
		var v := 0.0
		for hit in [0.0, 0.055]:
			var tt: float = t - hit
			if tt >= 0.0:
				var e := exp(-tt * 38.0)
				v += e * (sin(TAU * 310.0 * tt) * 0.5 + sin(TAU * 870.0 * tt) * 0.3 + sin(TAU * 1410.0 * tt) * 0.2)
				v += rng.randf_range(-1.0, 1.0) * 0.5 * exp(-tt * 120.0)
		v += sin(TAU * 95.0 * t) * exp(-t * 18.0) * 0.7
		f[i] = v * 0.55
	return _wav(f)


func _bata() -> AudioStreamWAV:
	var f := _buf(0.4)
	var lp := 0.0
	for i in f.size():
		var t := float(i) / float(RATE)
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.35
		var th := sin(TAU * (45.0 + 70.0 * exp(-t * 22.0)) * t * 1.0) * exp(-t * 11.0)
		f[i] = (lp * 0.9 * exp(-t * 16.0) + th * 0.9) * 0.8
	return _wav(f)


func _gon(dur: float, f0: float, f1: float) -> AudioStreamWAV:
	var f := _buf(dur)
	var ph := 0.0
	for i in f.size():
		var t := float(i) / float(RATE)
		var fr := f1 + (f0 - f1) * exp(-t * 24.0)
		ph += TAU * fr / float(RATE)
		var click := rng.randf_range(-1.0, 1.0) * exp(-t * 150.0) * 0.6
		f[i] = (sin(ph) * exp(-t * (6.0 / dur * 0.6)) + click) * 0.9
	return _wav(f)


func _whoosh() -> AudioStreamWAV:
	var f := _buf(0.5)
	var lp := 0.0
	for i in f.size():
		var t := float(i) / float(RATE)
		var u := t / 0.5
		var env := sin(PI * u)
		var a := 0.08 + 0.5 * sin(PI * u)
		lp += (rng.randf_range(-1.0, 1.0) - lp) * a
		f[i] = lp * env * 1.6
	return _wav(f)


func _gatsu() -> AudioStreamWAV:
	var f := _buf(0.22)
	for i in f.size():
		var t := float(i) / float(RATE)
		var sq := 1.0 if sin(TAU * 180.0 * t) > 0.0 else -1.0
		var v := sq * 0.4 * exp(-t * 30.0) + rng.randf_range(-1.0, 1.0) * 0.6 * exp(-t * 90.0)
		v += sin(TAU * 70.0 * t) * exp(-t * 20.0) * 0.8
		f[i] = v * 0.8
	return _wav(f)


func _tone(dur: float, freqs: Array, decay: float) -> AudioStreamWAV:
	var f := _buf(dur)
	for i in f.size():
		var t := float(i) / float(RATE)
		var v := 0.0
		for fr in freqs:
			v += sin(TAU * float(fr) * t)
		f[i] = v / float(freqs.size()) * exp(-t * decay) * 0.6
	return _wav(f)


func _boing() -> AudioStreamWAV:
	var f := _buf(0.4)
	var ph := 0.0
	for i in f.size():
		var t := float(i) / float(RATE)
		var fr := 220.0 + 520.0 * (1.0 - exp(-t * 9.0)) + sin(t * 40.0) * 30.0
		ph += TAU * fr / float(RATE)
		f[i] = sin(ph) * exp(-t * 6.0) * 0.6
	return _wav(f)


func _sting() -> AudioStreamWAV:
	var f := _buf(0.9)
	var ph := 0.0
	for i in f.size():
		var t := float(i) / float(RATE)
		var fr := 220.0 * exp(-t * 1.2)
		ph += TAU * fr / float(RATE)
		var saw := fmod(ph / TAU, 1.0) * 2.0 - 1.0
		var boom := sin(TAU * 48.0 * t) * exp(-t * 4.0)
		f[i] = (saw * 0.35 * exp(-t * 3.0) + boom * 0.9) * 0.8
	return _wav(f)


func _door() -> AudioStreamWAV:
	var f := _buf(0.6)
	for i in f.size():
		var t := float(i) / float(RATE)
		var rat := sin(TAU * 31.0 * t) * 0.5 + 0.5
		var v := rng.randf_range(-1.0, 1.0) * rat * 0.5 * (1.0 - t / 0.6)
		if t > 0.5:
			v += sin(TAU * 120.0 * t) * exp(-(t - 0.5) * 40.0) * 0.8
		f[i] = v * 0.7
	return _wav(f)


func _pinpon() -> AudioStreamWAV:
	var f := _buf(1.1)
	for i in f.size():
		var t := float(i) / float(RATE)
		var v := 0.0
		if t < 0.5:
			v = sin(TAU * 740.0 * t) * exp(-t * 5.0)
		else:
			var tt := t - 0.5
			v = sin(TAU * 587.0 * tt) * exp(-tt * 4.5)
		f[i] = v * 0.5
	return _wav(f)


func _hurt() -> AudioStreamWAV:
	var f := _buf(0.3)
	var ph := 0.0
	for i in f.size():
		var t := float(i) / float(RATE)
		ph += TAU * (420.0 - 280.0 * t / 0.3) / float(RATE)
		f[i] = (sin(ph) * 0.6 + rng.randf_range(-1.0, 1.0) * 0.25 * exp(-t * 40.0)) * (1.0 - t / 0.3)
	return _wav(f)


func _squish() -> AudioStreamWAV:
	var f := _buf(0.3)
	var ph := 0.0
	for i in f.size():
		var t := float(i) / float(RATE)
		ph += TAU * (500.0 * exp(-t * 7.0) + 90.0) / float(RATE)
		f[i] = sin(ph) * 0.7 * exp(-t * 8.0)
	return _wav(f)


func _rumble() -> AudioStreamWAV:
	var n := RATE
	var f := PackedFloat32Array()
	f.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / float(RATE)
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.04
		var beat := 0.0
		for hit in [0.0, 0.2, 0.5, 0.7]:
			var tt: float = fposmod(t - hit, 1.0)
			beat += exp(-tt * 28.0)
		f[i] = lp * (0.5 + 0.9 * minf(beat, 1.0)) * 1.6
	# ループの継ぎ目を馴らす
	for i in 200:
		var a := float(i) / 200.0
		f[i] = f[i] * a + f[n - 200 + i] * (1.0 - a) * 0.0
	return _wav(f, true)


func _bgm() -> AudioStreamWAV:
	var beat := 0.38
	var steps := 16
	var dur := beat * 0.5 * float(steps)
	var f := _buf(dur)
	var riff := [45, 0, 45, 48, 0, 45, 50, 0, 47, 0, 47, 50, 0, 52, 50, 48]
	for i in f.size():
		var t := float(i) / float(RATE)
		var sp := t / (beat * 0.5)
		var step := int(sp) % steps
		var st := (sp - floorf(sp)) * beat * 0.5
		var v := 0.0
		# キック（4つ打ち）
		var tb := fposmod(t, beat)
		v += sin(TAU * 52.0 * tb * (1.0 + 2.2 * exp(-tb * 28.0))) * exp(-tb * 12.0) * 0.9
		# ハット（裏）
		var th := fposmod(t - beat * 0.5, beat)
		v += rng.randf_range(-1.0, 1.0) * exp(-th * 70.0) * 0.18
		# ベース
		var nn: int = riff[step]
		if nn > 0:
			var fr := 440.0 * pow(2.0, float(nn - 69) / 12.0)
			var s1 := sin(TAU * fr * st)
			var sq := 1.0 if s1 > 0.0 else -1.0
			v += (s1 * 0.5 + sq * 0.2) * exp(-st * 5.5) * 0.5
		f[i] = v * 0.7
	return _wav(f, true)
