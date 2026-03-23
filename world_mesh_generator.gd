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
const CHUNK_SIZE: float = 30.0
const TERRAIN_HEIGHT: float = 30.0
const BASE_SUBDIVISIONS: int = 24
const WATER_LEVEL: float = 0.0

var mutex := Mutex.new()
var update_mesh_instances_thread := Thread.new()

@export var noise: FastNoiseLite
@export var terrain_material: ShaderMaterial
@export var water_material: ShaderMaterial

var old_cq: Vector2i = Vector2i.MIN
var mesh_instances_initiated: bool = false

var mesh_instances: Dictionary[Vector2i, MeshInstance3D]
var water_mesh_instances: Dictionary[Vector2i, MeshInstance3D]
var mesh_instances_updating: bool = false
var mesh_instances_updated: bool = false
var updated_meshes: Dictionary[Vector2i, ArrayMesh]
var updated_water_meshes: Dictionary[Vector2i, ArrayMesh]


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
			updated_water_meshes.clear()
			update_mesh_instances_thread.start(update_mesh_instances.bind(cq))
			old_cq = cq
		if mesh_instances_updating and mesh_instances_updated:
			print("bruruuh")
			update_mesh_instances_thread.wait_to_finish()
			mesh_instances_updating = false
			mesh_instances_updated = false
			for q in updated_meshes:
				mesh_instances[q].mesh = updated_meshes[q]
				water_mesh_instances[q].mesh = updated_water_meshes[q]
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
				water_mesh_instances[q] = MeshInstance3D.new()
				add_child(mesh_instances[q])
				add_child(water_mesh_instances[q])
				mesh_instances[q].global_position = Vector3()
				mesh_instances[q].material_override = terrain_material
				water_mesh_instances[q].global_position = Vector3()
				water_mesh_instances[q].material_override = water_material
				#mesh_instances[q].global_position = Vector3(q.x, 0.0, q.y) * CHUNK_SIZE * c
				#mat.albedo_color = Color(lod_level/float(LOD_LEVELS), 0, 0)
				
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
				updated_water_meshes[q] = create_water_mesh(Vector2(world_pos.x, world_pos.z), lod_level)
	mesh_instances_updated = true
	mutex.unlock()
	print("updated ", triangles, "triangles")

func get_lod_level(q: Vector2i):
	return max(0,max(abs(q.x), abs(q.y))-1)


func create_mesh(world_pos: Vector2, lod_level: int, stitch_at: int):
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
			
			st.set_color(get_biome_vertex_color(neg_x, neg_z))
			st.set_normal(get_normal(neg_x,neg_z,m))
			st.add_vertex(Vector3(neg_x, nxnzy, neg_z))
			
			st.set_color(get_biome_vertex_color(pos_x, neg_z))
			st.set_normal(get_normal(pos_x,neg_z,m))
			st.add_vertex(Vector3(pos_x, pxnzy, neg_z))
			
			st.set_color(get_biome_vertex_color(neg_x, pos_z))
			st.set_normal(get_normal(neg_x,pos_z,m))
			st.add_vertex(Vector3(neg_x, nxpzy, pos_z))
			
			st.set_color(get_biome_vertex_color(pos_x, neg_z))
			st.set_normal(get_normal(pos_x,neg_z,m))
			st.add_vertex(Vector3(pos_x, pxnzy, neg_z))
			
			st.set_color(get_biome_vertex_color(pos_x, pos_z))
			st.set_normal(get_normal(pos_x,pos_z,m))
			st.add_vertex(Vector3(pos_x, pxpzy, pos_z))
			
			st.set_color(get_biome_vertex_color(neg_x, pos_z))
			st.set_normal(get_normal(neg_x,pos_z,m))
			st.add_vertex(Vector3(neg_x, nxpzy, pos_z))
			triangles += 2
	return st.commit()


func create_water_mesh(world_pos: Vector2, lod_level: int):
	var subdivisions: int = BASE_SUBDIVISIONS
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c: float = pow(3,lod_level)
	var m: float = float(CHUNK_SIZE*c) / float(subdivisions)
	for x in subdivisions:
		for z in subdivisions:
			var wvp: Vector2 = world_pos + Vector2(x,z)*m
			
			var neg_x: float = wvp.x + 0
			var pos_x: float = wvp.x + m
			var neg_z: float = wvp.y + 0
			var pos_z: float = wvp.y + m
			
			st.set_uv(Vector2(neg_x,neg_z))
			st.set_color(get_biome_vertex_color(neg_x, neg_z))
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(neg_x, WATER_LEVEL, neg_z))
			
			st.set_uv(Vector2(pos_x,neg_z))
			st.set_color(get_biome_vertex_color(pos_x, neg_z))
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(pos_x, WATER_LEVEL, neg_z))
			
			st.set_uv(Vector2(neg_x,pos_z))
			st.set_color(get_biome_vertex_color(neg_x, pos_z))
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(neg_x, WATER_LEVEL, pos_z))
			
			st.set_uv(Vector2(pos_x,neg_z))
			st.set_color(get_biome_vertex_color(pos_x, neg_z))
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(pos_x, WATER_LEVEL, neg_z))
			
			st.set_uv(Vector2(pos_x,pos_z))
			st.set_color(get_biome_vertex_color(pos_x, pos_z))
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(pos_x, WATER_LEVEL, pos_z))
			
			st.set_uv(Vector2(neg_x,pos_z))
			st.set_color(get_biome_vertex_color(neg_x, pos_z))
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(neg_x, WATER_LEVEL, pos_z))
			triangles += 2
	return st.commit()


func get_biome_vertex_color(x: float, z: float) -> Color:
	
	var temperature: float = BiomeManager.get_temperature(x,z)
	var humidity: float = BiomeManager.get_humidity(x,z)
	
	var temperature_id: int = BiomeManager.get_temperature_id(temperature)
	var humidity_id: int = BiomeManager.get_humidity_id(humidity)

	var main_biome_id: int = get_biome_id(temperature_id, humidity_id)
	
	var frac_temp: float = (fmod(temperature*8.0,2.0)-1.0)
	var frac_hum: float = (fmod(humidity*4.0,2.0)-1.0)
	
	var second_biome_temperature_id: int = temperature_id
	var second_biome_humidity_id: int = humidity_id
	if (frac_temp < 0 and temperature_id == 0) or (frac_temp > 0 and temperature_id == 3): frac_temp = 0
	if (frac_hum < 0 and humidity_id == 0) or (frac_hum > 0 and humidity_id == 1): frac_hum = 0
	if abs(frac_temp) > abs(frac_hum):
		second_biome_temperature_id += sign(frac_temp)
	elif abs(frac_hum) > abs(frac_temp):
		second_biome_humidity_id += sign(frac_hum)
	
	var second_biome_id: int = get_biome_id(second_biome_temperature_id, second_biome_humidity_id)
	
	var blend = max(abs(frac_temp), abs(frac_hum))
	blend = clamp((blend-0.9)*10.0,0.0,1.0)*0.5
	
	
	return Color.from_rgba8(main_biome_id*32, second_biome_id*32, int(blend*255.0), 255)


func get_biome_id(temperature_id: int, humidity_id: int):
	return (3-temperature_id)+humidity_id*4


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
	
	
	
	
