extends Node
## Music foundation: a two-deck crossfading player on its own "Music" bus.
## Drop a track file at assets/music/<name>.ogg / .mp3 / .wav and call
## Music.play("<name>") — missing tracks no-op with a console note, so music
## hooks can ship before the music itself exists.
## Current hooks: "intro" (opening cinematic), "ahalo" (Island 1 exploration).

const TRACK_DIR := "res://assets/music/"
const EXTENSIONS := ["ogg", "mp3", "wav"]

var _deck_a: AudioStreamPlayer
var _deck_b: AudioStreamPlayer
var _active: AudioStreamPlayer
var _current_track := ""
var _warned := {}
var _deck_tweens := {}  # deck -> Tween; killed before reuse so a stale
                        # fade-out stop() can never silence a reused deck

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_deck_a = _make_deck()
	_deck_b = _make_deck()
	_active = _deck_a

func play(track: String, fade := 2.0) -> void:
	if track == _current_track:
		return
	var stream := _resolve(track)
	if stream == null:
		if not _warned.has(track):
			_warned[track] = true
			print("[Music] No file for track '%s' — add %s%s.ogg/.mp3/.wav and it will play here." % [track, TRACK_DIR, track])
		return
	_current_track = track
	var incoming := _deck_b if _active == _deck_a else _deck_a
	var outgoing := _active
	_active = incoming
	incoming.stream = stream
	incoming.volume_db = -60.0
	incoming.play()
	_fade_deck(incoming, 0.0, fade, false)
	if outgoing.playing:
		_fade_deck(outgoing, -60.0, fade, true)

func stop(fade := 2.0) -> void:
	_current_track = ""
	if _active and _active.playing:
		_fade_deck(_active, -60.0, fade, true)

func _fade_deck(deck: AudioStreamPlayer, to_db: float, fade: float, stop_after: bool) -> void:
	if _deck_tweens.has(deck) and (_deck_tweens[deck] as Tween).is_valid():
		(_deck_tweens[deck] as Tween).kill()
	var t := create_tween()
	t.tween_property(deck, "volume_db", to_db, fade)
	if stop_after:
		t.tween_callback(deck.stop)
	_deck_tweens[deck] = t

func set_music_volume_db(db: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), db)

func _make_deck() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Music"
	add_child(p)
	return p

func _resolve(track: String) -> AudioStream:
	for ext: String in EXTENSIONS:
		var path := TRACK_DIR + track + "." + ext
		if ResourceLoader.exists(path):
			var s: AudioStream = load(path).duplicate()
			s.set("loop", true)
			if s is AudioStreamWAV:
				s.loop_mode = AudioStreamWAV.LOOP_FORWARD
				s.loop_begin = 0
				s.loop_end = s.data.size() / 2
			return s
	return null
