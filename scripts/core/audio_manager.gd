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
	_sfx_cache["hit_critical"] = _gen_hit(0.35, 80.0, 1.0)
	_sfx_cache["ko"] = _gen_ko()
	_sfx_cache["jump"] = _gen_sweep(0.12, 300.0, 600.0, 0.3)
	_sfx_cache["double_jump"] = _gen_sweep(0.1, 500.0, 900.0, 0.25)
	_sfx_cache["land"] = _gen_noise_burst(0.08, 0.3)
	_sfx_cache["dodge"] = _gen_sweep(0.08, 600.0, 200.0, 0.2)
	_sfx_cache["menu_move"] = _gen_beep(0.05, 800.0, 0.2)
	_sfx_cache["menu_select"] = _gen_beep(0.1, 1200.0, 0.3)
	_sfx_cache["menu_back"] = _gen_sweep(0.08, 600.0, 300.0, 0.2)
	_sfx_cache["signal_lock"] = _gen_signal_lock()
	_sfx_cache["link_down"] = _gen_link_down()
	_sfx_cache["modem"] = _gen_modem_handshake()
	_sfx_cache["align_beep"] = _gen_beep(0.06, 1000.0, 0.2)
	_sfx_cache["score"] = _gen_sweep(0.15, 400.0, 800.0, 0.3)
	_sfx_cache["victory"] = _gen_victory()
	_sfx_cache["equip"] = _gen_equip()
	_sfx_cache["countdown"] = _gen_beep(0.08, 660.0, 0.35)
	_sfx_cache["fight_start"] = _gen_fight_start()
	_sfx_cache["round_end"] = _gen_round_end()

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

func play_music_select() -> void:
	if _is_music_playing:
		stop_music()
	_music_player.stream = _gen_select_theme()
	_music_player.play()
	_is_music_playing = true

func play_music_loadout() -> void:
	if _is_music_playing:
		stop_music()
	_music_player.stream = _gen_loadout_theme()
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

func _gen_select_theme() -> AudioStreamWAV:
	# Dr. Mario-style character select theme — upbeat chiptune with WISP flair
	# Key of C major, 140 BPM, 8 bars loop
	var bpm: float = 140.0
	var beat_dur: float = 60.0 / bpm
	var bars: int = 8
	var duration: float = beat_dur * 4 * bars
	var samples := _make_samples(duration)

	# Melody pattern (16th note resolution, 2 bars repeated 4x)
	# Inspired by Dr. Mario's bouncy optimistic feel
	var melody: Array[float] = [
		523.3, 0, 659.3, 0, 784.0, 0, 659.3, 0,  # C5 . E5 . G5 . E5 .
		698.5, 0, 784.0, 0, 880.0, 784.0, 659.3, 0,  # F5 . G5 . A5 G5 E5 .
		523.3, 0, 587.3, 0, 659.3, 0, 523.3, 0,  # C5 . D5 . E5 . C5 .
		440.0, 0, 523.3, 0, 587.3, 523.3, 440.0, 0,  # A4 . C5 . D5 C5 A4 .
	]

	# Bass pattern (quarter notes, 2 bars)
	var bass: Array[float] = [
		130.8, 130.8, 174.6, 174.6,  # C3 C3 F3 F3
		146.8, 146.8, 164.8, 130.8,  # D3 D3 E3 C3
	]

	# Arpeggio pattern (fast 8th notes, adds chiptune sparkle)
	var arp: Array[float] = [
		1047.0, 1318.5, 1568.0, 1318.5, 1047.0, 1318.5, 1568.0, 1760.0,
	]

	var sixteenth: float = beat_dur / 4.0

	for i in range(samples.size()):
		var t: float = float(i) / SAMPLE_RATE
		var mix: float = 0.0

		# ── Drums ──
		var beat_pos: float = fmod(t, beat_dur)
		var bar_beat: int = int(fmod(t, beat_dur * 4) / beat_dur)

		# Kick (beats 1, 3)
		if bar_beat == 0 or bar_beat == 2:
			if beat_pos < 0.06:
				mix += sin(beat_pos * lerpf(200.0, 60.0, beat_pos / 0.06) * TAU) * exp(-beat_pos * 40.0) * 0.5

		# Snare (beats 2, 4)
		if bar_beat == 1 or bar_beat == 3:
			if beat_pos < 0.05:
				mix += randf_range(-1.0, 1.0) * exp(-beat_pos * 40.0) * 0.25
				mix += sin(beat_pos * 300.0 * TAU) * exp(-beat_pos * 30.0) * 0.15

		# Hi-hat (every 8th)
		var eighth_pos: float = fmod(t, beat_dur / 2.0)
		if eighth_pos < 0.015:
			mix += randf_range(-1.0, 1.0) * exp(-eighth_pos * 150.0) * 0.1

		# ── Bass (square wave for NES feel) ──
		var bass_idx: int = int(fmod(t, beat_dur * 4 * 2) / beat_dur) % bass.size()
		var bass_freq: float = bass[bass_idx]
		if bass_freq > 0:
			var bass_env: float = 0.8 if beat_pos < beat_dur * 0.8 else 0.0
			# Square wave (sign of sine = square)
			mix += sign(sin(t * bass_freq * TAU)) * 0.12 * bass_env

		# ── Melody (pulse wave — Dr. Mario character) ──
		var melody_pos: float = fmod(t, sixteenth * melody.size())
		var mel_idx: int = int(melody_pos / sixteenth) % melody.size()
		var mel_freq: float = melody[mel_idx]
		if mel_freq > 0:
			var mel_note_pos: float = fmod(melody_pos, sixteenth)
			var mel_env: float = 1.0 if mel_note_pos < sixteenth * 0.7 else 0.0
			# Pulse wave (25% duty cycle for that classic NES sound)
			var pulse: float = 1.0 if fmod(t * mel_freq, 1.0) < 0.25 else -1.0
			mix += pulse * 0.12 * mel_env

		# ── Arpeggio sparkle (triangle wave) ──
		var arp_pos: float = fmod(t, beat_dur)
		var arp_idx: int = int(arp_pos / (beat_dur / 8.0)) % arp.size()
		var arp_freq: float = arp[arp_idx]
		# Triangle wave
		var tri: float = (2.0 * absf(2.0 * fmod(t * arp_freq, 1.0) - 1.0) - 1.0)
		mix += tri * 0.05

		# ── Occasional "data blip" SFX (WISP flair every 2 bars) ──
		var two_bar: float = fmod(t, beat_dur * 8)
		if two_bar > beat_dur * 7.5 and two_bar < beat_dur * 7.8:
			var blip_t: float = two_bar - beat_dur * 7.5
			mix += sin(blip_t * lerpf(2000.0, 800.0, blip_t / 0.3) * TAU) * 0.08

		samples[i] = int(clampf(mix, -1.0, 1.0) * 28000.0)

	var wav := _samples_to_wav(samples)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = samples.size()
	return wav

func _gen_equip() -> AudioStreamWAV:
	# Mechanical click + data transfer chirp — equipping gear
	var duration: float = 0.2
	var samples := _make_samples(duration)
	for i in range(samples.size()):
		var t: float = float(i) / SAMPLE_RATE
		var click: float = randf_range(-1.0, 1.0) * exp(-t * 80.0) * 0.4
		var chirp: float = sin(t * lerpf(800.0, 1600.0, t / duration) * TAU) * exp(-t * 15.0) * 0.3
		samples[i] = int((click + chirp) * 32000.0)
	return _samples_to_wav(samples)

func _gen_fight_start() -> AudioStreamWAV:
	# Rising power-up sweep + impact — "FIGHT!"
	var duration: float = 0.5
	var samples := _make_samples(duration)
	for i in range(samples.size()):
		var t: float = float(i) / SAMPLE_RATE
		var sweep: float = sin(t * lerpf(200.0, 1200.0, t / duration) * TAU) * 0.4
		var impact: float = 0.0
		if t > 0.35:
			var it: float = t - 0.35
			impact = sin(it * 100.0 * TAU) * exp(-it * 20.0) * 0.5
			impact += randf_range(-1.0, 1.0) * exp(-it * 15.0) * 0.3
		var envelope: float = minf(t * 10.0, 1.0)
		samples[i] = int((sweep * envelope + impact) * 30000.0)
	return _samples_to_wav(samples)

func _gen_round_end() -> AudioStreamWAV:
	# Descending whistle + crowd — round over
	var duration: float = 0.6
	var samples := _make_samples(duration)
	for i in range(samples.size()):
		var t: float = float(i) / SAMPLE_RATE
		var whistle: float = sin(t * lerpf(1000.0, 400.0, t / duration) * TAU) * 0.3
		var crowd: float = randf_range(-1.0, 1.0) * 0.15 * (1.0 - t / duration)
		var envelope: float = 1.0 - (t / duration) * 0.5
		samples[i] = int((whistle + crowd) * 32000.0 * envelope)
	return _samples_to_wav(samples)

func _gen_loadout_theme() -> AudioStreamWAV:
	# Techy ambient — data center vibe with subtle groove. Perfect for equipment browsing.
	var bpm: float = 100.0
	var beat_dur: float = 60.0 / bpm
	var duration: float = beat_dur * 4 * 4  # 4 bars
	var samples := _make_samples(duration)

	for i in range(samples.size()):
		var t: float = float(i) / SAMPLE_RATE
		var beat_pos: float = fmod(t, beat_dur)
		var bar_beat: int = int(fmod(t, beat_dur * 4) / beat_dur)
		var mix: float = 0.0

		# Soft kick (1 and 3)
		if bar_beat == 0 or bar_beat == 2:
			if beat_pos < 0.08:
				mix += sin(beat_pos * lerpf(100.0, 40.0, beat_pos / 0.08) * TAU) * exp(-beat_pos * 25.0) * 0.3

		# Rim click (2 and 4)
		if bar_beat == 1 or bar_beat == 3:
			if beat_pos < 0.02:
				mix += sin(beat_pos * 1800.0 * TAU) * exp(-beat_pos * 100.0) * 0.15

		# 16th note hi-hat pattern (soft, techy)
		var sixteenth: float = fmod(t, beat_dur / 4.0)
		if sixteenth < 0.01:
			mix += randf_range(-1.0, 1.0) * exp(-sixteenth * 200.0) * 0.06

		# Deep bass pad (Am — dark, sustained)
		mix += sin(t * 55.0 * TAU) * 0.12  # A1
		mix += sin(t * 65.4 * TAU) * 0.06  # C2

		# Ambient pad (Am7 — ethereal)
		var pad_env: float = 0.5 + sin(t * 0.3 * TAU) * 0.3
		mix += sin(t * 220.0 * TAU) * 0.04 * pad_env
		mix += sin(t * 261.6 * TAU) * 0.03 * pad_env
		mix += sin(t * 329.6 * TAU) * 0.03 * pad_env
		mix += sin(t * 392.0 * TAU) * 0.02 * pad_env  # G4 for Am7

		# Data chirps (random techy sounds every 2 beats)
		var two_beat: float = fmod(t, beat_dur * 2)
		if two_beat > beat_dur * 1.75 and two_beat < beat_dur * 1.85:
			var chirp_t: float = two_beat - beat_dur * 1.75
			mix += sin(chirp_t * lerpf(1500.0, 3000.0, chirp_t / 0.1) * TAU) * 0.04 * exp(-chirp_t * 30.0)

		# Subtle arpeggio (triangle wave, every other bar)
		var two_bar: float = fmod(t, beat_dur * 8)
		if two_bar > beat_dur * 4:
			var arp_notes: Array[float] = [220.0, 261.6, 329.6, 392.0, 329.6, 261.6]
			var arp_idx: int = int(fmod(two_bar, beat_dur * 2) / (beat_dur / 3.0)) % arp_notes.size()
			var arp_freq: float = arp_notes[arp_idx]
			var tri: float = (2.0 * absf(2.0 * fmod(t * arp_freq, 1.0) - 1.0) - 1.0)
			mix += tri * 0.03

		samples[i] = int(clampf(mix, -1.0, 1.0) * 28000.0)

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
