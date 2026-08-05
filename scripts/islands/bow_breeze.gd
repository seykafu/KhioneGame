extends Node3D
## The Bow breeze: Prince's Island's readable wind. Long calms, a one-beat
## warning (the cottonwood fluff surges), then a gust that holds for a few
## seconds. Riddles read it through is_gusting()/is_calm(); the fluff burst
## is the player's tell. Joins group "bow_breeze" for lookups.

signal warning_started
signal gust_started
signal gust_ended

enum Phase { CALM, WARNING, GUST }

var phase: int = Phase.CALM
var _burst: CPUParticles3D
var _auto := true  # tests freeze the cycle and drive phases directly

func _ready() -> void:
	add_to_group("bow_breeze")
	_burst = CPUParticles3D.new()
	_burst.amount = 260
	_burst.lifetime = 3.0
	_burst.emitting = false
	_burst.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_burst.emission_box_extents = Vector3(46.0, 3.5, 46.0)
	_burst.position = Vector3(0, 3.0, 0)
	_burst.direction = Vector3(1, 0, 0.3)
	_burst.spread = 10.0
	_burst.gravity = Vector3(2.6, -0.02, 0.8)
	_burst.initial_velocity_min = 2.2
	_burst.initial_velocity_max = 3.8
	var mote := QuadMesh.new()
	mote.size = Vector2(0.09, 0.09)
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(0.99, 0.99, 0.96, 0.9)
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mote.material = mm
	_burst.mesh = mote
	add_child(_burst)
	_cycle()

func is_gusting() -> bool:
	return phase == Phase.GUST

func is_calm() -> bool:
	return phase == Phase.CALM

## Test hook: freeze the natural cycle and set a phase directly.
func force_phase(p: int) -> void:
	_auto = false
	_set_phase(p)

func _set_phase(p: int) -> void:
	phase = p
	_burst.emitting = p != Phase.CALM
	match p:
		Phase.WARNING:
			warning_started.emit()
		Phase.GUST:
			gust_started.emit()
		Phase.CALM:
			gust_ended.emit()

func _cycle() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 626
	var loop := func() -> void:
		while is_inside_tree():
			await get_tree().create_timer(rng.randf_range(9.0, 15.0)).timeout
			if not is_inside_tree() or not _auto:
				return
			_set_phase(Phase.WARNING)
			await get_tree().create_timer(1.3).timeout
			if not is_inside_tree() or not _auto:
				return
			_set_phase(Phase.GUST)
			await get_tree().create_timer(rng.randf_range(5.0, 7.5)).timeout
			if not is_inside_tree() or not _auto:
				return
			_set_phase(Phase.CALM)
	loop.call()
