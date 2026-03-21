class_name ProceduralWorld
extends Node3D


static var noise := FastNoiseLite.new()


@export var world_mesh_generator: WorldMeshGenerator



func _init():
	RenderingServer.set_debug_generate_wireframes(true)



func _input(event):
	if event is InputEventKey and Input.is_key_pressed(KEY_P):
		get_viewport().debug_draw = (get_viewport().debug_draw + 1 ) % 5
		
		
func _ready():
	world_mesh_generator.noise = noise
