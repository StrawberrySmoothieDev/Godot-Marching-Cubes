@tool
extends Node3D
@export var noise: NoiseTexture3D:
	set(val):
		noise = val
		if !noise.changed.is_connected(update_mesh):
			noise.changed.connect(update_mesh)
		if noise.noise and !noise.noise.changed.is_connected(update_mesh):
			noise.noise.changed.connect(update_mesh)
@export var iso: float = 1.0:
	set(val):
		iso = val
		update_mesh()
@export var cubes: int = 1:
	set(val):
		cubes = val
		update_mesh()
@export_range(1,20) var res: int = 1:
	set(val):
		res = val
		update_mesh()
@export var indexed: bool = true:
	set(val):
		indexed = val
		update_mesh()

# Called when the node enters the scene tree for the first time.
var isready = false
func _ready() -> void:
	isready = true


func update_mesh():
	if isready:
		if noise:
			for i in get_children():
				if i is MarchedCube:
					i.update_mesh(iso,noise,cubes,res)
