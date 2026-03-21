extends Camera3D


func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotation.x -= event.relative.y/100.0
		rotation.y -= event.relative.x/100.0
		rotation_degrees.x = clamp(rotation_degrees.x, -80.0, 80)


func _process(delta):
	var move = Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	
	var speed: float = 10.0
	if Input.is_action_pressed("fast"):
		speed *= 10.0
	global_position += speed*(-move.y * global_basis.z + move.x * global_basis.x)*delta
