extends Node3D
@onready var chunk = preload("res://ThreadedTesting/ThreadedChunk.tscn")
@onready var dbg_outline = preload("res://ThreadedTesting/DebugOutline.tscn")
@export var debug = true
@export var chunk_size: int = 8
@export var localized_size: int = 4
@export var data: GenerationData
@onready var player: Player = $PlayerMark2
@onready var chunk_container = $Node3D
var last_updated_pos = Vector3.ZERO
var player_chunk = Vector3i.ZERO:
	get():
		return round_position_to(player.global_position)
var chunk_dict: Dictionary
var c_dict_size: int:
	get():
		return chunk_dict.size()
func _ready() -> void:
	DebugOverlay.add_new_property(self,"player_chunk","Player Chunk: ")
	DebugOverlay.add_new_property(self,"c_dict_size","Chunks Total: ")

	last_updated_pos = player.global_position
	#for x in range(-localized_size/2,localized_size-1):
		#for y in range(-localized_size/2,localized_size-1):
			#for z in range(-localized_size/2,localized_size-1):
				#var inst = dbg_outline.instantiate()
				#chunk_container.add_child(inst)
				#inst.owner = self
				##inst.scale = Vector3(chunk_size,chunk_size,chunk_size)
				#inst.position = Vector3(x,y,z)*chunk_size
				#chunk_dict[var_to_str(Vector3(x,y,z)*chunk_size)] = inst
				#inst.init(data)
				#inst.u()
	
func round_position_to(pos:Vector3):
	return round((pos-Vector3(chunk_size,chunk_size,chunk_size)/2)/chunk_size)


func _physics_process(delta: float) -> void:
	if last_updated_pos != player_chunk:
		update_chunks()
	last_updated_pos = player_chunk
func update_chunks():
	#for i in chunk_container.get_children():
		#if i.global_position.distance_to(player.global_position) >= chunk_size:
			#i.queue_free()
	@warning_ignore("integer_division")
	for x in range(player_chunk.x-localized_size/2,player_chunk.x+localized_size-1):
		@warning_ignore("integer_division")
		for y in range(player_chunk.y-localized_size/2,player_chunk.y+localized_size-1):
			@warning_ignore("integer_division")
			for z in range(player_chunk.z-localized_size/2,player_chunk.z+localized_size-1):
				var c_pos = Vector3(x,y,z)*chunk_size
				if !chunk_dict.has(var_to_str(c_pos)):
					var inst
					if debug:
						inst = dbg_outline.instantiate()
					else:
						inst = chunk.instantiate()
					chunk_container.add_child(inst)
					inst.owner = self
					if debug:
						inst.scale = Vector3(chunk_size,chunk_size,chunk_size)
					inst.position = Vector3(x,y,z)*chunk_size
					chunk_dict[var_to_str(Vector3(x,y,z)*chunk_size)] = inst
					if !debug:
						inst.init(data)
						inst.u()
						print("update")

	cull_distant_chunks()
			
func cull_distant_chunks():
	var chunks_to_erase: Array[String]
	for i in chunk_dict:
		#print("itterate")
		#var pain = player_chunk*chunk_size
		#var pain2 = str_to_var(i).distance_to(player_chunk*chunk_size)
		if str_to_var(i).distance_to(player_chunk*chunk_size) > localized_size*chunk_size:
			var t = chunk_dict[i]
			chunks_to_erase.append(i)
			t.queue_free()
			#print("Erased")
	for i in chunks_to_erase:
		chunk_dict.erase(i)
