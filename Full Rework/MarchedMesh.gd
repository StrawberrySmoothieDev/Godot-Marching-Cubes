@tool
extends MeshInstance3D
class_name MarchedMesh
@export var saved_point_data: ImageTexture3D
func _ready() -> void:
	var inst = ImageTexture3D.new()
	var arr = []
	for i in range(8):
		var d: PackedByteArray
		
		d.resize(pow(8,2))
		d.fill(32)
		var im2 = Image.create_from_data(8,8,false,Image.FORMAT_R8,d)
		arr.append(im2)
	inst.create(Image.FORMAT_R8,8,8,8,false,arr)
	saved_point_data= inst
func mesh_ready():
	if !Engine.is_editor_hint():
		var inst = StaticBody3D.new()
		add_child(inst)
		var inst2 = CollisionShape3D.new()
		inst.add_child(inst2)
		inst2.shape = mesh.create_trimesh_shape()


func get_image_data():
	var out: PackedByteArray
	if saved_point_data:
		for i in saved_point_data.get_data():
			out.append_array(i.get_data())
	return out
