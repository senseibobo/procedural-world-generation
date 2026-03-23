extends Node


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func get_temperature_id(temperature: float):
	return clampi(int(temperature*4.0),0,1)


func get_humidity_id(humidity: float):
	return clampi(int(humidity*2.0),0,1)


func get_temperature(x: float, z: float):
	return clamp(ProceduralWorld.temperature_noise.get_noise_2d(x,z) * 0.5 + 0.5, 0.0, 1.0)


func get_humidity(x: float, z: float):
	return clamp(ProceduralWorld.humidity_noise.get_noise_2d(x,z) * 0.5 + 0.5, 0.0, 1.0)
