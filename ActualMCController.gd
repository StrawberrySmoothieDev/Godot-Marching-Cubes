#@tool
extends Node3D
@onready var chunk = preload("res://MeshTest/MeshTest.tscn")
@export var data: GenerationData:
	set(val):
		data = val
		if !data.changed.is_connected(update_mesh):
			data.changed.connect(update_mesh)
		if !data.chunkdata_changed.is_connected(make_chunks):
			data.chunkdata_changed.connect(make_chunks)
			

# Called when the node enters the scene tree for the first time.
var isready = false
func _ready() -> void:
	for i in get_children():
		if i is MarchedCube:
			i.PREPARE_TO_DIE()
	isready = true
	make_chunks()

func update_mesh():
	if isready:
		if data:
			print("u")
			for i in get_children():
				if i is MarchedCube:
					i.update_mesh(data)

func make_chunks():
	for i in get_children():
		if i is MarchedCube:
			i.PREPARE_TO_DIE()
	if isready:
		if data:
			for x in range(data.chunks.x):
				for y in range(data.chunks.y):
					for z in range(data.chunks.z):
						var inst:MarchedCube = chunk.instantiate()
						add_child(inst)
						inst.owner = self
						inst.position += Vector3(x*data.cubes_per_chunk,y*data.cubes_per_chunk,z*data.cubes_per_chunk)
	
func _exit_tree() -> void:
	for i in get_children():
		if i is MarchedCube:
			i.queue_free()
