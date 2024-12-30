@tool
extends MeshInstance3D
@export var hide_in_game = true

# Called when the node enters the scene tree for the first time.
func _ready():
	if Engine.is_editor_hint():
		show()
	elif hide_in_game:
		hide()
