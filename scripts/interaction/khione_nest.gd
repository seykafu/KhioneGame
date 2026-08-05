extends Interactable
## Khione's nest on the second terrace: pressed grass, a faded ribbon, a
## bottle cap, a white feather. Small proof of a small life. Seeing it
## sets nest_seen for the story to lean on later.

func _init() -> void:
	prompt = "Curl up for a moment"

func _ready() -> void:
	super()
	var zone := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.8
	zone.shape = sph
	add_child(zone)
	var straw := StandardMaterial3D.new()
	straw.albedo_color = Color(0.78, 0.68, 0.42)
	straw.roughness = 1.0
	var nest := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.42
	ring.outer_radius = 0.62
	nest.mesh = ring
	nest.material_override = straw
	nest.scale = Vector3(1, 0.55, 1)
	nest.position.y = 0.08
	add_child(nest)
	var bed := MeshInstance3D.new()
	var bmesh := CylinderMesh.new()
	bmesh.top_radius = 0.44
	bmesh.bottom_radius = 0.44
	bmesh.height = 0.08
	bed.mesh = bmesh
	var bed_mat := StandardMaterial3D.new()
	bed_mat.albedo_color = Color(0.6, 0.66, 0.34)
	bed.material_override = bed_mat
	bed.position.y = 0.07
	add_child(bed)
	var ribbon := MeshInstance3D.new()
	var rmesh := BoxMesh.new()
	rmesh.size = Vector3(0.5, 0.015, 0.05)
	ribbon.mesh = rmesh
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.75, 0.25, 0.3)
	ribbon.material_override = rmat
	ribbon.position = Vector3(0.1, 0.13, 0.1)
	ribbon.rotation.y = 0.7
	add_child(ribbon)
	var cap := MeshInstance3D.new()
	var cmesh := CylinderMesh.new()
	cmesh.top_radius = 0.06
	cmesh.bottom_radius = 0.06
	cmesh.height = 0.02
	cap.mesh = cmesh
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(0.75, 0.75, 0.78)
	cmat.metallic = 0.8
	cmat.roughness = 0.3
	cap.material_override = cmat
	cap.position = Vector3(-0.16, 0.12, 0.05)
	add_child(cap)
	var feather := MeshInstance3D.new()
	var fmesh := BoxMesh.new()
	fmesh.size = Vector3(0.22, 0.01, 0.06)
	feather.mesh = fmesh
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.96, 0.96, 0.94)
	feather.material_override = fmat
	feather.position = Vector3(0.05, 0.12, -0.18)
	feather.rotation.y = -0.5
	add_child(feather)

func interact(_player: Node) -> void:
	var hud := get_node_or_null("../../HUD")
	if not GameState.get_flag("nest_seen"):
		GameState.set_flag("nest_seen")
		if hud:
			hud.flash_message("Pressed grass, a ribbon, a bottle cap. Your harbour, before the letter came.", 4.5)
	elif hud:
		hud.flash_message("The nest still holds your shape. It will keep holding it.", 3.5)
