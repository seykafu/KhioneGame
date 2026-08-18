extends Node3D
## Island 5, Riddle 3 — The Tam-Tam Circle.
## Drums abandoned mid-circle in the glade at the mountain's east foot.
## Strike a drum and it booms; the mountain answers half a beat later.
## The chalk on the biggest drum shows the pattern with rests exactly
## where the echo lands: play the hits BETWEEN the echoes and every
## squirrel on the mountain dances, dropping what it stole (among it,
## the brass handle of the staircase lever). The pattern is the
## finale's second key, so the mountain makes sure your hands know it.

const PATTERN: Array[String] = ["low", "high", "low", "mid"]
const ECHO_DELAY := 0.45
const GAP_MIN := 0.7      # a hit before this collides with the echo
const GAP_MAX := 1.7      # a hit after this loses the thread
const DRUM_SFX := {"low": "drum_low", "mid": "drum_mid", "high": "drum_high"}

var _drums := {}
var _progress := 0
var _last_hit := -10.0
var _squirrels: Array[Node3D] = []

class DrumPlate:
	extends Interactable
	var owner_puzzle: Node
	var kind := ""

	func interact(_player: Node) -> void:
		owner_puzzle.strike(kind)

func _ready() -> void:
	var island := get_parent()
	var g: Vector3 = island.GLADE_POS
	for def: Array in [["low", Vector3(0, 0, 0), 0.62, 0.8], ["mid", Vector3(2.4, 0, 1.4), 0.46, 0.65],
			["high", Vector3(-2.2, 0, 1.6), 0.36, 0.55]]:
		var kind: String = def[0]
		var pos: Vector3 = g + (def[1] as Vector3)
		var r: float = def[2]
		var h: float = def[3]
		var drum := Node3D.new()
		drum.name = "Drum_" + kind
		drum.position = pos
		add_child(drum)
		var shell := MeshInstance3D.new()
		shell.mesh = _cyl(r, r * 0.85, h)
		shell.material_override = _mat(Color(0.5, 0.36, 0.26))
		shell.position = Vector3(0, h / 2.0, 0)
		drum.add_child(shell)
		shell.create_convex_collision()
		var skin := MeshInstance3D.new()
		skin.mesh = _cyl(r, r, 0.04)
		skin.material_override = _mat(Color(0.86, 0.8, 0.68))
		skin.position = Vector3(0, h + 0.02, 0)
		drum.add_child(skin)
		var plate := DrumPlate.new()
		plate.owner_puzzle = self
		plate.kind = kind
		plate.prompt = "Strike the %s drum" % kind
		plate.position = Vector3(0, h / 2.0, 0)
		var cs := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 1.6
		cs.shape = sph
		plate.add_child(cs)
		drum.add_child(plate)
		_drums[kind] = drum
	# The chalk on the biggest drum: dots for hits, dashes for the echoes'
	# rests. Low is the big dot, high the small, mid the middling.
	var chalk := Label3D.new()
	chalk.text = "●  –  ·  –  ●  –  •  –"
	chalk.font_size = 40
	chalk.pixel_size = 0.008
	chalk.modulate = Color(0.95, 0.95, 0.9)
	chalk.position = Vector3(0, 0.6, 0.66)
	_drums["low"].add_child(chalk)
	# The mountain answers from the slope above.
	_build_squirrels(g)

func _build_squirrels(g: Vector3) -> void:
	# A few squirrels perched about the glade, still until the rhythm.
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	for i in 6:
		var s := Node3D.new()
		s.position = g + Vector3(rng.randf_range(-5.0, 5.0), 0, rng.randf_range(-6.0, 3.0))
		add_child(s)
		var body := MeshInstance3D.new()
		var bm := CapsuleMesh.new()
		bm.radius = 0.09
		bm.height = 0.34
		body.mesh = bm
		body.material_override = _mat(Color(0.45, 0.42, 0.4))
		body.position = Vector3(0, 0.17, 0)
		s.add_child(body)
		var tail := MeshInstance3D.new()
		var tm := CapsuleMesh.new()
		tm.radius = 0.06
		tm.height = 0.36
		tail.mesh = tm
		tail.material_override = _mat(Color(0.5, 0.46, 0.44))
		tail.position = Vector3(0, 0.3, -0.16)
		tail.rotation.x = -0.6
		s.add_child(tail)
		_squirrels.append(s)

func strike(kind: String) -> void:
	var drum: Node3D = _drums[kind]
	Sfx.play(DRUM_SFX[kind], 1.0, 0.02, -6.0)
	var bounce := create_tween()
	bounce.tween_property(drum, "scale", Vector3(1.06, 0.92, 1.06), 0.06)
	bounce.tween_property(drum, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BOUNCE)
	# The mountain answers, half a beat late, from up the slope.
	get_tree().create_timer(ECHO_DELAY).timeout.connect(func() -> void:
		Sfx.play(DRUM_SFX[kind], 0.94, 0.0, -14.0))
	if GameState.get_flag("tamtam_done"):
		return
	var now := Time.get_ticks_msec() / 1000.0
	var gap := now - _last_hit
	_last_hit = now
	if _progress > 0 and (gap < GAP_MIN or gap > GAP_MAX):
		_progress = 0
		if gap < GAP_MIN:
			_flash("Too soon: the echo swallows it. Leave the mountain room to answer.", 2.5)
		else:
			_flash("The thread is lost. From the top: the big drum first.", 2.5)
	if kind == PATTERN[_progress]:
		_progress += 1
		if _progress >= PATTERN.size():
			_win()
	else:
		_progress = 1 if kind == PATTERN[0] else 0
		if _progress == 0:
			_flash("Not that drum. The chalk starts with the big one.", 2.0)

func _win() -> void:
	GameState.set_flag("tamtam_done")
	Sfx.play("squirrel_chitter", 1.0, 0.0, -8.0)
	Sfx.play("pickup_chime", 1.1, 0.0, -10.0)
	# Every squirrel dances, dropping the loot: a rain of shinies.
	for s in _squirrels:
		var d := s.create_tween().set_loops(6)
		d.tween_property(s, "position:y", s.position.y + 0.45, 0.16).set_trans(Tween.TRANS_SINE)
		d.tween_property(s, "position:y", s.position.y, 0.2).set_trans(Tween.TRANS_BOUNCE)
	var island := get_parent()
	var rain := CPUParticles3D.new()
	rain.amount = 60
	rain.lifetime = 1.6
	rain.one_shot = true
	rain.explosiveness = 0.6
	rain.direction = Vector3(0, -1, 0)
	rain.spread = 30.0
	rain.gravity = Vector3(0, -6, 0)
	rain.initial_velocity_min = 0.5
	rain.initial_velocity_max = 2.0
	var bit := BoxMesh.new()
	bit.size = Vector3(0.08, 0.08, 0.02)
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.9, 0.8, 0.4)
	bm.metallic = 0.6
	bit.material = bm
	rain.mesh = bit
	rain.position = (island.GLADE_POS as Vector3) + Vector3(0, 6.0, 0)
	rain.emitting = true
	add_child(rain)
	get_tree().create_timer(2.5).timeout.connect(rain.queue_free)
	if island.has_method("_add_pickup"):
		island._add_pickup((island.GLADE_POS as Vector3) + Vector3(0.6, 0.0, -2.2),
				"lever_handle", "Brass Lever Handle", Color(0.85, 0.7, 0.3))
	_flash("The mountain and the drums lock into one rhythm, and EVERY squirrel on the slope dances, dropping what it stole. Something brass hits the grass.", 6.0)

## Test hook: play the pattern perfectly.
func force_play() -> void:
	_progress = 0
	_last_hit = -10.0
	for kind: String in PATTERN:
		Sfx.play(DRUM_SFX[kind], 1.0, 0.0, -6.0)
	_win()

func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	return m

func _cyl(top_r: float, bottom_r: float, height: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top_r
	c.bottom_radius = bottom_r
	c.height = height
	return c

func _flash(text: String, dur: float) -> void:
	var hud := get_node_or_null("../../HUD")
	if hud:
		hud.flash_message(text, dur)
