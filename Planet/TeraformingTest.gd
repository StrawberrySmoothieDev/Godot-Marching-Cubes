extends Marker3D
@export var max_dist = 0.3
@onready var ray: RayCast3D = $RayCast3D

func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("Dig"):
		for i:MarchedCube in get_tree().get_nodes_in_group("MarchedCube"):
			owner.data.points.append(global_position)
			if i.global_position.distance_to(global_position)< max_dist:
			
				i.update_mesh(owner.data)
		#ray.force_raycast_update()
		#var col = ray.get_collider()
		#if col:
			#
			#var cube: MarchedCube = col.owner
			#cube.save_values = true
			#for i in cube.saved_points_dict:
				#var tmp = float(cube.saved_points_dict[i])-0.5*delta
				#
				#cube.saved_points_dict[i] = tmp
