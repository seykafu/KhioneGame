extends Node
## Global game state: story flags, the vocalizations Khione has learned,
## and the save file that remembers both. Every flag change autosaves (the
## file is tiny); tools and tests switch autosave off via debug_fast_start.

signal vocal_used(kind: String)
signal letter_opened
signal flag_changed(flag: String, value: bool)

## Where the journey is saved. Tests point this at a scratch file.
var save_path := "user://khione_save.cfg"
var autosave_enabled := true

var known_vocals: Array[String] = ["meow"]
var flags: Dictionary = {}
var current_island_track := "ahalo"

func knows_vocal(kind: String) -> bool:
	return kind in known_vocals

func learn_vocal(kind: String) -> void:
	if not knows_vocal(kind):
		known_vocals.append(kind)
		save_now()

func set_flag(flag: String, value: bool = true) -> void:
	flags[flag] = value
	flag_changed.emit(flag, value)
	save_now()

func get_flag(flag: String) -> bool:
	return flags.get(flag, false)

func reset() -> void:
	flags.clear()
	known_vocals = ["meow"]
	current_island_track = "ahalo"

## Called by the island manager on every travel, so the save knows where
## she sleeps tonight.
func record_island(track: String) -> void:
	current_island_track = track
	save_now()

func has_save() -> bool:
	return FileAccess.file_exists(save_path)

func save_now() -> void:
	if not autosave_enabled:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "flags", flags)
	cfg.set_value("progress", "vocals", known_vocals)
	cfg.set_value("progress", "island", current_island_track)
	cfg.set_value("progress", "inventory", Inventory.stacks)
	cfg.save(save_path)

## Restores flags, vocals, and satchel. Returns the island track to travel
## to, or "" if there was nothing to load.
func load_save() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK:
		return ""
	# Quietly: no autosave churn and no flag_changed storms while loading.
	var was_autosave := autosave_enabled
	autosave_enabled = false
	flags = cfg.get_value("progress", "flags", {})
	var vocals: Array = cfg.get_value("progress", "vocals", ["meow"])
	known_vocals.assign(vocals)
	current_island_track = cfg.get_value("progress", "island", "ahalo")
	var stacks: Array = cfg.get_value("progress", "inventory", [])
	Inventory.restore(stacks)
	_repair_consistency()
	autosave_enabled = was_autosave
	return current_island_track

## Story logic backfill for saves written before a fix (or built from
## travel grants): a finished island always means its verb was learned.
func _repair_consistency() -> void:
	if get_flag("island2_complete") and not knows_vocal("hiss"):
		known_vocals.append("hiss")
	if (get_flag("horse_moved") or get_flag("island5_complete")) and not knows_vocal("growl"):
		known_vocals.append("growl")

func clear_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
