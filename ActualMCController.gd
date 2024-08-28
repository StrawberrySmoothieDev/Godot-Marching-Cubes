@tool
extends Node3D
@export var noise: NoiseTexture3D:
	set(val):
		noise = val
		if !noise.changed.is_connected(update_mesh):
			noise.changed.connect(update_mesh)
@export var iso: float = 1.0:
	set(val):
		iso = val
		update_mesh()
@export var mult: float = 1.0:
	set(val):
		mult = val
		update_mesh()
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func update_mesh():
	for i in get_children():
		if i is MarchedCube:
			i.upadate_mesh(iso,noise,mult)
