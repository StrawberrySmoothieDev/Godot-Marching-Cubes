@tool
extends Node3D

@export var iso = 1.0:
	set(val):
		iso = val
		run_compute()

@export var res := 1
@export var sphere_pos: Vector3 = Vector3.ZERO:
	set(val):
		sphere_pos = val
		run_compute()
@export var noise: NoiseTexture3D
var data_out: PackedFloat32Array
var data_out_vec: PackedVector3Array
var counter_out: PackedByteArray
const max_tris_per_voxel : int = 5
const max_triangles : int = max_tris_per_voxel * int(pow(10, 3))
const bytes_per_float : int = 4
const floats_per_triangle : int = 3 * 4
const bytes_per_triangle : int = floats_per_triangle * bytes_per_float
const max_bytes : int = bytes_per_triangle * max_triangles

var rd: RenderingDevice
var shader: RID
var pipeline: RID
var uniform_set: RID
var output_buffer: RID
var input_buffer: RID
var counter_buffer: RID
var noise_buffer: RID
var is_ready = false
# Called when the node enters the scene tree for the first time.

func _ready() -> void:
	prep_compute()
	is_ready = true

func prep_compute():
	rd = RenderingServer.create_local_rendering_device() #Extra rendering device we use to run the comp shader
	var shader_file := load("res://ComputeShader/computeMan.glsl") #Load shader file
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv() #Create intermediary SPIRV code we compile into the bytecode executed by the engine/OS
	shader = rd.shader_create_from_spirv(shader_spirv) #Compile that SPIRV into a usable shader
	var input := PackedFloat32Array([iso,sphere_pos.x,sphere_pos.y,sphere_pos.z]) #Data
	var input_as_bytes = input.to_byte_array() #Convert data to raw bytes
	input_buffer = rd.storage_buffer_create(input_as_bytes.size(),input_as_bytes) #Create a buffer in the custom rendering device
	var uniform = RDUniform.new() #Make new uniform so we can pass data to the GPU 
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER #Set uniform type
	uniform.binding = 0 #Bind uniform, this must be equal to the binding var in the comp shader
	uniform.add_id(input_buffer)




	output_buffer = rd.storage_buffer_create(max_bytes)
	var output_uniform = RDUniform.new()
	output_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	output_uniform.binding = 1
	output_uniform.add_id(output_buffer)
	
	
	var counter = [0]
	var counter_bytes = PackedFloat32Array(counter).to_byte_array()
	counter_buffer = rd.storage_buffer_create(counter_bytes.size(),counter_bytes)
	var c_uniform = RDUniform.new()
	c_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	c_uniform.binding = 2
	c_uniform.add_id(counter_buffer)
	
	var format_data = RDTextureFormat.new() #Data on the actual texture 
	format_data.width = noise.width #yippee
	format_data.height = noise.height #yippeeeeeeeeeeeee
	format_data.depth = noise.depth #yipppeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
	format_data.usage_bits = RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT #idk what this is but uhhhhhhhhhhhhhhh xd (Tutorial here: https://forum.godotengine.org/t/compute-shader-sampler3d-uniform/4459)
	format_data.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_SRGB #setting formats, TODO figure out how to make the shader accept lum8 maps as they only store one int per pixel instead of 4
	
	var image_data = PackedByteArray(noise.get_data()) #Convert the 3d texture to bytes
	var tex = rd.texture_create(format_data,RDTextureView.new(),[noise.get_data()]) #
	var sampler_state = RDSamplerState.new()
	#sampler_state.unnormalized_uvw =
	var sampler_final = rd.sampler_create(sampler_state)
	
	var tex_uni = RDUniform.new()
	tex_uni.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	tex_uni.binding = 3
	tex_uni.add_id(sampler_final)
	tex_uni.add_id(tex)
	uniform_set = rd.uniform_set_create([uniform,output_uniform,c_uniform],shader,0) #I think the last param needs to match the set var in the comp shader? idk. This returns an RID we can use to acsess the uniform
	
	pipeline = rd.compute_pipeline_create(shader) #Make an instruction set for the GPU to execute



func run_compute():
	if is_ready:
		data_out_vec.clear()
		data_out.clear()
		$MeshInstance3D.mesh.clear_surfaces()

		var new_input_buffer = PackedFloat32Array([iso,sphere_pos.x,sphere_pos.y,sphere_pos.z]).to_byte_array()
		rd.buffer_update(input_buffer,0,new_input_buffer.size(),new_input_buffer)
		var c_buffer = PackedFloat32Array([0]).to_byte_array()
		rd.buffer_update(counter_buffer,0,c_buffer.size(),c_buffer)

		var compute_list = rd.compute_list_begin() #Starts "accepting" instructions (any funcs called between this and compute_list_end() are sent to the gpu kinda)
		rd.compute_list_bind_compute_pipeline(compute_list,pipeline) #Binds the compute list to the pipeline, basically the pipeline is the "place" or "person" executing the compute list
		rd.compute_list_bind_uniform_set(compute_list,uniform_set,0) #Bind uniform to the compute list, giving it acsess to the uniform at runtime. L17's 3rd arg must match this line's 3rd arg.
		rd.compute_list_dispatch(compute_list,res,res,res) #Defines how many instances we want to run (x*y*z, in this case 5). Due to the fact that the shader code spesifies 2 x iterations, we are in reality running 5 instances that each run twice, effectivly running 10 times.
		rd.compute_list_end() #ends the instruction list
		rd.submit() #Send the code to the GPU to execute
		rd.sync() #Syncs the CPU and GPU. Minor preformance impact, try not to do this too much. Causes the CPU to wait for the GPU to finish processing. Generally you want to wait ~2-3 frames before syncing, that way the GPU and CPU can run in parallel.
		
		var output_bytes = rd.buffer_get_data(output_buffer) #Retrive newly multiplied bytes
		var output = output_bytes.to_float32_array() #convert to float32 array from raw bytes
		data_out = output
		
		counter_out = rd.buffer_get_data(counter_buffer)
		
		#print(str(output))
		process_output(output)
		

func process_output(data:PackedFloat32Array):
	
	var surf = SurfaceTool.new()
	surf.begin(Mesh.PRIMITIVE_TRIANGLES)
	#var d2: PackedFloat32Array
	#for x in range(data.size()):
		#if (!((x+1) % 4) == 0) or x == 0:
			#d2.append(data[x])
	#print(str(d2.size())) #TODO: For some reason seperating each set of 3 floats there's a zero. No idea why but it's fucking everything up lol.
	
	var num_tris = counter_out.to_int32_array()[0]
	if !num_tris:
		print("ERROR: num_tris failed to convert")
		return
	#var num_tris = 3
	for i in range(0,num_tris):
		var index = i*16
		var l = i
		#if i != 0:
			#l+=1
		var posA = Vector3(data[index + 0], data[index + 1], data[index + 2])
		var posB = Vector3(data[index + 4], data[index + 5], data[index + 6])
		var posC = Vector3(data[index + 8], data[index + 9], data[index + 10])
		surf.set_normal(Vector3(data[index + 12], data[index + 13], data[index + 14]))
		surf.add_vertex(posA)
		data_out_vec.append(posA)
		surf.set_normal(Vector3(data[index + 12], data[index + 13], data[index + 14]))
		surf.add_vertex(posB)
		data_out_vec.append(posB)
		surf.set_normal(Vector3(data[index + 12], data[index + 13], data[index + 14]))
		surf.add_vertex(posC)
		data_out_vec.append(posC)
	
	#surf.generate_normals()
	surf.index()
	surf.commit($MeshInstance3D.mesh)

func _notification(type):
	if type == NOTIFICATION_PREDELETE:
		release()

func release():
	rd.free_rid(pipeline)
	rd.free_rid(output_buffer)
	rd.free_rid(input_buffer)
	rd.free_rid(counter_buffer);
	rd.free_rid(shader)
	
	pipeline = RID()
	output_buffer = RID()
	input_buffer = RID()
	counter_buffer = RID()
	shader = RID()
		
	rd.free()
	rd= null
