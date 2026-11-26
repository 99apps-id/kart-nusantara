extends Node
class_name ComedySfx

const SAMPLE_RATE := 22050
static var _streams: Dictionary = {}


static func _load_asset(sfx_name: String, loop: bool = false) -> AudioStream:
	for ext in ["ogg", "mp3"]:
		var path := "res://assets/audio/%s.%s" % [sfx_name, ext]
		if ResourceLoader.exists(path):
			var res := load(path)
			if res is AudioStreamOggVorbis:
				(res as AudioStreamOggVorbis).loop = loop
				return res
			if res is AudioStreamMP3:
				(res as AudioStreamMP3).loop = loop
				return res
			if res is AudioStream:
				return res as AudioStream
	return null


static func _register(sfx_name: String, fallback: AudioStream, loop: bool = false) -> void:
	var loaded := _load_asset(sfx_name, loop)
	_streams[sfx_name] = loaded if loaded != null else fallback


static func _ensure_loaded() -> void:
	if _streams.size() > 0:
		return
	_register("telolet", _gen_telolet())
	_register("smash", _gen_smash())
	_register("bonk", _gen_bonk())
	_register("crash_kart", _gen_crash_kart())
	_register("crash_heavy", _gen_crash_heavy())
	_register("slip", _gen_slip_whistle())
	_register("boom", _gen_boom())
	_register("nitro", _gen_nitro())
	_register("siren", _gen_siren())
	_register("pickup", _gen_pickup())
	_register("chicken_scream", _gen_chicken_scream())
	_register("ped_scream_male", _gen_human_scream(false))
	_register("ped_scream_female", _gen_human_scream(true))
	_register("engine_loop", _gen_engine_loop(), true)
	_register("intro_fanfare", _gen_intro_fanfare())
	_register("countdown_beep", _gen_countdown_beep())
	_register("race_go", _gen_race_go())
	_register("engine_idle", _gen_engine_loop(), true)
	_register("wind_loop", _gen_nitro(), true)
	_register("birds_ambience", _gen_pickup(), true)
	_register("horn_klakson", _gen_telolet())
	_register("rocket_launch", _gen_nitro())
	_register("rocket_explosion", _gen_boom())


static func get_stream(sfx_name: String) -> AudioStream:
	_ensure_loaded()
	return _streams.get(sfx_name, null) as AudioStream


static func get_registered_names() -> Array:
	_ensure_loaded()
	return _streams.keys()


static func play(host: Node, sfx_name: String, volume_db: float = -6.0, pitch_scale: float = 1.0) -> void:
	if host == null or not host.is_inside_tree():
		return
	_ensure_loaded()
	if not _streams.has(sfx_name):
		return
	var p := AudioStreamPlayer.new()
	p.stream = _streams[sfx_name]
	p.volume_db = volume_db
	p.pitch_scale = clampf(pitch_scale, 0.4, 2.5)
	host.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


static func _build_wav(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in range(samples.size()):
		var v: int = clampi(int(samples[i] * 32767.0), -32768, 32767)
		bytes[i * 2] = v & 0xFF
		bytes[i * 2 + 1] = (v >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav


static func _gen_engine_loop() -> AudioStreamWAV:
	# Seamless looping Bajaj/2-stroke go-kart engine purr + exhaust pulse
	# Exact integer cycles (32 cycles at ~55.125 Hz -> 0.5805 s) so loop boundary has zero click
	var cycles := 32
	var base_freq := 55.125
	var count := int(round(float(cycles) * float(SAMPLE_RATE) / base_freq))
	var buf := PackedFloat32Array()
	buf.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	var lp_noise := 0.0
	for i in range(count):
		var ph := TAU * float(cycles) * float(i) / float(count)
		# Rich firing harmonics (characteristic throaty kart/bajaj exhaust)
		var pulse := sin(ph) * 0.42
		pulse += sin(ph * 2.0 + 0.4) * 0.30
		pulse += sin(ph * 3.0 + 0.9) * 0.18
		pulse += sin(ph * 4.0 + 1.3) * 0.12
		pulse += sin(ph * 6.0) * 0.07
		# Subtle cylinder chug modulation (integer harmonic = 4 cycles across buffer)
		var chug := 0.84 + 0.16 * sin(TAU * 4.0 * float(i) / float(count))
		# Soft-clipped warmth + filtered intake rasp
		var raw_n := rng.randf_range(-1.0, 1.0)
		lp_noise = lp_noise * 0.82 + raw_n * 0.18
		var raw := tanh(pulse * 1.45) * chug * 0.62 + lp_noise * 0.14
		buf[i] = clampf(raw, -0.95, 0.95)
	return _build_wav(buf, true)


static func _gen_bonk() -> AudioStreamWAV:
	# Punchy rubber suspension thump for speedbumps & light knocks
	var count := int(0.18 * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(count)
	var phase := 0.0
	for i in range(count):
		var u := float(i) / float(count)
		var freq := 210.0 * pow(0.38, u)
		phase += TAU * freq / float(SAMPLE_RATE)
		var env := pow(1.0 - u, 2.0)
		buf[i] = (sin(phase) * 0.78 + sin(phase * 2.1) * 0.22) * env * 0.82
	return _build_wav(buf)


static func _gen_crash_kart() -> AudioStreamWAV:
	# Kart-to-kart bumper collision: hollow metallic thwack + rubber squeal + thud
	var count := int(0.32 * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 313
	var lp := 0.0
	var phase := 0.0
	for i in range(count):
		var u := float(i) / float(count)
		var t := float(i) / float(SAMPLE_RATE)
		var freq := 160.0 * (1.0 - u * 0.65)
		phase += TAU * freq / float(SAMPLE_RATE)
		var thud := sin(phase) * pow(1.0 - u, 1.8) * 0.65
		var clank := (sin(TAU * 485.0 * t) * 0.5 + sin(TAU * 735.0 * t) * 0.35 + sin(TAU * 1140.0 * t) * 0.2) * pow(1.0 - u, 3.2) * 0.45
		var n := rng.randf_range(-1.0, 1.0)
		lp = lp * 0.6 + n * 0.4
		var crunch := lp * pow(1.0 - u, 2.2) * 0.55
		buf[i] = clampf(tanh((thud + clank + crunch) * 1.35) * 0.85, -0.95, 0.95)
	return _build_wav(buf)


static func _gen_crash_heavy() -> AudioStreamWAV:
	# Heavy vehicle / wall / angkot crash: sub impact + metallic crumple + debris rattle
	var count := int(0.55 * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var lp := 0.0
	var bp := 0.0
	var phase := 0.0
	for i in range(count):
		var u := float(i) / float(count)
		var t := float(i) / float(SAMPLE_RATE)
		var impact_freq := 130.0 * pow(0.28, u)
		phase += TAU * impact_freq / float(SAMPLE_RATE)
		var sub := sin(phase) * pow(1.0 - u, 1.4) * 0.72
		var n := rng.randf_range(-1.0, 1.0)
		lp = lp * 0.78 + n * 0.22
		bp = (n - lp) * 0.7 + bp * 0.3
		# Secondary metallic rattle bursts
		var rattle_env := 0.55 + 0.45 * absf(sin(TAU * 19.0 * t))
		var crunch := (lp * 0.55 + bp * 0.45) * pow(1.0 - u, 1.55) * rattle_env * 0.75
		var metal := (sin(TAU * 370.0 * t) + 0.6 * sin(TAU * 615.0 * t) + 0.4 * sin(TAU * 980.0 * t)) * pow(1.0 - u, 2.6) * 0.24
		buf[i] = clampf(tanh((sub + crunch + metal) * 1.5) * 0.88, -0.95, 0.95)
	return _build_wav(buf)


static func _gen_chicken_scream() -> AudioStreamWAV:
	# Panicked chicken squawk: "PETOK-PETOK-KAAAK!!" (4 rapid cluck-squawk bursts with raspy FM vibrato)
	var count := int(0.68 * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 555
	var phase := 0.0
	# Burst windows: [start_s, dur_s, pitch_start, pitch_peak, pitch_end]
	var bursts: Array = [
		[0.00, 0.11, 560.0, 920.0, 620.0],
		[0.13, 0.11, 610.0, 990.0, 650.0],
		[0.26, 0.12, 660.0, 1080.0, 720.0],
		[0.40, 0.26, 780.0, 1340.0, 540.0],
	]
	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var sample := 0.0
		for b in bursts:
			var t0: float = float(b[0])
			var dur: float = float(b[1])
			if t >= t0 and t < t0 + dur:
				var u := (t - t0) / dur
				var f0: float = float(b[2])
				var fp: float = float(b[3])
				var f1: float = float(b[4])
				var freq := lerpf(f0, fp, minf(1.0, u * 2.4)) if u < 0.42 else lerpf(fp, f1, (u - 0.42) / 0.58)
				# Rapid poultry throat trill (~34 Hz)
				freq += sin(TAU * 34.0 * t) * 75.0
				phase += TAU * freq / float(SAMPLE_RATE)
				# Nasal saw/formant squawk timbre
				var sq := sin(phase) * 0.48 + sin(phase * 2.0 + 0.5) * 0.34 + sin(phase * 3.0) * 0.24 + sin(phase * 4.0) * 0.14
				var rasp := rng.randf_range(-1.0, 1.0) * 0.12
				var env := sin(u * PI) * (0.75 + 0.25 * sin(TAU * 28.0 * t))
				sample += clampf(tanh((sq + rasp) * 1.4), -1.0, 1.0) * env * 0.78
		buf[i] = clampf(sample, -0.95, 0.95)
	return _build_wav(buf)


static func _gen_human_scream(is_female: bool) -> AudioStreamWAV:
	# Expressive panicked human yell ("AAAHH!!" / "AWAAAS!!") via vocal formant synthesis
	var dur := 0.58 if is_female else 0.54
	var count := int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 808 if is_female else 909
	var f0_start := 410.0 if is_female else 195.0
	var f0_peak := 685.0 if is_female else 325.0
	var f0_end := 465.0 if is_female else 215.0
	# Vowel "AA" -> "AH" formant frequencies
	var f1 := 890.0 if is_female else 720.0
	var f2 := 1460.0 if is_female else 1160.0
	var f3 := 2850.0 if is_female else 2420.0
	var glottal_phase := 0.0
	var breath_lp := 0.0
	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var u := float(i) / float(count)
		# Panicked pitch contour: sharp rise then desperate drop with vocal vibrato
		var pitch := lerpf(f0_start, f0_peak, pow(u / 0.28, 0.7)) if u < 0.28 else lerpf(f0_peak, f0_end, (u - 0.28) / 0.72)
		pitch += sin(TAU * (11.5 if is_female else 9.0) * t) * (18.0 if is_female else 11.0)
		glottal_phase += pitch / float(SAMPLE_RATE)
		if glottal_phase >= 1.0:
			glottal_phase -= floor(glottal_phase)
		# Additive formant-weighted harmonics of glottal pulse (bandlimited, natural vocal resonance)
		var v := 0.0
		for h in range(1, 14):
			var hf := pitch * float(h)
			if hf > 4800.0:
				break
			var g1 := exp(-pow((hf - f1) / 170.0, 2.0)) * 0.65
			var g2 := exp(-pow((hf - f2) / 260.0, 2.0)) * 0.45
			var g3 := exp(-pow((hf - f3) / 380.0, 2.0)) * 0.22
			var weight := (0.14 / float(h)) + g1 + g2 + g3
			v += sin(TAU * float(h) * glottal_phase) * weight
		# Slight breathy shout grit
		var n := rng.randf_range(-1.0, 1.0)
		breath_lp = breath_lp * 0.55 + n * 0.45
		var env := minf(1.0, u * 16.0) * pow(1.0 - maxf(0.0, (u - 0.55) / 0.45), 1.35)
		buf[i] = clampf(tanh((v * 0.65 + breath_lp * 0.14) * 1.25) * env * 0.85, -0.95, 0.95)
	return _build_wav(buf)


static func _gen_telolet() -> AudioStreamWAV:
	# Playful Indonesian Telolet horn cadence: Te-lo-let!
	var notes: Array = [[523.25, 0.11], [659.25, 0.11], [783.99, 0.14], [659.25, 0.10], [880.0, 0.24]]
	var total := 0
	for n in notes:
		total += int(float(n[1]) * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(total)
	var idx := 0
	for n in notes:
		var freq: float = float(n[0])
		var count: int = int(float(n[1]) * SAMPLE_RATE)
		for i in range(count):
			var t := float(i) / float(SAMPLE_RATE)
			var env := minf(1.0, float(i) / 180.0) * minf(1.0, float(count - i) / 280.0)
			var s := (sin(TAU * freq * t) * 0.55 + sin(TAU * freq * 2.0 * t) * 0.25 + sin(TAU * freq * 3.0 * t) * 0.12) * env * 0.7
			buf[idx] = s
			idx += 1
	return _build_wav(buf)


static func _gen_smash() -> AudioStreamWAV:
	var count := int(0.30 * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var env := pow(1.0 - float(i) / float(count), 1.7)
		var noise := rng.randf_range(-1.0, 1.0) * 0.58
		var boing := sin(TAU * (185.0 + 250.0 * (1.0 - t * 2.8)) * t) * 0.42
		buf[i] = (noise + boing) * env * 0.82
	return _build_wav(buf)


static func _gen_slip_whistle() -> AudioStreamWAV:
	var count := int(0.42 * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(count)
	var phase := 0.0
	for i in range(count):
		var u := float(i) / float(count)
		var freq := 420.0 + sin(u * PI * 2.0) * 520.0 + u * 650.0
		phase += TAU * maxf(freq, 120.0) / float(SAMPLE_RATE)
		var env := sin(u * PI)
		buf[i] = sin(phase) * env * 0.65
	return _build_wav(buf)


static func _gen_boom() -> AudioStreamWAV:
	var count := int(0.45 * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in range(count):
		var u := float(i) / float(count)
		var env := pow(1.0 - u, 1.5)
		var sub := sin(TAU * (135.0 * (1.0 - u * 0.75)) * (float(i) / float(SAMPLE_RATE)))
		var rumble := rng.randf_range(-1.0, 1.0) * 0.5
		buf[i] = (sub * 0.65 + rumble * 0.45) * env * 0.85
	return _build_wav(buf)


static func _gen_nitro() -> AudioStreamWAV:
	var count := int(0.35 * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for i in range(count):
		var u := float(i) / float(count)
		var env := sin(u * PI)
		var whine := sin(TAU * (240.0 + u * 520.0) * (float(i) / float(SAMPLE_RATE))) * 0.35
		var rush := rng.randf_range(-1.0, 1.0) * 0.45
		buf[i] = (whine + rush) * env * 0.65
	return _build_wav(buf)


static func _gen_siren() -> AudioStreamWAV:
	var count := int(0.48 * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(count)
	var phase := 0.0
	for i in range(count):
		var u := float(i) / float(count)
		var freq := 640.0 + sin(u * TAU * 2.5) * 260.0
		phase += TAU * freq / float(SAMPLE_RATE)
		var env := minf(1.0, u * 10.0) * minf(1.0, (1.0 - u) * 10.0)
		buf[i] = sin(phase) * env * 0.6
	return _build_wav(buf)


static func _gen_pickup() -> AudioStreamWAV:
	var count := int(0.22 * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(count)
	for i in range(count):
		var u := float(i) / float(count)
		var freq := 660.0 if u < 0.45 else 990.0
		var env := 1.0 - u
		buf[i] = sin(TAU * freq * (float(i) / float(SAMPLE_RATE))) * env * 0.6
	return _build_wav(buf)


static func _gen_intro_fanfare() -> AudioStreamWAV:
	# Energetic Nusantara arcade intro jingle (~2.65s): bright pentatonic metallophone/brass lead + bouncy bass + kick/snare + kart rev!
	var dur := 2.65
	var n := int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var notes := [
		[0.00, 0.16, 587.33],  # D5
		[0.16, 0.14, 659.25],  # E5
		[0.30, 0.18, 739.99],  # F#5
		[0.50, 0.16, 880.00],  # A5
		[0.68, 0.14, 739.99],  # F#5
		[0.84, 0.22, 880.00],  # A5
		[1.10, 0.16, 987.77],  # B5
		[1.28, 0.16, 1174.66], # D6
		[1.46, 0.14, 987.77],  # B5
		[1.62, 0.72, 1174.66], # D6 finale chord
	]
	var bass_notes := [
		[0.00, 0.26, 146.83],
		[0.28, 0.22, 185.00],
		[0.50, 0.28, 220.00],
		[0.84, 0.24, 196.00],
		[1.10, 0.24, 220.00],
		[1.36, 0.24, 246.94],
		[1.62, 0.78, 146.83],
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 9091
	var rev_phase := 0.0
	for i in range(n):
		var t := float(i) / float(SAMPLE_RATE)
		var sample := 0.0
		for nd in notes:
			var ns: float = nd[0]
			var nl: float = nd[1]
			var nf: float = nd[2]
			if t >= ns and t < ns + nl:
				var lt := t - ns
				var env := minf(lt * 70.0, 1.0) * exp(-lt * (2.6 if nl > 0.4 else 5.2))
				var ph := TAU * nf * lt
				sample += (sin(ph) * 0.55 + sin(ph * 2.0) * 0.24 + sin(ph * 3.0) * 0.12 + sin(ph * 4.02) * 0.09) * env * 0.42
				if nl > 0.4:
					sample += (sin(TAU * 880.0 * lt) * 0.30 + sin(TAU * 739.99 * lt) * 0.26 + sin(TAU * 587.33 * lt) * 0.22) * env * 0.30
		for bn in bass_notes:
			var bs: float = bn[0]
			var bl: float = bn[1]
			var bf: float = bn[2]
			if t >= bs and t < bs + bl:
				var lt := t - bs
				var env := minf(lt * 50.0, 1.0) * exp(-lt * 3.5)
				var ph := TAU * bf * lt
				sample += (sin(ph) * 0.72 + sin(ph * 2.0) * 0.28) * env * 0.34
		var beat_t := fmod(t, 0.28)
		if t < 2.15:
			var beat_idx := int(floor(t / 0.28))
			if beat_idx % 2 == 0:
				var k_env := exp(-beat_t * 30.0)
				var k_f := lerpf(150.0, 46.0, minf(beat_t * 14.0, 1.0))
				sample += sin(TAU * k_f * beat_t) * k_env * 0.34
			else:
				var s_env := exp(-beat_t * 36.0)
				sample += (rng.randf_range(-1.0, 1.0) * 0.7 + sin(TAU * 210.0 * beat_t) * 0.3) * s_env * 0.18
		if t >= 1.95:
			var rt := t - 1.95
			var rev_f := 65.0 + sin(minf(rt / 0.65, 1.0) * PI) * 85.0
			rev_phase += TAU * rev_f / float(SAMPLE_RATE)
			var r_env := sin(minf(rt / 0.65, 1.0) * PI) * 0.22
			sample += (sin(rev_phase) * 0.5 + sin(rev_phase * 2.0) * 0.35 + sin(rev_phase * 3.0) * 0.15) * r_env
		buf[i] = clampf(sample, -0.95, 0.95)
	return _build_wav(buf)


static func _gen_countdown_beep() -> AudioStreamWAV:
	var n := int(0.20 * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in range(n):
		var t := float(i) / float(SAMPLE_RATE)
		var env := minf(t * 90.0, 1.0) * exp(-t * 11.0)
		var ph := TAU * 587.33 * t
		buf[i] = clampf((sin(ph) * 0.72 + sin(ph * 2.0) * 0.22 + sin(ph * 3.0) * 0.08) * env * 0.55, -0.95, 0.95)
	return _build_wav(buf)


static func _gen_race_go() -> AudioStreamWAV:
	var n := int(0.55 * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in range(n):
		var t := float(i) / float(SAMPLE_RATE)
		var env := minf(t * 70.0, 1.0) * exp(-t * 3.8)
		var s := sin(TAU * 880.0 * t) * 0.45 + sin(TAU * 1174.66 * t) * 0.40 + sin(TAU * 1479.98 * t) * 0.28
		buf[i] = clampf(s * env * 0.58, -0.95, 0.95)
	return _build_wav(buf)
