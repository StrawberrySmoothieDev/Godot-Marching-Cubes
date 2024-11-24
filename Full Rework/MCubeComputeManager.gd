@tool
extends Node
class_name MCubeComputeMan

@export var generate: bool:
	set(val):
		if is_ready:
			recursive_compute()

@export_category("Generation Parameters")
@export var iso:float = 1.0:
	set(val):
		iso = val
		if is_ready:
			recursive_compute()
@export var seed:float = 1.0:
	set(val):
		seed = val
		if is_ready:
			recursive_compute()
@export var recursive_count:int = 1:
	set(val):
		recursive_count = val
		if is_ready:
			recursive_compute()
@export var noise_scale:Vector3 = Vector3.ONE:
	set(val):
		noise_scale = val
		if is_ready:
			recursive_compute()
@export var origin_position_offset: Vector3 = Vector3.ZERO:
	set(val):
		origin_position_offset = val
		if is_ready:
			recursive_compute()
@export var clean_up_mesh: bool:
	set(val):
		clean_up_mesh = val
		if is_ready:
			recursive_compute()
@export var should_save_data_as_image: bool = false
@export var dimentions: Vector3 = Vector3.ONE:
	set(val):
		dimentions = val
		if is_ready:
			prep_meshes()
@export_category("Compute Shader Info")
@export var invocations:int = 8


var rd: RenderingDevice ##Local rendering device used for just about everything. You can think of this as a """""virtual GPU""""" (but it's more like a virtual GPU interface)
var compute_shader: RID ##Compiled bytecode of the shader that is run on the GPU.
var r_pipeline: RID ##Rendering pipeline. Used to execute the shader and other shenanaginry.
var uniform_set: RID ##Used to communicate between the CPU and GPU.
var output_buffer: RID ##Ref to the output buffer, the GPU writes to this and we read it to get the mesh.
var param_buffer: RID ##Param buffer, stores iso, scale, noise, etc to send to the GPU.
var counter_buffer: RID ##Counter buffer. Stores the number of itterations that occured when generating, used to calculate the # of triangles.
var debug_buffer: RID ##Debug output buffer.
var point_data_buffer: RID
var is_ready = false
var start_time

@export_category("Profiling Options")
@export var should_profile:bool = false
@export var use_arraymesh: bool = false
@export var average_time_arraymesh: float
@export var average_time_surfacetool: float
@export var debug_buffer_out:PackedInt32Array
@export var img_out: PackedByteArray
@export var img_out_tex: Image

var times_arraymesh: PackedFloat32Array
var times_surfacetool: PackedFloat32Array




var vertex_data: PackedFloat32Array
var counter_data: int
class TriVertexData:
	var position:Vector3
	var normal:Vector3
	var index: int
	static func instance(pos,norm):
		var inst = TriVertexData.new()
		inst.position = pos
		inst.normal = norm
		return inst
func _ready() -> void:
	times_arraymesh.clear()
	times_surfacetool.clear()
	is_ready = true
	prep_compute()
	if !Engine.is_editor_hint():
		#seed = randf_range(0,42069420)
		recursive_compute()
	#for i in get_children():
		##i.mesh = i.mesh.duplicate()
		#i.position/=Vector3(8,8,8)
		#i.position*=16
		
func prep_meshes():
	for x in range(dimentions.x):
		for y in range(dimentions.y):
			for z in range(dimentions.z):
				var inst = MarchedMesh.new()
				add_child(inst)
func prep_compute() -> void: ##Creates ALL the rendering garbage, buffers, SPIR-V, pipeline, etc.
	if rd == null:
		rd = RenderingServer.create_local_rendering_device() #Extra rendering device we use to run the comp shader
	var shader_file := load("res://Full Rework/computeManPreview.glsl") #Load shader file (preview)
	#var shader_file := load("res://ComputeShader/computeMan.glsl") #Load shader file
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv() #Create intermediary SPIR-V code we compile into the bytecode executed by the engine/OS
	compute_shader = rd.shader_create_from_spirv(shader_spirv) #Compile that SPIRV into a usable shader
	
	
	var input := PackedFloat32Array([iso,noise_scale.x,noise_scale.y,noise_scale.z,origin_position_offset.x,origin_position_offset.y,origin_position_offset.z,seed]) #Params for the shader
	var input_as_bytes = input.to_byte_array() #Convert data to raw bytes
	param_buffer = rd.storage_buffer_create(input_as_bytes.size(),input_as_bytes) #Create a buffer in the custom rendering device
	var uniform = RDUniform.new() #Make new uniform so we can pass data to the GPU
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER #Set uniform type
	uniform.binding = 0 #Bind uniform, this must be equal to the binding var in the comp shader
	uniform.add_id(param_buffer) #bind the databuffer to the uniform
	



	output_buffer = rd.storage_buffer_create(get_output_max_bytes()) #Make the buffer we'll read from
	var output_uniform = RDUniform.new() #uniform
	output_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER #set type
	output_uniform.binding = 1 #binding is 1 matching binding in shader
	output_uniform.add_id(output_buffer) #bind buffer
	
	
	var counter = [0] #don't ask why it's an array I dont fucking know xd
	var counter_bytes = PackedInt32Array(counter).to_byte_array() #make it into raw bytes in the most scuffed way possible
	counter_buffer = rd.storage_buffer_create(counter_bytes.size(),counter_bytes) #you know the drill by now
	var c_uniform = RDUniform.new() #cross the linedef to spawn extra revenants
	c_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER #grab the megasphere
	c_uniform.binding = 2 #grab the bfg
	c_uniform.add_id(counter_buffer) #grab the supercharge
	
	debug_buffer = rd.storage_buffer_create((16*8)/4)
	var dbg_uniform = RDUniform.new()
	dbg_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	dbg_uniform.binding = 3
	dbg_uniform.add_id(debug_buffer)
	#and freaking die
	#https://www.youtube.com/decino

	
	var dataformat := RDTextureFormat.new()
	dataformat.width = invocations
	dataformat.height = invocations
	dataformat.depth = invocations
	dataformat.texture_type = RenderingDevice.TEXTURE_TYPE_3D
	dataformat.format = RenderingDevice.DATA_FORMAT_R8_UNORM
	dataformat.usage_bits = \
			RenderingDevice.TEXTURE_USAGE_STORAGE_BIT + \
			#RenderingDevice.TEXTURE_USAGE_CPU_READ_BIT + \ #For more info on this rat bastard see here (https://app.milanote.com/1SJ1Nd16j7xv2T?p=0ULmZcMVtYC) and look for the doc labled "CPU texture readback jank"
			RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT + \
			RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT 
	point_data_buffer = rd.texture_create(dataformat,RDTextureView.new())
	var data_buffer_uniform = RDUniform.new()
	data_buffer_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	data_buffer_uniform.binding = 4
	data_buffer_uniform.add_id(point_data_buffer)
	
	
	
	
	
	
	
	uniform_set = rd.uniform_set_create([uniform,output_uniform,c_uniform,dbg_uniform,data_buffer_uniform],compute_shader,0) #ID:03 Creates the uniform set and sends all them to the gpu. The 0 at the end spesifies the uniform set, matching the set values in the layouts/uniforms in the shader. XD
	
	r_pipeline = rd.compute_pipeline_create(compute_shader) #Make an instruction set for the GPU to execute
	
func kill_existing_compute():
	rd.free_rid(compute_shader)
	rd.free_rid(r_pipeline)
	rd.free_rid(uniform_set)
	rd.free_rid(output_buffer)
	rd.free_rid(param_buffer)
	rd.free_rid(counter_buffer)
	rd.free_rid(debug_buffer)
	rd.free_rid(point_data_buffer)
	

func get_output_max_bytes():
	const max_tris_per_voxel : int = 5 ##Constant value due to how marching cubes is done. The most triangles in a single MCube voxel is 5.
	var max_triangles : int = max_tris_per_voxel * int(pow(invocations, 3))*recursive_count ##Max triangles = max_tris_per_voxel * (the number of invocations^the number of dimentions) For more info on invocations, see comment ID:02 in the compute shader for more info.
	const bytes_per_float : int = 4 ##We use 32 bit floats, and there are 8 bits in each byte. 32/8 = 4, therefore 4 bytes per float.
	const floats_per_triangle : int = 3 * 4 ##Each triangle has 4 vectors each composed of 3 floats, 3 for each of the verts and 1 for the normal direction.
	const bytes_per_triangle : int = floats_per_triangle * bytes_per_float ##number of floats per tri * bytes per float gives us the max amount of a space a triangle can take up in memory
	var max_bytes : int = bytes_per_triangle * max_triangles ##max bytes per tri * max tris gives us the max possible size of the mesh. We then use this to set the size of the output buffer to avoid malloc (memory acllocation) errors.
	return max_bytes


func recursive_compute(itterations: int = recursive_count,resolution:int = invocations):
	#target.mesh.clear_surfaces()
	start_time = Time.get_ticks_msec()
	for i in get_children():
		i.mesh.clear_surfaces()
		run_compute(i,false,i.position,recursive_count)
		#for x in range(itterations):
			#for y in range(itterations):
				#for z in range(itterations):
					#var offset = (Vector3(x,y,z)*resolution)+i.position
					#run_compute(i,false,offset)
	if should_profile:
		output_elapsed_time()
func run_compute(target: MarchedMesh,erase_existing_mesh = true,offset_positon:Vector3 = Vector3.ZERO,workgroups:int = 1) -> void: ##Function to actually generate and build the mesh. Automatically calls process_output().
	if is_ready: #J-J-J-J A N K (preventing it from attempting to generate when not all the resources are loaded)
		#print("guh")
		
		if should_save_data_as_image:
			if target.saved_point_data == null:
				var bpd_array = [] #bipolar disorder array me fr
				for i in range(invocations):
					var inst = Image.create(invocations,invocations,false,Image.FORMAT_R8)
					bpd_array.append(inst)
				var base_p_data = ImageTexture3D.new()
				base_p_data.create(Image.FORMAT_R8,invocations,invocations,invocations,false,bpd_array)
				target.saved_point_data = base_p_data
		
		vertex_data.clear()
		if erase_existing_mesh:
			target.mesh.clear_surfaces()
		var o_pos = origin_position_offset+offset_positon
		var new_parameter_buffer = PackedFloat32Array([iso,noise_scale.x,noise_scale.y,noise_scale.z,o_pos.x,o_pos.y,o_pos.z,seed]).to_byte_array()
		rd.buffer_update(param_buffer,0,new_parameter_buffer.size(),new_parameter_buffer)
		var c_buffer = PackedInt32Array([0]).to_byte_array() #reset the counter buffer
		rd.buffer_update(counter_buffer,0,c_buffer.size(),c_buffer)
		rd.buffer_clear(debug_buffer,0,rd.buffer_get_data(debug_buffer).size())
		if should_save_data_as_image:
			rd.texture_update(point_data_buffer,0,target.get_image_data())
		var compute_list = rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(compute_list,r_pipeline)
		rd.compute_list_bind_uniform_set(compute_list,uniform_set,0)
		rd.compute_list_dispatch(compute_list,workgroups,workgroups,workgroups)
		rd.compute_list_end()
		rd.submit()
		rd.sync()
		vertex_data = get_output_data()
		counter_data = get_counter_data()
		if should_save_data_as_image:
			img_out = rd.texture_get_data(point_data_buffer,0)
			var img_data_array = []
			for i in range(0,pow(invocations,3),64):
				var slice = img_out.slice(i,i+64)
				var img_out_tex = Image.create_from_data(8,8,false,Image.FORMAT_R8,slice)
				img_data_array.append(img_out_tex)
			target.saved_point_data = ImageTexture3D.new()
			target.saved_point_data.create(Image.FORMAT_R8,8,8,8,false,img_data_array)
		if use_arraymesh:
			output_to_mesh_arraymesh(vertex_data,counter_data,target)
		else:
			output_to_mesh_surfacetool(vertex_data,counter_data,target,o_pos)
		
		
func get_output_data():
	var output_bytes:PackedByteArray = rd.buffer_get_data(output_buffer)
	var as_floats = output_bytes.to_float32_array()
	return as_floats
func get_counter_data():
	var output_bytes = rd.buffer_get_data(counter_buffer).to_int32_array()[0]
	#print(str(output_bytes))
	return output_bytes


func output_to_mesh_surfacetool(data: PackedFloat32Array,counterin:int,mesh:MarchedMesh,offset:Vector3):
	
	var surf = SurfaceTool.new() #SurfaceTool instance. We use this as it lets us quickly generate normals and indexes and is generally pain-free. Will proably replace soon.
	surf.begin(Mesh.PRIMITIVE_TRIANGLES) #Start the mesh. Required b4 you start adding verts.

	var offset2 = offset - mesh.position
	var num_tris = counterin #Figure out the number of triangles we need to itterate over
	if !num_tris: #If there's no triangles
		#print("ERROR: num_tris failed to convert") #This is not always the case. This error will also be thrown if the chunk simply has no verts (ie it is empty)
		return #End func to save processing time
	#var num_tris = 3
	for i in range(0,num_tris): #For all of the triangles
		var index = i*16 #Index = i*16, where 16 is the number of indexes each tri takes up.
		#For some ungodly reason, each vec3 in the triangle struct takes up 4 indexes with the last one being a meaningless zero i have NO IDEA why this happens help
		#This results in 4 indexes per vector * 4 vectors per tri = 16 indexes per tri
		if index < data.size():
			var posA = Vector3(data[index + 0], data[index + 1], data[index + 2])+offset2 #First position
			var posB = Vector3(data[index + 4], data[index + 5], data[index + 6])+offset2 #Second pos, skipping data[index+3] because it's just always a 0
			var posC = Vector3(data[index + 8], data[index + 9], data[index + 10])+offset2 #Third pos, skipping data[index+7] because it's just always a 0
			surf.set_normal(-Vector3(data[index + 12], data[index + 13], data[index + 14]))
			surf.add_vertex(posC)
			surf.set_normal(-Vector3(data[index + 12], data[index + 13], data[index + 14]))
			surf.add_vertex(posB)
			surf.set_normal(-Vector3(data[index + 12], data[index + 13], data[index + 14])) #this func sets the normal FOR THE NEXT VERTEX. This results in flat shading, as all vtexes in a face have the same normal.
			surf.add_vertex(posA) #add vtex
		else:
			print("Overflow!")



	if clean_up_mesh:
		surf.generate_normals()
		surf.index() #attempts to merge identicle verts, but breaks bc they aren't exactly the same. I'll write a custom version soonish.
		surf.optimize_indices_for_cache()
	#if mesh.mesh.get_surface_count() <= 0:
		#mesh.get_child(0).get_child(0).shape = null
	#else:
		#mesh.get_child(0).get_child(0).shape = mesh.mesh.create_trimesh_shape()
	
	surf.commit(mesh.mesh) #Finishes the mesh, automatically updating $MeshInstance3D.mesh
	if !Engine.is_editor_hint():
		mesh.mesh_ready()
	#if should_profile:
		#var elapsed_time = Time.get_ticks_msec()-start_time
		#var amnt_of_frame = (elapsed_time/16.666666666666667)
		#times_surfacetool.append(elapsed_time)
		#average_time_surfacetool = avgf(times_surfacetool)
		#print("Elapsed MS: "+str(elapsed_time)+" Frames elapsed: "+ str(amnt_of_frame))
	debug_buffer_out = rd.buffer_get_data(debug_buffer).to_int32_array()
func output_to_mesh_arraymesh(data: PackedFloat32Array,counterin:int,mesh:MeshInstance3D):
	
	if !counterin: #If there's no triangles
		#print("ERROR: num_tris failed to convert") #This is not always the case. This error will also be thrown if the chunk simply has no verts (ie it is empty)
		#print("pain")
		return #E
	var a_mesh = ArrayMesh.new()
	var surf_array = []
	surf_array.resize(Mesh.ARRAY_MAX)
	var verts = PackedVector3Array()
	var verts_dict: Dictionary
	var normals = PackedVector3Array()
	var num_tris = counterin
	var processed_vertexes: Dictionary
	for i in range(0,num_tris): #For all of the triangles
		var index = i*16 #Index = i*16, where 16 is the number of indexes each tri takes up.
		#For some ungodly reason, each vec3 in the triangle struct takes up 4 indexes with the last one being a meaningless zero i have NO IDEA why this happens help
		#This results in 4 indexes per vector * 4 vectors per tri = 16 indexes per tri

		var posA = Vector3(data[index + 0], data[index + 1], data[index + 2]) #First position
		var normA = Vector3(data[index + 12], data[index + 13], data[index + 14])
		normals.append(normA)
		verts.append(posA)
		var vd1 = TriVertexData.instance(posA,normA)
		processed_vertexes[processed_vertexes.size()] = vd1
		var posB = Vector3(data[index + 4], data[index + 5], data[index + 6]) #Second pos, skipping data[index+3] because it's just always a 0
		var normB = Vector3(data[index + 12], data[index + 13], data[index + 14])
		normals.append(normB)
		verts.append(posB)
		var vd2 = TriVertexData.instance(posB,normB)
		processed_vertexes[processed_vertexes.size()] = vd2
		var posC = Vector3(data[index + 8], data[index + 9], data[index + 10]) #Third pos, skipping data[index+7] because it's just always a 0
		var normC = Vector3(data[index + 12], data[index + 13], data[index + 14])
		normals.append(normC)
		verts.append(posC)
		var vd3 = TriVertexData.instance(posC,normC)
		processed_vertexes[processed_vertexes.size()] = vd3
		#normals.append(normal_calc(posA,posB,posC))
		
	var index_dict: Dictionary
	var new_vertex_dict: Dictionary
	var itteration = 0
	var new_norm_array: PackedVector3Array
	var vert_norms:Array[Array]
	vert_norms.resize(num_tris*3)
	for index in range(num_tris*3):
		var vert_data: TriVertexData = processed_vertexes[index]
		#var exists = new_vertex_dict.get()
		var t = new_vertex_dict.find_key(vert_data.position)
		if !t:
			
			index_dict[index_dict.size()] = itteration
			vert_data.index = itteration
			new_vertex_dict[new_vertex_dict.size()] = vert_data.position
			new_norm_array.append(normals[index])
			vert_norms[index].append(normals[index])
			itteration += 1
			#print("no merge")
		else:
			vert_norms[index].append(normals[index])
			new_norm_array[t] = avg(vert_norms[index])
			
			index_dict[index_dict.size()] = t
			vert_data.index = t
			#print("Merge")
	#normals.resize(index_dict.size())
	#print(str(index_dict))

	var indexes_as_array = PackedInt32Array(index_dict.values())
	surf_array[Mesh.ARRAY_INDEX] = indexes_as_array
	surf_array[Mesh.ARRAY_VERTEX] = PackedVector3Array(new_vertex_dict.values())
	#surf_array[Mesh.ARRAY_VERTEX] = verts
	surf_array[Mesh.ARRAY_NORMAL] = new_norm_array
	a_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,surf_array)
	mesh.mesh = a_mesh



func _notification(type): ##IMPORTANT: Used to free refs to the rendering stuff on deletion. Without this, will result in a ton of memory leaks.
	if type == NOTIFICATION_PREDELETE: #Need this conditon so we don't delete ourself when we recive any notification
		release()

func release() -> void: ##Function that frees the memory of all the RIDs we made and kept track of. Remeber, unlike resources, RIDs don't automatically free themselves.
	rd.free_rid(r_pipeline)
	rd.free_rid(output_buffer)
	rd.free_rid(param_buffer)
	rd.free_rid(counter_buffer);
	rd.free_rid(compute_shader)
	rd.free_rid(debug_buffer)
	rd.free_rid(point_data_buffer)
	debug_buffer = RID()
	#rd.free_rid(noisemap_texture_rid)
	#rd.free_rid(noisemap_sampler)
	r_pipeline = RID()
	output_buffer = RID()
	param_buffer = RID()
	counter_buffer = RID()
	compute_shader = RID()
	point_data_buffer = RID()
	
	#noisemap_texture_rid = RID()
	#noisemap_sampler = RID()
		
	rd.free()
	rd= null

func normal_calc(pointA:Vector3,pointB:Vector3,pointC:Vector3):
	var ab = pointB - pointA
	var ac = pointC - pointA
	return (ab.cross(ac).normalized())

func avg(array:Array):
	var t: Vector3
	for i in array:
		t+=i
	return t/array.size()

func avgf(array:Array):
	var t: float
	for i in array:
		t+=i
	return t/array.size()

func output_elapsed_time():
	var elapsed_time = Time.get_ticks_msec()-start_time
	var amnt_of_frame = (elapsed_time/16.666666666666667)
	times_arraymesh.append(elapsed_time)
	average_time_arraymesh = avgf(times_arraymesh)
	print("Elapsed MS: "+str(elapsed_time)+" Frames elapsed: "+ str(amnt_of_frame))
