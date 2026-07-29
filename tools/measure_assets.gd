extends SceneTree
## Dev tool: print the real-world AABB of each vendored GLB so scene scales
## can be set precisely. Run: godot --headless --path . --script tools/measure_assets.gd

const PATHS := [
	"res://assets/characters/khione_cat.glb",
	"res://assets/nature/tree_palm.glb",
	"res://assets/nature/tree_palmTall.glb",
	"res://assets/nature/tree_palmDetailedShort.glb",
	"res://assets/nature/rock_largeA.glb",
	"res://assets/nature/rock_tallA.glb",
	"res://assets/nature/rock_smallA.glb",
	"res://assets/nature/grass_large.glb",
	"res://assets/nature/flower_redA.glb",
]

func _init() -> void:
	for p in PATHS:
		var scene: Node = load(p).instantiate()
		var aabb := _merged_aabb(scene, Transform3D.IDENTITY)
		print("%s  size=%s" % [p.get_file(), aabb.size])
		scene.free()
	quit()

func _merged_aabb(n: Node, xf: Transform3D) -> AABB:
	var local := xf
	if n is Node3D:
		local = xf * (n as Node3D).transform
	var result := AABB()
	var has := false
	if n is MeshInstance3D:
		result = local * (n as MeshInstance3D).get_aabb()
		has = true
	for c in n.get_children():
		var child := _merged_aabb(c, local)
		if child.size != Vector3.ZERO:
			result = result.merge(child) if has else child
			has = true
	return result
