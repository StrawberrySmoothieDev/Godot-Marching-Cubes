extends Resource
class_name BufferData
@export var input: Array
@export var uniform_type: RenderingDevice.UniformType = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
@export var binding: int
var buffer: RID
var uniform: RDUniform
var rd: RenderingDevice
func get_uniform(rdi:RenderingDevice,size = null):
	rd = rdi
	var max_size
	if size:
		max_size = size
	else:
		max_size = PackedByteArray(input).size()
	buffer = rd.storage_buffer_create(max_size)
	uniform = RDUniform.new()
	uniform.uniform_type = self.uniform_type
	uniform.binding = self.binding
	uniform.add_id(buffer)
	return [buffer,uniform]


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE: #Need this conditon so we don't delete ourself when we recive any notification
		release()
		
func release():
	rd.free_rid(buffer)
	uniform = null
