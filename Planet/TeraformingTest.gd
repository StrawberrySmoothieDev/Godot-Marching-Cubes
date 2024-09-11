extends RayCast3D
@export var max_dist = 0.3

func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("M1") or Input.is_action_just_pressed("Dig"):
		force_raycast_update()
		var pos = get_collision_point()
		
		if is_colliding():
			var mc = get_collider().get_parent()
			%ComputeTest.terraform(pos,mc)
