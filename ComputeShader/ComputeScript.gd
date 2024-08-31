@tool
extends Node3D

@export var iso = 1.0:
	set(val):
		iso = val
		run_compute()

@export var cubes = 8
@export var res := 1
@export var data_out: PackedFloat32Array
@export var data_out_vec: PackedVector3Array

const max_tris_per_voxel : int = 5
const max_triangles : int = max_tris_per_voxel * int(pow(1, 3))
const bytes_per_float : int = 4
const floats_per_triangle : int = 3 * 3
const bytes_per_triangle : int = floats_per_triangle * bytes_per_float
const max_bytes : int = bytes_per_triangle * max_triangles

var rd: RenderingDevice
var shader: RID
var pipeline: RID
var uniform_set: RID
var output_buffer
var input_buffer
var counter_buffer

# Called when the node enters the scene tree for the first time.

func _ready() -> void:
	prep_compute()
	

func prep_compute():
	rd = RenderingServer.create_local_rendering_device() #Extra rendering device we use to run the comp shader
	var shader_file := load("res://ComputeShader/computeMan.glsl") #Load shader file
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv() #Create intermediary SPIRV code we compile into the bytecode executed by the engine/OS
	shader = rd.shader_create_from_spirv(shader_spirv) #Compile that SPIRV into a usable shader
	var input := PackedFloat32Array([iso,cubes,res]) #Data
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
	
	
	uniform_set = rd.uniform_set_create([uniform,output_uniform,c_uniform],shader,0) #I think the last param needs to match the set var in the comp shader? idk. This returns an RID we can use to acsess the uniform
	
	pipeline = rd.compute_pipeline_create(shader) #Make an instruction set for the GPU to execute


func run_compute():
	data_out_vec.clear()
	data_out.clear()
	$MeshInstance3D.mesh.clear_surfaces()

	var new_input_buffer = PackedFloat32Array([iso,cubes,res]).to_byte_array()
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
	#print(str(output))
	process_output(output)
	

func process_output(data:PackedFloat32Array):
	var surf = SurfaceTool.new()
	surf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var d2: PackedFloat32Array
	for x in range(data.size()):
		if (!((x+1) % 4) == 0) or x == 0:
			d2.append(data[x])
	print(str(d2.size())) #TODO: For some reason seperating each set of 3 floats there's a zero. No idea why but it's fucking everything up lol.
	for i in range(0,d2.size(),3):
		var l = i
		#if i != 0:
			#l+=1
		var vec = Vector3(d2[l],d2[l+1],d2[l+2])
		surf.add_vertex(vec)
		data_out_vec.append(vec)
	surf.index()
	surf.generate_normals()
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
