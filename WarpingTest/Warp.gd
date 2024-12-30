@tool
extends MeshInstance3D
@export var marker: Marker3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if marker:
		material_override.set_shader_parameter("warp_pos",marker.global_position)
