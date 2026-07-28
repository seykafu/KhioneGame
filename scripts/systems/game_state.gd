extends Node
## Global game state: story flags and the vocalizations Khione has learned.
## Puzzle objects listen to `vocal_used` to react to meows, hisses, and growls.

signal vocal_used(kind: String)
signal letter_opened
signal flag_changed(flag: String, value: bool)

var known_vocals: Array[String] = ["meow"]
var flags: Dictionary = {}

func knows_vocal(kind: String) -> bool:
	return kind in known_vocals

func learn_vocal(kind: String) -> void:
	if not knows_vocal(kind):
		known_vocals.append(kind)

func set_flag(flag: String, value: bool = true) -> void:
	flags[flag] = value
	flag_changed.emit(flag, value)

func get_flag(flag: String) -> bool:
	return flags.get(flag, false)
