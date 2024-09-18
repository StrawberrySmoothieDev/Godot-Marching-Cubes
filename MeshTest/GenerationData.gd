#@tool
extends Resource
class_name GenerationData
signal chunkdata_changed
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
		changed.emit()
@export var cubes_per_chunk: int = 1:
	set(val):
		cubes_per_chunk = val
		chunkdata_changed.emit()
@export var chunks: Vector3i = Vector3i.ONE:
	set(val):
		chunks = val
		chunkdata_changed.emit()
#@export_range(1,20) var base_res: int = 1:
	#set(val):
		#base_res = val
		#changed.emit()
@export var base_res: float = 1.0:
	set(val):
		base_res = val
		changed.emit()

@export var indexed: bool = true:
	set(val):
		indexed = val
		changed.emit()

@export var sphereCenter: Vector3 = Vector3.ZERO:
	set(val):
		sphereCenter = val
		changed.emit()
		
var points = []
func update_mesh():
	changed.emit()


func get_noise(pos: Vector3):
	
	#return noise.noise.get_noise_3dv(pos)
	var dist =1000.0
	if points != [] and !Engine.is_editor_hint():
		for i in points:
			dist = min(pos.distance_to(i),dist)
	else:
		dist = pos.distance_to(sphereCenter)
	return dist
