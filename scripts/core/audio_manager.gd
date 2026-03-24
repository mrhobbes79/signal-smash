extends Node
## AudioManager — Autoload singleton for all game audio.
## Generates procedural SFX and music using AudioStreamWAV synthesis.
## Bus layout: Master → Music, SFX, Voice

const SAMPLE_RATE: int = 22050

## Audio buses (created at runtime)
var _music_bus: int = -1
var _sfx_bus: int = -1

## Music state
var _music_player: AudioStreamPlayer
var _is_music_playing: bool = false

## SFX cache
var _sfx_cache: Dictionary = {}

func _ready() -> void:
	_setup_buses()
	_generate_sfx_cache()
	_setup_music_player()
	print("[AUDIO] AudioManager initialized")

func _setup_buses() -> void:
	# Add SFX bus
	AudioServer.add_bus()
	_sfx_bus = AudioServer.bus_count - 1
	AudioServer.set_bus_name(_sfx_bus, "SFX")
	AudioServer.set_bus_send(_sfx_bus, "Master")

	# Add Music bus
	AudioServer.add_bus()
	_music_bus = AudioServer.bus_count - 1
	AudioServer.set_bus_name(_music_bus, "Music")
	AudioServer.set_bus_send(_music_bus, "Master")
	AudioServer.set_bus_volume_db(_music_bus, -6.0)  # Music slightly quieter

func _setup_music_player() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)

## ═══════════ SFX GENERATION ═══════════

func _generate_sfx_cache() -> void:
	_sfx_cache["hit_light"] = _gen_hit(0.15, 200.0, 0.6)
	_sfx_cache["hit_heavy"] = _gen_hit(0.25, 120.0, 0.9)
	_sfx_cache["ko"] = _gen_ko()
	_sfx_cache["jump"] = _gen_sweep(0.12, 300.0, 600.0, 0.3)
	_sfx_cache["land"] = _gen_noise_burst(0.08, 0.3)
	_sfx_cache["menu_move"] = _gen_beep(0.05, 800.0, 0.2)
	_sfx_cache["menu_select"] = _gen_beep(0.1, 1200.0, 0.3)
	_sfx_cache["signal_lock"] = _gen_signal_lock()
	_sfx_cache["link_down"] = _gen_link_down()
	_sfx_cache["modem"] = _gen_modem_handshake()
	_sfx_cache["align_beep"] = _gen_beep(0.06, 1000.0, 0.2)
	_sfx_cache["score"] = _gen_sweep(0.15, 400.0, 800.0, 0.3)
	_sfx_cache["victory"] = _gen_victory()

## Play a cached SFX
func play_sfx(sfx_name: String, volume_db: float = 0.0) -> void:
	if sfx_name not in _sfx_cache:
		push_warning("[AUDIO] SFX not found: %s" % sfx_name)
		return
	var player := AudioStreamPlayer.new()
	player.stream = _sfx_cache[sfx_name]
	player.bus = "SFX"
	player.volume_db = volume_db
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

## Play SFX at a 3D position
func play_sfx_3d(sfx_name: String, position: Vector3, volume_db: float = 0.0) -> AudioStreamPlayer3D:
	if sfx_name not in _sfx_cache:
		return null
	var player := AudioStreamPlayer3D.new()
	player.stream = _sfx_cache[sfx_name]
	player.volume_db = volume_db
	player.position = position
	get_tree().current_scene.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
	return player

## ═══════════ MUSIC ═══════════

func play_music_monterrey() -> void:
	if _is_music_playing:
		return
	_music_player.stream = _gen_monterrey_beat()
	_music_player.play()
	_is_music_playing = true

func play_music_menu() -> void:
	if _is_music_playing:
		stop_music()
	_music_player.stream = _gen_menu_ambient()
	_music_player.play()
	_is_music_playing = true

func stop_music() -> void:
	_music_player.stop()
	_is_music_playing = false

## ═══════════ GENERATORS ═══════════

func _gen_beep(duration: float, freq: float, volume: float) -> AudioStreamWAV:
	var samples := _make_samples(duration)
	for i in range(samples.size()):
		var t: float = float(i) / SAMPLE_RATE
		var envelope: float = 1.0 - (t / duration)  # Fade out
		samples[i] = int(sin(t * freq * TAU) * 32000.0 * volume * envelope)
	return _samples_to_wav(samples)

func _gen_hit(duration: float, freq: float, volume: float) -> AudioStreamWAV:
	var samples := _make_samples(duration)
	for i in range(samples.size()):
		var t: float = float(i) / SAMPLE_RATE
		var envelope: float = exp(-t * 15.0)  # Fast decay
		var noise: float = randf_range(-1.0, 1.0) * 0.3
		var tone: float = sin(t * freq * TAU) * 0.7
		# RF static filter on top
		var rf_static: float = sin(t * 4500.0 * TAU) * 0.1 * envelope
		samples[i] = int((tone + noise + rf_static) * 32000.0 * volume * envelope)
	return _samples_to_wav(samples)

func _gen_noise_burst(duration: float, volume: float) -> AudioStreamWAV:
	var samples := _make_samples(duration)
	for i in range(samples.size()):
		var t: float = float(i) / SAMPLE_RATE
		var envelope: float = exp(-t * 20.0)
		samples[i] = int(randf_range(-1.0, 1.0) * 32000.0 * volume * envelope)
	return _samples_to_wav(samples)

func _gen_sweep(duration: float, freq_start: float, freq_end: float, volume: float) -> AudioStreamWAV:
	var samples := _make_samples(duration)
	for i in range(samples.size()):
		var t: float = float(i) / SAMPLE_RATE
		var progress: float = t / duration
		var freq: float = lerpf(freq_start, freq_end, progress)
		var envelope: float = 1.0 - progress
		samples[i] = int(sin(t * freq * TAU) * 32000.0 * volume * envelope)
	return _samples_to_wav(samples)

func _gen_ko() -> AudioStreamWAV:
	# Descending buzz + static — "link down" sound
	var duration: float = 0.6
	var samples := _make_samples(duration)
	for i in range(samples.size()):
		var t: float = float(i) / SAMPLE_RATE
		var freq: float = lerpf(400.0, 60.0, t / duration)
		var envelope: float = 1.0 - (t / duration) * 0.5
		var buzz: float = sin(t * freq * TAU) * 0.5
		var static_noise: float = randf_range(-1.0, 1.0) * 0.3 * (t / duration)
		# Square wave undertone
		var square: float = sign(sin(t * 80.0 * TAU)) * 0.2
		samples[i] = int((buzz + static_noise + square) * 32000.0 * 0.7 * envelope)
	return _samples_to_wav(samples)

func _gen_signal_lock() -> AudioStreamWAV:
	# Rising triple beep — "locked on signal"
	var duration: float = 0.4
	var samples := _make_samples(duration)
	for i in range(samples.size()):
		var t: float = float(i) / SAMPLE_RATE
		var beep_phase: int = int(t / 0.12)
		var freq: float = 800.0 + beep_phase * 200.0
		var in_beep: bool = fmod(t, 0.12) < 0.08
		var envelope: float = 1.0 if in_beep else 0.0
		samples[i] = int(sin(t * freq * TAU) * 32000.0 * 0.4 * envelope)
	return _samples_to_wav(samples)

func _gen_link_down() -> AudioStreamWAV:
	# Modem disconnect + alarm — the iconic "LINK DOWN"
	var duration: float = 1.0
	var samples := _make_samples(duration)
	for i in range(samples.size()):
		var t: float = float(i) / SAMPLE_RATE
		var alarm: float = sin(t * 600.0 * TAU) * sin(t * 3.0 * TAU) * 0.5
		var static_fade: float = randf_range(-1.0, 1.0) * clampf(t * 2.0, 0.0, 0.4)
		var disconnect: float = sin(t * 2400.0 * TAU) * exp(-t * 5.0) * 0.3
		samples[i] = int((alarm + static_fade + disconnect) * 32000.0 * 0.6)
	return _samples_to_wav(samples)

func _gen_modem_handshake() -> AudioStreamWAV:
	# Classic modem negotiation sound (simplified)
	var duration: float = 0.8
	var samples := _make_samples(duration)
	for i in range(samples.size()):
		var t: float = float(i) / SAMPLE_RATE
		var phase: float = t / duration
		var freq: float
		if phase < 0.2:
			freq = 1200.0 + sin(t * 30.0) * 400.0
		elif phase < 0.5:
			freq = 2400.0 + sin(t * 80.0) * 600.0
		else:
			freq = 1800.0 + randf_range(-200, 200)
		var envelope: float = 0.3
		samples[i] = int(sin(t * freq * TAU) * 32000.0 * envelope)
	return _samples_to_wav(samples)

func _gen_victory() -> AudioStreamWAV:
	# Rising fanfare — signal lock ascending
	var duration: float = 0.8
	var samples := _make_samples(duration)
	var notes: Array[float] = [523.0, 659.0, 784.0, 1047.0]  # C5, E5, G5, C6
	for i in range(samples.size()):
		var t: float = float(i) / SAMPLE_RATE
		var note_idx: int = mini(int(t / 0.2), notes.size() - 1)
		var freq: float = notes[note_idx]
		var note_t: float = fmod(t, 0.2)
		var envelope: float = 1.0 - (note_t / 0.2) * 0.3
		var tone: float = sin(t * freq * TAU) * 0.4 + sin(t * freq * 2.0 * TAU) * 0.2
		samples[i] = int(tone * 32000.0 * envelope)
	return _samples_to_wav(samples)

func _gen_monterrey_beat() -> AudioStreamWAV:
	# Simple norteño-inspired electronic beat loop (4 bars, 120 BPM)
	var bpm: float = 120.0
	var beat_duration: float = 60.0 / bpm
	var bars: int = 4
	var duration: float = beat_duration * 4 * bars  # 4 beats per bar * 4 bars
	var samples := _make_samples(duration)

	for i in range(samples.size()):
		var t: float = float(i) / SAMPLE_RATE
		var beat_pos: float = fmod(t, beat_duration)
		var bar_pos: float = fmod(t, beat_duration * 4)
		var mix: float = 0.0

		# Kick drum (beats 1 and 3)
		var beat_num: int = int(bar_pos / beat_duration)
		if beat_num == 0 or beat_num == 2:
			if beat_pos < 0.1:
				var kick_env: float = exp(-beat_pos * 30.0)
				mix += sin(beat_pos * lerpf(150.0, 50.0, beat_pos / 0.1) * TAU) * kick_env * 0.6

		# Snare/clap (beats 2 and 4) — norteño bajo sexto feel
		if beat_num == 1 or beat_num == 3:
			if beat_pos < 0.08:
				var snare_env: float = exp(-beat_pos * 25.0)
				mix += randf_range(-1.0, 1.0) * snare_env * 0.3
				mix += sin(beat_pos * 250.0 * TAU) * snare_env * 0.2

		# Hi-hat (every eighth note)
		var eighth_pos: float = fmod(t, beat_duration / 2.0)
		if eighth_pos < 0.02:
			mix += randf_range(-1.0, 1.0) * exp(-eighth_pos * 100.0) * 0.15

		# Bass line (simple pattern per bar)
		var bass_notes: Array[float] = [110.0, 110.0, 146.8, 130.8]  # A2, A2, D3, C3
		var bass_freq: float = bass_notes[beat_num]
		var bass_env: float = exp(-beat_pos * 3.0) if beat_pos < 0.3 else 0.0
		mix += sin(t * bass_freq * TAU) * bass_env * 0.25

		# Accent melody (simple synth — norteño accordion feel)
		var melody_beat: float = fmod(t, beat_duration * 8)  # 2-bar melody
		var melody_notes: Array[float] = [440.0, 523.0, 587.0, 523.0, 440.0, 392.0, 440.0, 440.0]
		var melody_idx: int = int(melody_beat / beat_duration) % melody_notes.size()
		var melody_pos: float = fmod(melody_beat, beat_duration)
		if melody_pos < beat_duration * 0.7:
			var mel_env: float = (1.0 - melody_pos / (beat_duration * 0.7)) * 0.15
			# Slight vibrato for accordion feel
			var vibrato: float = sin(t * 6.0 * TAU) * 5.0
			mix += sin(t * (melody_notes[melody_idx] + vibrato) * TAU) * mel_env

		samples[i] = int(clampf(mix, -1.0, 1.0) * 30000.0)

	var wav := _samples_to_wav(samples)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = samples.size()
	return wav

func _gen_menu_ambient() -> AudioStreamWAV:
	# Chill ambient pad with subtle data-center hum
	var duration: float = 4.0
	var samples := _make_samples(duration)
	for i in range(samples.size()):
		var t: float = float(i) / SAMPLE_RATE
		# Pad chord (Am: A3 + C4 + E4)
		var pad: float = sin(t * 220.0 * TAU) * 0.15
		pad += sin(t * 261.6 * TAU) * 0.12
		pad += sin(t * 329.6 * TAU) * 0.10
		# Slow LFO modulation
		pad *= 0.7 + sin(t * 0.5 * TAU) * 0.3
		# Subtle data hum
		var hum: float = sin(t * 60.0 * TAU) * 0.03
		samples[i] = int(clampf(pad + hum, -1.0, 1.0) * 28000.0)

	var wav := _samples_to_wav(samples)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = samples.size()
	return wav

## ═══════════ UTILITIES ═══════════

func _make_samples(duration: float) -> PackedInt32Array:
	var count: int = int(duration * SAMPLE_RATE)
	var arr := PackedInt32Array()
	arr.resize(count)
	return arr

func _samples_to_wav(samples: PackedInt32Array) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false

	# Convert int32 samples to bytes (16-bit little-endian)
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in range(samples.size()):
		var val: int = clampi(samples[i], -32768, 32767)
		bytes[i * 2] = val & 0xFF
		bytes[i * 2 + 1] = (val >> 8) & 0xFF
	wav.data = bytes
	return wav
