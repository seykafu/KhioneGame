extends Interactable
## A Toronto streetlamp, half buried in the dune by the boat channel. It
## should not be here. Its glass still flickers, and sniffing it stirs
## the first crack in the story (memory_glitch_1).

var _glass_mat: StandardMaterial3D

func _init() -> void:
	prompt = "Sniff the strange lamp"

func _ready() -> void:
	super()
	var zone := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 2.2
	zone.shape = sph
	add_child(zone)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.16, 0.24, 0.2)
	iron.roughness = 0.6
	iron.metallic = 0.4
	var pole := MeshInstance3D.new()
	var pmesh := CylinderMesh.new()
	pmesh.top_radius = 0.07
	pmesh.bottom_radius = 0.1
	pmesh.height = 3.4
	pole.mesh = pmesh
	pole.material_override = iron
	pole.position = Vector3(0, 1.1, 0)  # the rest sleeps under the sand
	add_child(pole)
	var arm := MeshInstance3D.new()
	var amesh := CylinderMesh.new()
	amesh.top_radius = 0.05
	amesh.bottom_radius = 0.05
	amesh.height = 0.7
	arm.mesh = amesh
	arm.material_override = iron
	arm.position = Vector3(0.3, 2.75, 0)
	arm.rotation.z = PI / 2.0 - 0.3
	add_child(arm)
	_glass_mat = StandardMaterial3D.new()
	_glass_mat.albedo_color = Color(0.95, 0.9, 0.7)
	_glass_mat.emission_enabled = true
	_glass_mat.emission = Color(1.0, 0.9, 0.6)
	_glass_mat.emission_energy_multiplier = 0.0
	var head := MeshInstance3D.new()
	var hmesh := BoxMesh.new()
	hmesh.size = Vector3(0.34, 0.3, 0.34)
	head.mesh = hmesh
	head.material_override = _glass_mat
	head.position = Vector3(0.62, 2.85, 0)
	add_child(head)
	rotation.z = 0.85  # half toppled into the dune
	rotation.y = -0.7
	position.y -= 0.55
	var mound := MeshInstance3D.new()
	var mmesh := SphereMesh.new()
	mmesh.radius = 1.1
	mmesh.height = 0.9
	mound.mesh = mmesh
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.9, 0.82, 0.6)
	smat.roughness = 1.0
	mound.mesh = mmesh
	mound.material_override = smat
	# Counter the lamp's tilt so the drift lies flat on the beach.
	mound.rotation.z = -0.85
	mound.position = Vector3(0.25, 0.15, 0)
	add_child(mound)
	_flicker()

func _flicker() -> void:
	# An irregular electrical stutter, like the lamp is trying to remember.
	var rng := RandomNumberGenerator.new()
	rng.seed = 4040
	var loop := func() -> void:
		while is_inside_tree():
			await get_tree().create_timer(rng.randf_range(1.4, 4.2)).timeout
			if not is_inside_tree():
				return
			for i in rng.randi_range(2, 5):
				_glass_mat.emission_energy_multiplier = rng.randf_range(0.9, 1.8)
				await get_tree().create_timer(rng.randf_range(0.04, 0.12)).timeout
				_glass_mat.emission_energy_multiplier = 0.0
				await get_tree().create_timer(rng.randf_range(0.05, 0.18)).timeout
	loop.call()

func interact(_player: Node) -> void:
	var hud := get_node_or_null("../../HUD")
	if not GameState.get_flag("memory_glitch_1"):
		GameState.set_flag("memory_glitch_1")
		if hud:
			hud.flash_message("It smells like rain on warm pavement. Like a street you have walked before.", 4.5)
			await get_tree().create_timer(4.8).timeout
			hud.flash_message("But you have always lived on this island. Haven't you?", 4.0)
	elif hud:
		hud.flash_message("The lamp stutters its small light, remembering a city.", 3.5)
