extends Node
## Pooled sound-effect player. Every effect is a bespoke synthesized sound
## made for Khione (see tools in git history) — no stock or library audio.
## Usage: Sfx.play("pickup_chime", pitch, jitter, vol_db)

const SOUNDS := {
	"paw_sand": "res://assets/audio/paw_sand.wav",
	"paw_grass": "res://assets/audio/paw_grass.wav",
	"splash": "res://assets/audio/splash.wav",
	"swim_stroke": "res://assets/audio/swim_stroke.wav",
	"jump_whoosh": "res://assets/audio/jump_whoosh.wav",
	"land": "res://assets/audio/land.wav",
	"pickup_chime": "res://assets/audio/pickup_chime.wav",
	"paper_open": "res://assets/audio/paper_open.wav",
	"paper_close": "res://assets/audio/paper_close.wav",
	"stone_slide": "res://assets/audio/stone_slide.wav",
	"gull": "res://assets/audio/gull.wav",
	"ocean_loop": "res://assets/audio/ocean_loop.wav",
	"coconut_thunk": "res://assets/audio/coconut_thunk.wav",
	"wood_creak": "res://assets/audio/wood_creak.wav",
	"gate_open": "res://assets/audio/gate_open.wav",
	"whisker_shimmer": "res://assets/audio/whisker_shimmer.wav",
	"crab_snip": "res://assets/audio/crab_snip.wav",
	"hiss": "res://assets/audio/hiss.wav",
	"robot_whir": "res://assets/audio/robot_whir.wav",
	"robot_flee": "res://assets/audio/robot_flee.wav",
}
const POOL_SIZE := 10

var _pool: Array[AudioStreamPlayer] = []
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("Music")
	_ensure_bus("SFX")
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)

func play(sound: String, pitch := 1.0, jitter := 0.0, vol_db := 0.0) -> void:
	if not SOUNDS.has(sound):
		return
	var p := _free_player()
	p.stream = load(SOUNDS[sound])
	p.pitch_scale = pitch * (1.0 + _rng.randf_range(-jitter, jitter))
	p.volume_db = vol_db
	p.play()

## Starts a dedicated looping player (ambient beds like the ocean).
func play_ambient(sound: String, vol_db := -12.0) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "SFX"
	var s: AudioStreamWAV = load(SOUNDS[sound]).duplicate()
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = s.data.size() / 2
	p.stream = s
	p.volume_db = vol_db
	add_child(p)
	p.play()
	return p

func set_sfx_volume_db(db: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), db)

func _free_player() -> AudioStreamPlayer:
	for p in _pool:
		if not p.playing:
			return p
	return _pool[0]

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")
