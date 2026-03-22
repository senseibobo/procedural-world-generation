class_name WorldMeshGenerator
extends Node3D


enum StitchFace {
	X_NEG = 1,
	Z_NEG = 2,
	X_POS = 4,
	Z_POS = 8,
}

var triangles: int = 0


const LOD_LEVELS: int = 5
const CHUNK_SIZE: float = 42.00
const TERRAIN_HEIGHT: float = 30.0
const BASE_SUBDIVISIONS: int = 48

var mutex := Mutex.new()
var update_mesh_instances_thread := Thread.new()



@export var noise: FastNoiseLite
@export var terrain_material: ShaderMaterial

var old_cq: Vector2i = Vector2i.MIN
var mesh_instances_initiated: bool = false

var mesh_instances: Dictionary[Vector2i, MeshInstance3D]
var mesh_instances_updating: bool = false
var mesh_instances_updated: bool = false
var updated_meshes: Dictionary[Vector2i, ArrayMesh]


func _ready():
	await get_tree().process_frame
	await get_tree().process_frame
	_init_mesh_instances()
	

func _process(delta: float) -> void:
	if mesh_instances_initiated:
		var camera = get_viewport().get_camera_3d()
		var cq := Vector2i(floor(camera.global_position.x/CHUNK_SIZE), floor(camera.global_position.z/CHUNK_SIZE))
		if cq != old_cq and not mesh_instances_updating:
			updated_meshes.clear()
			update_mesh_instances_thread.start(update_mesh_instances.bind(cq))
			old_cq = cq
		if mesh_instances_updating and mesh_instances_updated:
			print("bruruuh")
			update_mesh_instances_thread.wait_to_finish()
			mesh_instances_updating = false
			mesh_instances_updated = false
			for q in updated_meshes:
				mesh_instances[q].mesh = updated_meshes[q]
			updated_meshes.clear()

func _init_mesh_instances():
	for lod_level in LOD_LEVELS:
		var p: int = -(pow(3, lod_level) - 1) / 2
		var c: int = pow(3,lod_level)
		for x in 3:
			for z in 3:
				if x == 1 and z == 1 and lod_level != 0: continue
				var q := Vector2i((x-1)*c+p, (z-1)*c+p)
				#var c: float = pow(3,lod_level)
				mesh_instances[q] = MeshInstance3D.new()
				add_child(mesh_instances[q])
				mesh_instances[q].global_position = Vector3()
				#mesh_instances[q].global_position = Vector3(q.x, 0.0, q.y) * CHUNK_SIZE * c
				var mat := StandardMaterial3D.new()
				#mat.albedo_color = Color(lod_level/float(LOD_LEVELS), 0, 0)
				mesh_instances[q].material_overlay = terrain_material
	mesh_instances_initiated = true


func update_mesh_instances(cq: Vector2i):
	print("updatin")
	mutex.lock()
	mesh_instances_updating = true
	triangles = 0
	for lod_level in LOD_LEVELS:
		var p: int = -(pow(3, lod_level) - 1) / 2
		var c: int = pow(3,lod_level)
		for x in 3:
			for z in 3:
				if x == 1 and z == 1 and lod_level != 0: continue
				var q := Vector2i((x-1)*c+p, (z-1)*c+p)
				#print((x-1)*c-pow(lod_level,2))
				var stitch_at: int = 0
				if x == 0: stitch_at = stitch_at | StitchFace.X_NEG 
				if x == 2: stitch_at = stitch_at | StitchFace.X_POS
				if z == 0: stitch_at = stitch_at | StitchFace.Z_NEG
				if z == 2: stitch_at = stitch_at | StitchFace.Z_POS
				
				var world_pos: Vector3 = Vector3(q.x+cq.x, 0.0, q.y+cq.y) * CHUNK_SIZE
				updated_meshes[q] = create_mesh(Vector2(world_pos.x, world_pos.z), lod_level, stitch_at)
	mesh_instances_updated = true
	mutex.unlock()
	print("updated ", triangles, "triangles")

func get_lod_level(q: Vector2i):
	return max(0,max(abs(q.x), abs(q.y))-1)


func create_mesh(world_pos: Vector2, lod_level: int, stitch_at: int):
	#print(world_pos, ": ", 
		#stitch_at & StitchFace.X_NEG,
		#stitch_at & StitchFace.X_POS,
		#stitch_at & StitchFace.Z_NEG,
		#stitch_at & StitchFace.Z_POS)
	var subdivisions: int = BASE_SUBDIVISIONS
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c: float = pow(3,lod_level)
	var m: float = float(CHUNK_SIZE*c) / float(subdivisions)
	for x in subdivisions:
		for z in subdivisions:
			var mz: float = m
			var mx: float = m 
			var wvp: Vector2 = world_pos + Vector2(x,z)*m
			
			var neg_x: float = wvp.x + 0
			var pos_x: float = wvp.x + mx
			var neg_z: float = wvp.y + 0
			var pos_z: float = wvp.y + mz
			
			var pxpzy: float = sample_noise(pos_x, pos_z)
			var nxpzy: float = sample_noise(neg_x, pos_z)
			var pxnzy: float = sample_noise(pos_x, neg_z)
			var nxnzy: float = sample_noise(neg_x, neg_z)
			
			if x == 0 and (stitch_at & StitchFace.X_NEG):
				var stitched: Array = stitch_edge(x, z, world_pos, m, neg_x, 1)
				nxnzy = stitched[0]; nxpzy = stitched[1]
			
			if x == subdivisions-1 and (stitch_at & StitchFace.X_POS):
				var stitched: Array = stitch_edge(x, z, world_pos, m, pos_x, 1)
				pxnzy = stitched[0]; pxpzy = stitched[1]
			
			if z == 0 and (stitch_at & StitchFace.Z_NEG):
				var stitched: Array = stitch_edge(x, z, world_pos, m, neg_z, 0)
				nxnzy = stitched[0]; pxnzy = stitched[1]
			
			if z == subdivisions-1 and (stitch_at & StitchFace.Z_POS):
				var stitched: Array = stitch_edge(x, z, world_pos, m, pos_z, 0)
				nxpzy = stitched[0]; pxpzy = stitched[1]
			#if z == 0 and (stitch_at & StitchFace.Z_NEG): x = snappedi(x, 4); mx *= 4.0
			#if x == subdivisions-1 and (stitch_at & StitchFace.X_POS): z = snappedi(z, 4); mz *= 4.0
			#if z == subdivisions-1 and (stitch_at & StitchFace.Z_POS): x = snappedi(x, 4); mx *= 4.0
			
			
			st.set_normal(get_normal(neg_x,neg_z,m/2.0))
			st.add_vertex(Vector3(neg_x, nxnzy, neg_z))
			st.set_normal(get_normal(pos_x,neg_z,m/2.0))
			st.add_vertex(Vector3(pos_x, pxnzy, neg_z))
			st.set_normal(get_normal(neg_x,pos_z,m/2.0))
			st.add_vertex(Vector3(neg_x, nxpzy, pos_z))
			st.set_normal(get_normal(pos_x,neg_z,m/2.0))
			st.add_vertex(Vector3(pos_x, pxnzy, neg_z))
			st.set_normal(get_normal(pos_x,pos_z,m/2.0))
			st.add_vertex(Vector3(pos_x, pxpzy, pos_z))
			st.set_normal(get_normal(neg_x,pos_z,m/2.0))
			st.add_vertex(Vector3(neg_x, nxpzy, pos_z))
			triangles += 2
	return st.commit()



func stitch_edge(x: int, z: int, world_pos: Vector2, m: float, fixed_val: float, interpolate: int):
	#interpolate = 0: X axis, interpolate = 1: Z axis
	var stitch_res: int = 3
	var var_world: float = world_pos.x if interpolate == 0 else world_pos.y
	var var_id: int = x if interpolate == 0 else z
	var var_snapped: int = (var_id / stitch_res) * stitch_res
	var first: float = var_world + var_snapped * m
	var last: float = first + stitch_res * m
	var fnxpzy: float
	var lnxpzy: float
	if interpolate == 1:
		fnxpzy = sample_noise(fixed_val, first)
		lnxpzy = sample_noise(fixed_val, last)
	else:
		fnxpzy = sample_noise(first, fixed_val)
		lnxpzy = sample_noise(last, fixed_val)
		
	var t0: float = float(var_id % stitch_res) / float(stitch_res)
	var t1: float = float(var_id % stitch_res + 1) / float(stitch_res)
	return [lerp(fnxpzy, lnxpzy, t0),lerp(fnxpzy, lnxpzy, t1)]
	#returns negative then positive side
	#fnxpzy and lnxpzy are the first and last point of the interpolated axis, I didn't know what to
	#name them after testing the first case.


func sample_noise(x: float, z: float):
	return noise.get_noise_2d(x,z)*TERRAIN_HEIGHT


func get_normal(nx: float, nz: float, m: float):
	var hL = noise.get_noise_2d(nx - m, nz) * TERRAIN_HEIGHT
	var hR = noise.get_noise_2d(nx + m, nz) * TERRAIN_HEIGHT
	var hD = noise.get_noise_2d(nx, nz - m) * TERRAIN_HEIGHT
	var hU = noise.get_noise_2d(nx, nz + m) * TERRAIN_HEIGHT

	var normal = Vector3(hL - hR, 2.0 * m, hD - hU)
	return normal.normalized()
	
	
	
	
