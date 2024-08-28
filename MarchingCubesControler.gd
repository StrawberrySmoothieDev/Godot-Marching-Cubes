@tool
extends Node3D
var point_set: Array[BitMap]
@export var resolution: int = 4
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for i in get_children():
		if i:
			i.queue_free()
	for y in range(resolution):
		var bmap = BitMap.new()
		bmap.resize(Vector2i(resolution,resolution))
		point_set.append(bmap)
		var layer = make_layer_owner(y)
		layer.position.y += y
		populate_layer(layer,bmap)


func make_layer_owner(layer):
	var inst = Node3D.new()
	add_child(inst)
	inst.name = "BitLayer "+ str(layer)
	inst.owner =self
	return inst

func populate_layer(layer:Node3D,bitmap:BitMap):
	for x in range(bitmap.get_size().x):
		for y in range(bitmap.get_size().y):
			new_marker(layer,Vector2i(x,y))

func new_marker(layer:Node3D,pos:Vector2i):
	var inst = Marker3D.new()
	layer.add_child(inst)
	inst.name = "Marker (" +str(pos)+ ")"
	inst.position = Vector3(pos.x,0,pos.y)
	inst.owner = self
	return inst
