
@tool ##Makes it run in the editor
extends Node3D
class_name MarchingCubesComputeManager
##This is a mathamatical algorithem for turning a 3D function (a scalar field) into a 3D mesh. A scalar field is a mathamatic function that takes in a point in space returns a value. Think of it like 3D noise.
##The code you see here IS NOT responsible for the actual mesh generation. Instead, it's a handler script for a compute shader that actually generates the mesh.
##A compute shader is a special shader that runs math and other garbage on the GPU STUPIDLY fast. It does this by running the same calculation thousands of times in parrallel, something that GPUs can do really well unlike CPUS.

@onready var tex_raster:SubViewport = $SubViewport ##Subviewport we use to turn shaders into 3d images, effectively allowing me to use visualshaders to generate noise
@export var iso:float = 1.0: ##iso AKA the value that is compared to points sampled from the scalar feild to figure out where there's a mesh. TLDR if this is higher than the value of the noise at that point, the point is inside the mesh.
	set(val): #setter function
		iso = val #set the value
		run_compute() #update the mesh

@export var res: int = 1 ##number of workgroups we execute. This is basically the number of times we run the compute shader, except we run it res^3 times. See comment ID:01 for more info.
@export var noise_scale: Vector3 = Vector3.ZERO: ##Multiplies the coords of the texture. This effectively makes the texture smaller or larger along the 3 axises.
	set(val):
		noise_scale = val
		run_compute()
#@export var noise: NoiseTexture3D: #DEPRECATED: Old implementation for the editor to compute noise. We now use the noisegraph. You can safely ignore this.
	#set(val):
		#noise = val
		#if !noise.changed.is_connected(run_compute):
			#noise.changed.connect(run_compute)
		#if !noise.noise.changed.is_connected(run_compute):
			#noise.noise.changed.connect(run_compute)
var data_out: PackedFloat32Array ##Floating point x,y,z positions of each vertex in the mesh.
var data_out_vec: PackedVector3Array ##Vectorized version of above.
var counter_out: PackedByteArray ##Counter array. Used to calculate the number of triangles in the mesh
const max_tris_per_voxel : int = 5 ##Constant value due to how marching cubes is done. The most triangles in a single MCube voxel is 5.
var max_triangles : int = max_tris_per_voxel * int(pow(10, 3))*pow(res,3) ##Max triangles = max_tris_per_voxel * (the number of invocations^the number of dimentions) For more info on invocations, see comment ID:02 in the compute shader for more info.
 
const bytes_per_float : int = 4 ##We use 32 bit floats, and there are 8 bits in each byte. 32/8 = 4, therefore 4 bytes per float.


const floats_per_triangle : int = 3 * 4 ##Each triangle has 4 vectors each composed of 3 floats, 3 for each of the verts and 1 for the normal direction.


const bytes_per_triangle : int = floats_per_triangle * bytes_per_float ##number of floats per tri * bytes per float gives us the max amount of a space a triangle can take up in memory
var max_bytes : int = bytes_per_triangle * max_triangles ##max bytes per tri * max tris gives us the max possible size of the mesh. We then use this to set the size of the output buffer to avoid malloc (memory acllocation) errors.

var rd: RenderingDevice ##Local rendering device used for just about everything. You can think of this as a """""virtual GPU""""" (but it's more like a virtual GPU interface)
var shader: RID ##Compiled bytecode of the shader that is run on the GPU.
var pipeline: RID ##Rendering pipeline. Used to execute the shader and other shenanaginry.
var uniform_set: RID ##Used to communicate between the CPU and GPU. 
var output_buffer: RID ##Ref to the output buffer, the GPU writes to this and we read it to get the mesh.
var input_buffer: RID ##Param buffer, stores iso, scale, noise, etc to send to the GPU.
var counter_buffer: RID ##Counter buffer. Stores the number of itterations that occured when generating, used to calculate the # of triangles.
var noisemap_texture_rid: RID ##Noisemap texture buffer. Used to send the 3D noise tex to the GPU.
var noisemap_sampler: RID ##Unused??? I'm too scared to delete it. Probably not necassary.
var is_ready:bool = false ##j-j-j-j-j-jANK (var that stores if we're ready to prevent setters from procing (activating) the mesh regen funcs before the node is ready.)
# Called when the node enters the scene tree for the first time.

func _ready() -> void:
	#await noise.changed
	for i in get_children():
		if i is MeshInstance3D:
			i.mesh = i.mesh.duplicate()
	prep_compute()
	is_ready = true

func prep_compute() -> void: ##Creates ALL the rendering garbage, buffers, SPIR-V, pipeline, etc.
	rd = RenderingServer.create_local_rendering_device() #Extra rendering device we use to run the comp shader
	var shader_file := load("res://ComputeShader/computeMan.glsl") #Load shader file
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv() #Create intermediary SPIR-V code we compile into the bytecode executed by the engine/OS
	shader = rd.shader_create_from_spirv(shader_spirv) #Compile that SPIRV into a usable shader
	var input := PackedFloat32Array([iso,noise_scale.x,noise_scale.y,noise_scale.z,position.x,position.y,position.z]) #Params for the shader
	var input_as_bytes = input.to_byte_array() #Convert data to raw bytes
	input_buffer = rd.storage_buffer_create(input_as_bytes.size(),input_as_bytes) #Create a buffer in the custom rendering device
	var uniform = RDUniform.new() #Make new uniform so we can pass data to the GPU
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER #Set uniform type
	uniform.binding = 0 #Bind uniform, this must be equal to the binding var in the comp shader
	uniform.add_id(input_buffer) #bind the databuffer to the uniform




	output_buffer = rd.storage_buffer_create(max_bytes) #Make the buffer we'll read from
	var output_uniform = RDUniform.new() #uniform
	output_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER #set type
	output_uniform.binding = 1 #binding is 1 matching binding in shader
	output_uniform.add_id(output_buffer) #bind buffer
	
	
	var counter = [0] #don't ask why it's an array I dont fucking know xd
	var counter_bytes = PackedFloat32Array(counter).to_byte_array() #make it into raw bytes in the most scuffed way possible
	counter_buffer = rd.storage_buffer_create(counter_bytes.size(),counter_bytes) #you know the drill by now
	var c_uniform = RDUniform.new() #cross the linedef to spawn extra revenants
	c_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER #grab the megasphere
	c_uniform.binding = 2 #grab the bfg
	c_uniform.add_id(counter_buffer) #grab the supercharge
	#and freaking die
	#https://www.youtube.com/decino
	
	
	var noisemap_format_data := RDTextureFormat.new() #Make a metadata resource to store info on the image we use for the noise
	noisemap_format_data.width = tex_raster.res #width
	noisemap_format_data.height = tex_raster.res #hight
	noisemap_format_data.depth = tex_raster.res #depth
	noisemap_format_data.samples = RenderingDevice.TEXTURE_SAMPLES_1
	
	#These shouldn't be constants, will fix this soon
	noisemap_format_data.texture_type = RenderingDevice.TEXTURE_TYPE_3D #Set flag to treat it as a 3d texture instead of just a big texture
	noisemap_format_data.format = RenderingDevice.DATA_FORMAT_R8_UNORM #Set format to a single chanel, 8-bit normalized luminance map, saving a shit ton of time and memory
	
	noisemap_format_data.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT + RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT #A smidge confusing. This is what is called a bitmask or bitmap or something like that. It's basically a binary number where each number pos repersents a different parameter, which is why we're adding them.
	#In this case, we're saying it can be sampled from ^^^							And it can be updated ^^^
	
	noisemap_texture_rid = rd.texture_create(noisemap_format_data,RDTextureView.new()) #Make the texture for the noise, no data in it yet tho.
	var sampler_state = RDSamplerState.new() #uhhhhhhhh something
	
	noisemap_sampler = rd.sampler_create(sampler_state) #Make a new sampler which is used by the GPU to sample (crazy) data from a texture.
	
	var noisemap_uniform := RDUniform.new() #cross the imp cliff
	noisemap_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE #ooo something different
	noisemap_uniform.binding = 3 #bindings
	noisemap_uniform.add_id(noisemap_sampler) #add both the ids. I don't think we need this one tho.
	noisemap_uniform.add_id(noisemap_texture_rid)
	
	
	
	
	
	
	
	uniform_set = rd.uniform_set_create([uniform,output_uniform,c_uniform,noisemap_uniform],shader,0) #ID:03 Creates the uniform set and sends all them to the gpu. The 0 at the end spesifies the uniform set, matching the set values in the layouts/uniforms in the shader. XD
	
	pipeline = rd.compute_pipeline_create(shader) #Make an instruction set for the GPU to execute



func run_compute() -> void: ##Function to actually generate and build the mesh. Automatically calls process_output().
	if is_ready: #J-J-J-J A N K (preventing it from attempting to generate when not all the resources are loaded)
		for mesh in get_mesh_children():
			data_out_vec.clear() #clear existing data
			data_out.clear()  #clear existing data
			mesh.mesh.clear_surfaces()  #clear existing mesh

			var new_input_buffer = PackedFloat32Array([iso,noise_scale.x,noise_scale.y,noise_scale.z,mesh.position.x,mesh.position.y,mesh.position.z]).to_byte_array() #make new param data
			rd.buffer_update(input_buffer,0,new_input_buffer.size(),new_input_buffer) #Update the existing param buffer w/the new data.
			var c_buffer = PackedFloat32Array([0]).to_byte_array() #reset the counter buffer
			rd.buffer_update(counter_buffer,0,c_buffer.size(),c_buffer)

			rd.texture_update(noisemap_texture_rid,0,get_noise_data()) #Update the noise texture incase it's changed
			var compute_list = rd.compute_list_begin() #Starts "accepting" instructions (any funcs called between this and compute_list_end() are sent to the gpu kinda)
			rd.compute_list_bind_compute_pipeline(compute_list,pipeline) #Binds the compute list to the pipeline, basically the pipeline is the "place" or "person" executing the compute list
			rd.compute_list_bind_uniform_set(compute_list,uniform_set,0) #Bind uniform to the compute list, giving it acsess to the uniform at runtime. ID:03's 3rd arg must match this line's 3rd arg.
			rd.compute_list_dispatch(compute_list,res,res,res) # ID:01 Defines how many instances we want to run (x*y*z, in this case 5). Due to the fact that the shader code spesifies 2 x iterations, we are in reality running 5 instances that each run twice, effectivly running 10 times.
			rd.compute_list_end() #ends the instruction list
			rd.submit() #Send the code to the GPU to execute
			rd.sync() #Syncs the CPU and GPU. Minor preformance impact, try not to do this too much. Causes the CPU to wait for the GPU to finish processing. Generally you want to wait ~2-3 frames before syncing, that way the GPU and CPU can run in parallel.
			
			var output_bytes = rd.buffer_get_data(output_buffer) #Retrive the data from the shader
			var output = output_bytes.to_float32_array() #convert to float32 array from raw bytes
			data_out = output #Store the data
			
			counter_out = rd.buffer_get_data(counter_buffer) #Store counter garbage
			
			#print(str(output))
			process_output(output,mesh) #Process the output!!
		

func process_output(data:PackedFloat32Array,mesh:MeshInstance3D) -> void: ##Takes in a set of ungrouped float coords and turns them into a mesh.
	
	var surf = SurfaceTool.new() #SurfaceTool instance. We use this as it lets us quickly generate normals and indexes and is generally pain-free. Will proably replace soon.
	surf.begin(Mesh.PRIMITIVE_TRIANGLES) #Start the mesh. Required b4 you start adding verts.

	
	var num_tris = counter_out.to_int32_array()[0] #Figure out the number of triangles we need to itterate over
	if !num_tris: #If there's no triangles
		#print("ERROR: num_tris failed to convert") #This is not always the case. This error will also be thrown if the chunk simply has no verts (ie it is empty)
		return #End func to save processing time
	#var num_tris = 3
	for i in range(0,num_tris): #For all of the triangles
		var index = i*16 #Index = i*16, where 16 is the number of indexes each tri takes up.
		#For some ungodly reason, each vec3 in the triangle struct takes up 4 indexes with the last one being a meaningless zero i have NO IDEA why this happens help
		#This results in 4 indexes per vector * 4 vectors per tri = 16 indexes per tri

		var posA = Vector3(data[index + 0], data[index + 1], data[index + 2]) #First position
		var posB = Vector3(data[index + 4], data[index + 5], data[index + 6]) #Second pos, skipping data[index+3] because it's just always a 0
		var posC = Vector3(data[index + 8], data[index + 9], data[index + 10]) #Third pos, skipping data[index+7] because it's just always a 0
		surf.set_normal(Vector3(data[index + 12], data[index + 13], data[index + 14])) #this func sets the normal FOR THE NEXT VERTEX. This results in flat shading, as all vtexes in a face have the same normal.
		surf.add_vertex(posA) #add vtex
		data_out_vec.append(posA) #append to dbg (unused)
		surf.set_normal(Vector3(data[index + 12], data[index + 13], data[index + 14]))
		surf.add_vertex(posB)
		data_out_vec.append(posB)
		surf.set_normal(Vector3(data[index + 12], data[index + 13], data[index + 14]))
		surf.add_vertex(posC)
		data_out_vec.append(posC)
	
	surf.generate_normals()
	surf.index() #attempts to merge identicle verts, but breaks bc they aren't exactly the same. I'll write a custom version soonish.
	surf.commit(mesh.mesh) #Finishes the mesh, automatically updating $MeshInstance3D.mesh

func _notification(type): ##IMPORTANT: Used to free refs to the rendering stuff on deletion. Without this, will result in a ton of memory leaks.
	if type == NOTIFICATION_PREDELETE: #Need this conditon so we don't delete ourself when we recive any notification
		release()

func release() -> void: ##Function that frees the memory of all the RIDs we made and kept track of. Remeber, unlike resources, RIDs don't automatically free themselves.
	rd.free_rid(pipeline)
	rd.free_rid(output_buffer)
	rd.free_rid(input_buffer)
	rd.free_rid(counter_buffer);
	rd.free_rid(shader)
	rd.free_rid(noisemap_texture_rid)
	rd.free_rid(noisemap_sampler)
	pipeline = RID()
	output_buffer = RID()
	input_buffer = RID()
	counter_buffer = RID()
	shader = RID()
	noisemap_texture_rid = RID()
	noisemap_sampler = RID()
		
	rd.free()
	rd= null


func get_noise_data() -> PackedByteArray: ##Grabs the textures from the rastarizer.

	var out: PackedByteArray 
	if tex_raster: #if it even exists
		#for i in noise.get_data():
		for i in tex_raster.images: #for all the images
			out.append_array(i.get_data()) #append their raw bytes to the array, making them into a 3D image
	return out #return it


func get_mesh_children():
	var arr: Array[MeshInstance3D] = []
	for i in get_children():
		if i is MeshInstance3D:
			arr.append(i)
	return arr
