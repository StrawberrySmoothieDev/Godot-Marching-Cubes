extends MeshInstance3D
class_name ThreadedChunk
signal done_generating
@export var generate: bool = true
@export var noise: NoiseTexture3D
var data: GenerationData
@export var color_ramp: GradientTexture1D

@export var dbg = false
var full_dbg = false
var generating = false
var isoLevel = 0.0
var thread: Thread
var mutex: Mutex
var pos = Vector3.ZERO
var is_ready = false
var start_time1
var start_time2
var st: SurfaceTool
var is_active = true
var presampled_points: Dictionary
func _ready() -> void:
	st = SurfaceTool.new()
	thread = Thread.new()
	#thread.set_thread_safety_checks_enabled(false)
	#mutex = Mutex.new()
	mesh = mesh.duplicate()
	is_ready = true
	
func init(data:GenerationData):
	self.data = data
	#is_active = eight_point_test()
func u():
	print("Gen " +str(name))
	if is_ready and is_active:
		full_dbg = data.full_debug
		pos = position+owner.position
		
		thread.start(update_mesh)
		#await thread.wait_to_finish()
		#gen_mesh()
		#call_deferred("gen_mesh",thread.wait_to_finish())
		#gen_mesh(update_mesh())
	elif is_ready:
		mesh.clear_surfaces()
func update_mesh(clear_presamp = true):
	var EDGE_CONNECTIONS: Array  = [
		[0,1], [1,2], [2,3], [3,0],
		[4,5], [5,6], [6,7], [7,4],
		[0,4], [1,5], [2,6], [3,7]
	]
	var CORNER_OFFSETS: Array = [
			[0, 0, 1],
			[1, 0, 1],
			[1, 0, 0],
			[0, 0, 0],
			[0, 1, 1],
			[1, 1, 1],
			[1, 1, 0],
			[0, 1, 0]
	]
	if dbg or full_dbg:
		start_time1 = Time.get_ticks_msec()
	generating = true
	isoLevel = data.iso
	
	var res = data.base_res
	var cubes = data.cubes_per_chunk
	var verts = PackedVector3Array()
	var cubeIndex = 0;
	var cubeValues = [0,0,0,0,0,0,0,0]
	#if clear_presamp:
		#presampled_points = Dictionary()
	for x in range(0,cubes/res):
		for y in range(0,cubes/res):
			for z in range(0,cubes/res):
				if dbg:
					print("Generated")
				var offset = Vector3(x,y,z)*res
				#mutex.lock()
				for i in range(0,8):
					var pt = (offset+Vector3(MarchingCubesLibrary.CORNER_OFFSETS_VECTOR[i])*res)+(pos)
					#if suffering.global_presampled_points_dict.has(pt):
						#cubeValues[i] = suffering.global_presampled_points_dict.get(pt)
						#presampled_points[pt] = cubeValues[i]
					#else:
						#var val = remap(data.get_noise(pt),0,1,-1,1)
						#cubeValues[i] = val
						#suffering.global_presampled_points_dict[pt] = val
						#presampled_points[pt] = val
					if presampled_points.has(pt):
						cubeValues[i] = presampled_points.get(pt)
						presampled_points[pt] = cubeValues[i]
					else:
						var val = remap(data.get_noise(pt),0,1,-1,1)
						cubeValues[i] = val
						#presampled_points[pt] = val
						presampled_points[pt] = val
				#mutex.unlock()
					#saved_points_dict[str((offset+Vector3(CORNER_OFFSETS_VECTOR[i]))+(position))] = cubeValues[i]
				if (cubeValues[0] < isoLevel): cubeIndex |= 1 #wha
				if (cubeValues[1] < isoLevel): cubeIndex |= 2
				if (cubeValues[2] < isoLevel): cubeIndex |= 4
				if (cubeValues[3] < isoLevel): cubeIndex |= 8
				if (cubeValues[4] < isoLevel): cubeIndex |= 16
				if (cubeValues[5] < isoLevel): cubeIndex |= 32
				if (cubeValues[6] < isoLevel): cubeIndex |= 64
				if (cubeValues[7] < isoLevel): cubeIndex |= 128 #hhhhhhhhhhhhh

				var edges = MarchingCubesLibrary.TRI_TABLE_DICT[cubeIndex] 
				var i = 0
				var override = 1000 #oop
				while edges[i] != -1 and override > 0:
					#print("Wao")
					override -=1
					
					var e00 = EDGE_CONNECTIONS[edges[i]][0] #0 Basically we pull an index from the data we got from the tritable and use that to look at a certain index of edgeconnections, with the two indexes in edgeconnections being the 2 verticies of the edge
					var e01 = EDGE_CONNECTIONS[edges[i]][1] #1
					#First edge is between vertexes 0 and 1
					var e10 = EDGE_CONNECTIONS[edges[i + 1]][0] #3
					var e11 = EDGE_CONNECTIONS[edges[i + 1]][1] #0
					#Second edge is between vertexes 3 and 0

					var e20 = EDGE_CONNECTIONS[edges[i + 2]][0] #0
					var e21 = EDGE_CONNECTIONS[edges[i + 2]][1] #4
					#Third edge is between vertexes 0 and 4
					
					
					
					var tri = []
					#print(str(interp(CORNER_OFFSETS[e00], cubeValues[e00], CORNER_OFFSETS[e01], cubeValues[e01])))
					#mutex.lock()
					tri.append((offset)+(res*interp(CORNER_OFFSETS[e00], cubeValues[e00], CORNER_OFFSETS[e01], cubeValues[e01],isoLevel))) #append the thinggggggggggggggggggggggggggs
					tri.append((offset)+(res*interp(CORNER_OFFSETS[e10], cubeValues[e10], CORNER_OFFSETS[e11], cubeValues[e11],isoLevel)))
					tri.append((offset)+(res*interp(CORNER_OFFSETS[e20], cubeValues[e20], CORNER_OFFSETS[e21], cubeValues[e21],isoLevel)))
					verts.append_array(tri)
					#mutex.unlock()
					i+=3
				if override <= 0:
					print_debug("Hit while maximum") #krill me
				cubeIndex = 0
	if dbg or full_dbg:
		output_elapsed_time(start_time1)
	#if verts:
		#call_deferred("gen_mesh",verts)
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in verts:
		st.add_vertex(i)
	if data.indexed:
		st.index() #WARNING Indexing might not actually work pain
	st.generate_normals()
	#st.call_deferred("commit",mesh)
	
	call_deferred("gen_mesh")
	
func gen_mesh():
	mesh.clear_surfaces()
	#thread.wait_to_finish()
	st.commit(mesh)
	#if dbg:
		#start_time2 = Time.get_ticks_msec()
	#st.begin(Mesh.PRIMITIVE_TRIANGLES)
	#for i in verts:
		#st.add_vertex(i)
	#if data.indexed:
		#st.index() #WARNING Indexing might not actually work pain
	#st.generate_normals()
	#st.commit(mesh)
	if !mesh.get_surface_count() <= 0: #TODO: test if threading this speeds it up
		$StaticBody3D/CollisionShape3D.shape = mesh.create_trimesh_shape()
		show()
	else:
		$StaticBody3D/CollisionShape3D.shape = null
		hide()
	generating = false
	done_generating.emit()
	if dbg:
		output_elapsed_time(start_time2)
	thread.wait_to_finish()
	#mutex.unlock()

func interp(edgeVertex1A:Array, valueAtVertex1:float, edgeVertex2A:Array, valueAtVertex2:float, isoLevel:float):
	var edgeVertex1 = Vector3(edgeVertex1A[0],edgeVertex1A[1],edgeVertex1A[2])
	var edgeVertex2 = Vector3(edgeVertex2A[0],edgeVertex2A[1],edgeVertex2A[2])
	var comp1 = isoLevel-valueAtVertex1
	var lerp = edgeVertex1 + Vector3(comp1,comp1,comp1) * (edgeVertex2-edgeVertex1) / (valueAtVertex2-valueAtVertex1)
	return lerp

func _exit_tree() -> void:
	if thread.is_alive():
		thread.wait_to_finish()

func PREPARE_TO_DIE():
	
	if !thread.is_alive():
		thread.wait_to_finish()
	queue_free()


func output_elapsed_time(start_time):
	var elapsed_time = Time.get_ticks_msec()-start_time
	var amnt_of_frame = (elapsed_time/16.666666666666667)
	print("Elapsed MS: "+str(elapsed_time)+" Frames elapsed: "+ str(amnt_of_frame))

func eight_point_test():
	var pos2 = position+owner.position
	var inside = -1
	for i in MarchingCubesLibrary.CORNER_OFFSETS_VECTOR:
		var sample = remap(data.get_noise((pos2+Vector3(i*data.cubes_per_chunk))),0.0,1.0,-1.0,1.0)
		var is_inside:bool = sample < data.iso
		if inside == -1:
			inside = int(is_inside)
		elif int(is_inside) != inside:
			return true
	return false
	
	
	#print(str(get_std_dev(arr)))
	#var b0 = remap(data.get_noise(pos),0,1,-1,1)
	#var b1 = remap(data.get_noise(pos+Vector3(data.cubes_per_chunk)),0,1,-1,1)
	#var b2 = remap(data.get_noise(pos+data.cubes_per_chunk),0,1,-1,1)

func get_mean(array):
	var sum = 0
	for i in array:
		sum = sum + i
	var mean = sum/len(array)
	return mean

func get_std_dev(array):
	# get mu
	var mean = get_mean(array)
	# (x[i] - mu)**2
	for i in array:
		array = (i - mean) ** 2
		return array
	var sum_sqr_diff = 0
	# get sigma
	for i in array:
		sum_sqr_diff = sum_sqr_diff + i
		return sum_sqr_diff
	# get mean of squared differences
	var variance = 1/len(array)
	var mean_sqr_diff = (variance * sum_sqr_diff)
	
	var std_dev = sqrt(mean_sqr_diff)
	return std_dev

func set_priority(value: float):
	$DebugOutline/MeshInstance3D/Label3D4.text = "Priority: "+str(value)
	set_instance_shader_parameter("albedo",color_ramp.gradient.sample(value))

var suffering: ThreadedChunker
func initalize(pain):
	suffering = pain

func _physics_process(delta: float) -> void:
	if suffering and $DebugOutline.visible:
		set_priority(suffering.get_chunk_priority(global_position))
		if $DebugOutline.visible:
			$DebugOutline/MeshInstance3D/Label3D2.text = "Position: "+str(global_position)
			$DebugOutline/MeshInstance3D/Label3D3.text = "Chunk ID: "+str(suffering.round_position_to(global_position))

func toggle_DBG():
	$DebugOutline.scale = Vector3(data.cubes_per_chunk,data.cubes_per_chunk,data.cubes_per_chunk)
	$DebugOutline.visible = !$DebugOutline.visible
	if !$DebugOutline.visible:
		set_instance_shader_parameter("albedo",Color("White"))
