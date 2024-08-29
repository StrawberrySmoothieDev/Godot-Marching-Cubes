extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready():
	var rd := RenderingServer.create_local_rendering_device() #Extra rendering device we use to run the comp shader
	var shader_file := load("res://Testing.glsl") #Load shader file
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv() #Create intermediary SPIRV code we compile into the bytecode executed by the engine/OS
	var shader := rd.shader_create_from_spirv(shader_spirv) #Compile that SPIRV into a usable shader
	var input := PackedFloat32Array([1,0,0,0,0,0,0,0,0,0]) #Data
	var input_as_bytes = input.to_byte_array() #Convert data to raw bytes
	var buffer = rd.storage_buffer_create(input_as_bytes.size(),input_as_bytes) #Create a buffer in the custom rendering device
	var uniform = RDUniform.new() #Make new uniform so we can pass data to the GPU 
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER #Set uniform type
	uniform.binding = 0 #Bind uniform, this must be equal to the binding var in the comp shader
	uniform.add_id(buffer)
	var uniform_set := rd.uniform_set_create([uniform],shader,0) #I think the last param needs to match the set var in the comp shader? idk. This returns an RID we can use to acsess the uniform
	
	var pipeline = rd.compute_pipeline_create(shader) #Make an instruction set for the GPU to execute
	var compute_list = rd.compute_list_begin() #Starts "accepting" instructions (any funcs called between this and compute_list_end() are sent to the gpu kinda)
	rd.compute_list_bind_compute_pipeline(compute_list,pipeline) #Binds the compute list to the pipeline, basically the pipeline is the "place" or "person" executing the compute list
	rd.compute_list_bind_uniform_set(compute_list,uniform_set,0) #Bind uniform to the compute list, giving it acsess to the uniform at runtime. L17's 3rd arg must match this line's 3rd arg.
	rd.compute_list_dispatch(compute_list,5,1,1) #Defines how many instances we want to run (x*y*z, in this case 5). Due to the fact that the shader code spesifies 2 x iterations, we are in reality running 5 instances that each run twice, effectivly running 10 times.
	rd.compute_list_end() #ends the instruction list
	rd.submit() #Send the code to the GPU to execute
	rd.sync() #Syncs the CPU and GPU. Minor preformance impact, try not to do this too much. Causes the CPU to wait for the GPU to finish processing. Generally you want to wait ~2-3 frames before syncing, that way the GPU and CPU can run in parallel.
	
	var output_bytes = rd.buffer_get_data(buffer) #Retrive newly multiplied bytes
	var output = output_bytes.to_float32_array() #convert to float32 array from raw bytes
	print("Input: ", str(input))
	print("Output: ", str(output))
	
	
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
