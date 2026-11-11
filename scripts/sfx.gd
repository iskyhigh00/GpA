class_name Sfx
extends RefCounted
## Sonidos provisionales generados por código (sin archivos de audio).

const RATE := 22050


static func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


static func tone(freq: float, dur: float, vol: float = 0.5, decay: float = 3.0) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var env := exp(-decay * t / dur)
		var s := sin(TAU * freq * t) * env * vol
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	return _wav(data)


static func clang(dur: float = 0.6, vol: float = 0.6) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var partials: Array[float] = [430.0, 1130.0, 1790.0, 2610.0]
	for i in n:
		var t := float(i) / RATE
		var s := 0.0
		for j in partials.size():
			s += sin(TAU * partials[j] * t) * exp(-(5.0 + j * 4.0) * t) / (1.0 + j)
		data.encode_s16(i * 2, int(clampf(s * vol, -1.0, 1.0) * 32767.0))
	return _wav(data)


static func rumble(dur: float = 1.2, vol: float = 0.4) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var s := (sin(TAU * 55.0 * t) + 0.5 * sin(TAU * 83.0 * t + 1.0)) * vol * 0.6
		s *= minf(1.0, t * 8.0) * minf(1.0, (dur - t) * 4.0)
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	return _wav(data)


static func noise_burst(dur: float, vol: float, decay: float, smooth: float) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * smooth
		var s := lp * exp(-decay * t / dur) * vol
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	return _wav(data)


static func build_all() -> Dictionary:
	return {
		"beep": tone(880.0, 0.28, 0.45, 2.0),
		"clang": clang(),
		"rumble": rumble(),
		"thud": noise_burst(0.5, 1.4, 6.0, 0.06),
		"swish": noise_burst(0.18, 0.5, 3.0, 0.35),
		"hit": noise_burst(0.25, 1.6, 5.0, 0.12),
		"pickup": tone(660.0, 0.2, 0.4, 3.0),
		"push": tone(240.0, 0.18, 0.5, 4.0),
		"alarm": tone(520.0, 0.35, 0.5, 1.5),
		"door": noise_burst(0.6, 0.7, 3.0, 0.03),
		"step": noise_burst(0.07, 0.5, 4.0, 0.2),
		"dodge": noise_burst(0.3, 0.55, 2.0, 0.5),
		"block": clang(0.3, 0.5),
		"slam": noise_burst(0.7, 1.8, 5.0, 0.04),
		"perfect": tone(1320.0, 0.35, 0.35, 3.0),
	}


## Ambiente en bucle: oleaje, bordón grave, campana lejana y chirridos. Sin archivos.
static func music() -> AudioStreamWAV:
	var rate := 11025
	var dur := 8
	var n := rate * dur
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var nz := PackedFloat32Array()
	nz.resize(n * 2)
	var lp := 0.0
	for i in n * 2:
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.04
		nz[i] = lp
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / rate
		var w := minf(1.0, float(i) / (rate * 0.5))
		var sea := (nz[i] * w + nz[i + n] * (1.0 - w)) * 5.0
		sea *= 0.35 + 0.65 * (0.5 + 0.5 * sin(TAU * t / dur * 2.0))
		var drone := sin(TAU * 55.0 * t) * 0.22 + sin(TAU * 82.5 * t) * 0.12 + sin(TAU * 65.25 * t + 1.0) * 0.08
		drone *= 0.7 + 0.3 * sin(TAU * t / dur * 3.0)
		var bt := fmod(t, 4.0)
		var bell := sin(TAU * 329.625 * bt) * exp(-bt * 1.6) * 0.08 * (1.0 if int(t / 4.0) % 2 == 0 else 0.0)
		bell += sin(TAU * 494.4 * bt) * exp(-bt * 2.4) * 0.03 * (1.0 if int(t / 4.0) % 2 == 0 else 0.0)
		var creak := sin(TAU * (900.0 + 120.0 * sin(TAU * t / dur * 5.0)) * t) * 0.012 * maxf(0.0, sin(TAU * t / dur * 1.0 + 2.0))
		var s := sea * 0.5 + drone + bell + creak
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	var wv := AudioStreamWAV.new()
	wv.format = AudioStreamWAV.FORMAT_16_BITS
	wv.mix_rate = rate
	wv.stereo = false
	wv.data = data
	wv.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wv.loop_begin = 0
	wv.loop_end = n
	return wv
