@tool
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
@export var noise_power: float = 1.0:
	set(val):
		noise_power = val
		changed.emit()

@export var indexed: bool = true:
	set(val):
		indexed = val
		changed.emit()

@export var sphereCenter: Vector3 = Vector3.ZERO:
	set(val):
		sphereCenter = val
		changed.emit()
@export var full_debug = false
var points = []
func update_mesh():
	changed.emit()


func get_noise(pos: Vector3):
	


	var dist = pos.distance_to(sphereCenter) + (noise.noise.get_noise_3dv(pos)*noise_power)
	#var dist = noise.noise.get_noise_3dv(pos)*noise_power
	#var shear = Transform3D()
	#shear.basis.x = Vector3(1,0,1)
	#pos = shear*pos
	#var cut = noise.color_ramp.sample(noise.noise.get_noise_3dv(pos)*16).r
	#var r = remap(cut,0,1,-2,1)
	#return op_sdf_subtration(sdf_cone_ie(pos, Vector3(10.0,10.0,0),Vector2(4,1),16),r)
	return dist
	#return cut

static func sdf_torus(sample_pos: Vector3, center_pos: Vector3, factor: Vector2):
	sample_pos-=center_pos
	var base = Vector2(Vector2(sample_pos.x,sample_pos.z).length()-factor.x,sample_pos.y)
	return base.length()-factor.y


static func sdf_cone_ie(sample_pos: Vector3, center_pos:Vector3, factor:Vector2,height:float):
	sample_pos-=center_pos +Vector3(0,(height/2),0)
	var q = Vector2(sample_pos.x,sample_pos.z).length();
	return max(factor.dot(Vector2(q,sample_pos.y)),-height-sample_pos.y);


static func op_sdf_subtration(original:float, cutter:float):
	return max(-cutter,original)
