extends Node
## Persistent user settings: audio bus volumes, mouse sensitivity, fullscreen.
## Saved to user://settings.cfg, loaded and applied at boot.

const PATH := "user://settings.cfg"

var master_vol := 1.0
var music_vol := 0.85
var sfx_vol := 1.0
var mouse_sensitivity := 1.0
var fullscreen := false

func _ready() -> void:
	load_settings()
	apply()

func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	master_vol = cf.get_value("audio", "master", 1.0)
	music_vol = cf.get_value("audio", "music", 0.85)
	sfx_vol = cf.get_value("audio", "sfx", 1.0)
	mouse_sensitivity = cf.get_value("controls", "sensitivity", 1.0)
	fullscreen = cf.get_value("display", "fullscreen", false)

func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("audio", "master", master_vol)
	cf.set_value("audio", "music", music_vol)
	cf.set_value("audio", "sfx", sfx_vol)
	cf.set_value("controls", "sensitivity", mouse_sensitivity)
	cf.set_value("display", "fullscreen", fullscreen)
	cf.save(PATH)

func apply() -> void:
	_set_bus("Master", master_vol)
	_set_bus("Music", music_vol)
	_set_bus("SFX", sfx_vol)
	if DisplayServer.get_name() != "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)

func _set_bus(bus: String, vol: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx == -1:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(vol, 0.0001, 1.0)))
	AudioServer.set_bus_mute(idx, vol <= 0.001)
