class_name ProceduralWorld
extends Node3D


static var terrain_noise: FastNoiseLite
static var temperature_noise: FastNoiseLite
static var humidity_noise: FastNoiseLite

@export var _terrain_noise: FastNoiseLite
@export var _temperature_noise: FastNoiseLite
@export var _humidity_noise: FastNoiseLite
@export var world_mesh_generator: WorldMeshGenerator



func _init():
	RenderingServer.set_debug_generate_wireframes(true)

		
func _ready():
	terrain_noise = _terrain_noise
	temperature_noise = _temperature_noise
	humidity_noise = _humidity_noise
	world_mesh_generator.noise = _terrain_noise


func _input(event):
	if event is InputEventKey and Input.is_key_pressed(KEY_P):
		get_viewport().debug_draw = (get_viewport().debug_draw + 1 ) % 5
