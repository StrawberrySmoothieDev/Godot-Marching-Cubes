extends Node3D
@export var color_ramp: GradientTexture1D
var manager: ThreadedChunker
func initalize(man):
	manager = man
func set_priority(value: float):
	
	$MeshInstance3D.set_instance_shader_parameter("wireframeColor",color_ramp.gradient.sample(value))

func _physics_process(delta: float) -> void:
	if manager:
		var p = manager.get_chunk_priority($MeshInstance3D.global_position)
		$MeshInstance3D/Label3D.text = str(p)
		set_priority(remap(p,0,4,1,0))

func PREPARE_TO_DIE():
	pass
