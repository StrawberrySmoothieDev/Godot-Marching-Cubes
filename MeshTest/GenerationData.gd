extends Resource
class_name GenerationData
@export var noise: NoiseTexture3D:
	set(val):
		noise = val
		if !noise.changed.is_connected(update_mesh):
			noise.changed.connect(update_mesh)
		if noise.noise and !noise.noise.changed.is_connected(update_mesh):
			noise.noise.changed.connect(update_mesh)
@export var iso: float = 1.0
@export var cubes_per_chunk: int = 1
@export var chunks: Vector3 = Vector3.ONE
@export_range(1,20) var base_res: int = 1
@export var indexed: bool = true


func update_mesh():
	changed.emit()
