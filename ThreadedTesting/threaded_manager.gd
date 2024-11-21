@tool
extends Node3D
@onready var chunk = preload("res://ThreadedTesting/ThreadedChunk.tscn")
@onready var dbg_outline = preload("res://ThreadedTesting/DebugOutline.tscn")

@export var data: GenerationData:
	set(val):
		data = val
		if !data.changed.is_connected(update_mesh):
			data.changed.connect(update_mesh)
		#if !data.chunkdata_changed.is_connected(make_chunks):
			#data.chunkdata_changed.connect(make_chunks)
			
@export var generate_one: bool = true:
	set(val):
		if isready and made_chunks:
			get_child(randi_range(0,get_child_count()-1)).u()
@export var debug_outlines = false
# Called when the node enters the scene tree for the first time.
var isready = false
var made_chunks = false
var c = 0
func _ready() -> void:
	for i in get_children():
		if i is ThreadedChunk:
			i.PREPARE_TO_DIE()
	isready = true
	#make_chunks()

func update_mesh():
	if isready:
		if data:
			if get_child_count() > 0:
				for i in get_children():
					if i is ThreadedChunk:
						i.u()

func make_chunks():
	for i in get_children():
		if i is ThreadedChunk:
			i.PREPARE_TO_DIE()
	if isready:
		if data:
			for x in range(data.chunks.x):
				for y in range(data.chunks.y):
					for z in range(data.chunks.z):
						var inst:ThreadedChunk = chunk.instantiate()
						add_child(inst)
						inst.owner = self
						inst.position += Vector3(x*data.cubes_per_chunk,y*data.cubes_per_chunk,z*data.cubes_per_chunk)
						inst.init(data)
						if debug_outlines:
							var i2 = dbg_outline.instantiate()
							inst.add_child(i2)
							i2.owner = self
							i2.scale = Vector3(data.cubes_per_chunk,data.cubes_per_chunk,data.cubes_per_chunk)
	made_chunks = true
	
func _exit_tree() -> void:
	for i in get_children():
		if i is ThreadedChunk:
			i.queue_free()

#func _physics_process(delta: float) -> void:
	#if isready and made_chunks:
		#c+= 1
		#if c >= 60:
			#c = 0 
			#get_child(randi_range(0,get_child_count()-1)).u()
