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
