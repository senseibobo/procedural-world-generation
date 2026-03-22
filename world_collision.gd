class_name WorldCollision
extends StaticBody3D


@onready var shape_node := CollisionShape3D.new()
@onready var shape := ConcavePolygonShape3D.new()

var old_pp: Vector3 = Vector3.INF


func _ready():
	top_level = true
	global_position = Vector3()
	add_child(shape_node)
	process_physics_priority = -10
	shape_node.shape = shape


func _physics_process(delta):
	var noise: FastNoiseLite = ProceduralWorld.noise
	var faces: PackedVector3Array
	var m: float = WorldMeshGenerator.CHUNK_SIZE/WorldMeshGenerator.BASE_SUBDIVISIONS 
	var pp: Vector3 = get_parent().global_position
	pp.y = 0.0
	pp.x = snapped(pp.x, m)
	pp.z = snapped(pp.z, m)
	if pp.distance_to(old_pp) > 0.02: 
		print(old_pp, " and ", pp)
		for fx in 3:
			for fz in 3:
				var p := Vector2i(fx-1, fz-1)
				var wvp := Vector2(pp.x, pp.z) + p * m
				faces.append(Vector3(wvp.x+0, noise.get_noise_2d(wvp.x+0, wvp.y+0)*WorldMeshGenerator.TERRAIN_HEIGHT, wvp.y+0))
				faces.append(Vector3(wvp.x+m, noise.get_noise_2d(wvp.x+m, wvp.y+0)*WorldMeshGenerator.TERRAIN_HEIGHT, wvp.y+0))
				faces.append(Vector3(wvp.x+0, noise.get_noise_2d(wvp.x+0, wvp.y+m)*WorldMeshGenerator.TERRAIN_HEIGHT, wvp.y+m))
				faces.append(Vector3(wvp.x+m, noise.get_noise_2d(wvp.x+m, wvp.y+0)*WorldMeshGenerator.TERRAIN_HEIGHT, wvp.y+0))
				faces.append(Vector3(wvp.x+m, noise.get_noise_2d(wvp.x+m, wvp.y+m)*WorldMeshGenerator.TERRAIN_HEIGHT, wvp.y+m))
				faces.append(Vector3(wvp.x+0, noise.get_noise_2d(wvp.x+0, wvp.y+m)*WorldMeshGenerator.TERRAIN_HEIGHT, wvp.y+m))
		shape.set_faces(faces)
		old_pp = pp
