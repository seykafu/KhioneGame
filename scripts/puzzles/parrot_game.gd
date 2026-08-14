extends Node3D
## Island 5 — the parrot: growl teacher, then The Parrot's Game.
## It perches on the crow's nest mocking every sound Khione makes.
## Oreo barks; it flinches; Khione tries to bark and finds her growl.
## Once it respects her, it plays Simon with vocals: watch the sequence,
## answer with the real keys (M/G/H). Five rounds win the captain's
## whistle: from then on, a meow summons Oreo across the whole island.

const ROUNDS := 5
const VOCAL_COLORS := {
	"meow": Color(0.95, 0.9, 0.7),
	"growl": Color(0.8, 0.4, 0.3),
	"hiss": Color(0.55, 0.8, 0.7),
}

var _parrot: Node3D
var _beak_light: MeshInstance3D
var _mock_count := 0
var _sequence: Array[String] = []
var _answer_idx := 0
var _round := 0
var _listening := false   # player's turn
var _showing := false     # parrot's turn
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 727
	_build_parrot()
	GameState.vocal_used.connect(_on_vocal)
	var player: Node = get_tree().get_first_node_in_group("player")
	if player and player.has_signal("vocal_unknown"):
		player.vocal_unknown.connect(_on_vocal_unknown)

func _build_parrot() -> void:
	var island := get_parent()
	_parrot = Node3D.new()
	_parrot.name = "Parrot"
	island.crow_nest.add_child(_parrot)
	_parrot.position = Vector3(0, 0.62, 0)
	var body := MeshInstance3D.new()
	var bm := CapsuleMesh.new()
	bm.radius = 0.14
	bm.height = 0.5
	body.mesh = bm
	body.material_override = _flat(Color(0.85, 0.25, 0.2))
	body.rotation.x = 0.5
	_parrot.add_child(body)
	var wing := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(0.06, 0.22, 0.3)
	wing.mesh = wm
	wing.material_override = _flat(Color(0.2, 0.5, 0.75))
	wing.position = Vector3(0.13, 0.05, 0)
	_parrot.add_child(wing)
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.11
	head.mesh = hm
	head.material_override = _flat(Color(0.9, 0.8, 0.3))
	head.position = Vector3(0, 0.3, 0.12)
	_parrot.add_child(head)
	_beak_light = MeshInstance3D.new()
	var km := CylinderMesh.new()
	km.top_radius = 0.0
	km.bottom_radius = 0.05
	km.height = 0.16
	_beak_light.mesh = km
	_beak_light.material_override = _flat(Color(0.3, 0.3, 0.3))
	_beak_light.rotation.x = PI / 2.0
	_beak_light.position = Vector3(0, 0.3, 0.26)
	_parrot.add_child(_beak_light)

func _player_near() -> bool:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player == null:
		return false
	return player.global_position.distance_to(_parrot.global_position) < 26.0

func _squawk(pitch: float, flash_col := Color.TRANSPARENT) -> void:
	Sfx.play("parrot_squawk", pitch, 0.02, -8.0)
	var hop := create_tween()
	hop.tween_property(_parrot, "position:y", 0.82, 0.12).set_trans(Tween.TRANS_SINE)
	hop.tween_property(_parrot, "position:y", 0.62, 0.16).set_trans(Tween.TRANS_BOUNCE)
	if flash_col != Color.TRANSPARENT:
		var m := StandardMaterial3D.new()
		m.albedo_color = flash_col
		m.emission_enabled = true
		m.emission = flash_col
		m.emission_energy_multiplier = 1.8
		_beak_light.material_override = m
		get_tree().create_timer(0.35).timeout.connect(func() -> void:
			_beak_light.material_override = _flat(Color(0.3, 0.3, 0.3)))

func _on_vocal_unknown(kind: String) -> void:
	# Her first attempt at a bark comes out as her first growl.
	if kind != "growl" or not _player_near():
		return
	if GameState.get_flag("parrot_respect") or _mock_count < 2:
		return
	GameState.learn_vocal("growl")
	GameState.set_flag("parrot_respect")
	Sfx.play("growl", 1.0, 0.0, -4.0)
	_squawk(0.7)
	_flash("What comes out is not a bark. It is a GROWL, low and true — and the parrot goes very, very respectful.", 5.5)
	get_tree().create_timer(2.5).timeout.connect(func() -> void:
		_flash("The parrot bobs twice. It wants to play. Watch its beak-light, answer in kind.", 4.5))
	get_tree().create_timer(5.5).timeout.connect(_start_round.bind(1))

func _on_vocal(kind: String) -> void:
	if not _player_near():
		return
	if _listening:
		_check_answer(kind)
		return
	if _showing:
		return
	if GameState.get_flag("parrot_game_done"):
		_squawk(1.1)
		return
	if not GameState.get_flag("parrot_respect"):
		# The mockingbird phase: it answers everything, pitch-perfect, rude.
		_mock_count += 1
		var pitch := 1.3 if kind == "meow" else 0.9
		get_tree().create_timer(0.5).timeout.connect(func() -> void: _squawk(pitch))
		if _mock_count == 2:
			get_tree().create_timer(1.2).timeout.connect(func() -> void:
				_oreo_demonstrates())
		return
	# Respected but no game running: a vocal near the nest starts one.
	_start_round(1)

func _oreo_demonstrates() -> void:
	var oreo: Node = get_tree().get_first_node_in_group("oreo")
	if oreo == null:
		_flash("The parrot mocks her perfectly. Something with a bigger voice might impress it…", 4.5)
		return
	Sfx.play("bark", 1.0, 0.05, -6.0)
	_squawk(0.75)
	_flash("Oreo BARKS. The parrot flinches — respect at last! Khione squares up… try to bark. [G]", 5.0)

func _start_round(round_n: int) -> void:
	if GameState.get_flag("parrot_game_done"):
		return
	_round = round_n
	_sequence.clear()
	var known: Array[String] = []
	for v: String in ["meow", "growl", "hiss"]:
		if GameState.knows_vocal(v):
			known.append(v)
	for i in (2 + _round):
		_sequence.append(known[_rng.randi_range(0, known.size() - 1)])
	_showing = true
	_listening = false
	_flash("Round %d of %d. The parrot sings…" % [_round, ROUNDS], 2.0)
	var delay := 0.8
	var gap := maxf(0.75 - 0.08 * _round, 0.4)
	for i in _sequence.size():
		var kind := _sequence[i]
		get_tree().create_timer(delay + gap * i).timeout.connect(func() -> void:
			_squawk(_pitch_for(kind), VOCAL_COLORS[kind]))
	get_tree().create_timer(delay + gap * _sequence.size() + 0.4).timeout.connect(func() -> void:
		_showing = false
		_listening = true
		_answer_idx = 0
		_flash("Your turn. Answer in kind.", 2.0))

func _pitch_for(kind: String) -> float:
	return {"meow": 1.35, "growl": 0.7, "hiss": 1.0}[kind]

func _check_answer(kind: String) -> void:
	if kind == _sequence[_answer_idx]:
		_answer_idx += 1
		if _answer_idx >= _sequence.size():
			_listening = false
			if _round >= ROUNDS:
				_win()
			else:
				Sfx.play("pickup_chime", 1.2, 0.0, -12.0)
				get_tree().create_timer(0.8).timeout.connect(_start_round.bind(_round + 1))
		return
	_listening = false
	_squawk(1.5)
	_flash("The parrot falls over laughing. From the top!", 3.0)
	get_tree().create_timer(1.5).timeout.connect(_start_round.bind(1))

func _win() -> void:
	GameState.set_flag("parrot_game_done")
	Sfx.play("whistle_trill", 1.0, 0.0, -6.0)
	var island := get_parent()
	if island.has_method("_add_pickup"):
		island._add_pickup(Vector3(7.5, 0.5, 19.5), "captains_whistle",
				"Captain's Whistle", Color(0.85, 0.72, 0.3))
	_flash("Five rounds! The parrot drops its treasure at the lanyard post: the captain's whistle. A meow will fetch Oreo from ANYWHERE now.", 6.0)

## Test hooks.
func force_respect() -> void:
	_mock_count = 2
	GameState.learn_vocal("growl")
	GameState.set_flag("parrot_respect")

func force_win() -> void:
	_round = ROUNDS
	_win()

func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	return m

func _flash(text: String, dur: float) -> void:
	var hud := get_node_or_null("../../HUD")
	if hud:
		hud.flash_message(text, dur)
