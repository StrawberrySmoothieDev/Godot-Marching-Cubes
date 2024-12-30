
@icon("res://Icons/MarchingCubesChunkIcon.svg")
extends Node3D
class_name ThreadedChunker
##Main script that manages marching cube chunk creation.
#TODO: Set up lazy chunk loading that prioritizes chunks we can see
const CHUNK_SCENE: PackedScene = preload("res://addons/UltimateMarchingCubes/Scenes/ThreadedChunk.tscn") ##ThreadedChunk
const DEBUG_OUTLINE_SCENE: PackedScene = preload("res://addons/UltimateMarchingCubes/Scenes/DebugOutline.tscn") ##Debug thing
@export var debug:bool = true ##Weather to generate debug outlines instead of chunks
@export var skip_NPT:bool = false ##Weather to skip the 9-point test. Useful for small worlds and noise algorithem testing.
@export var ignore_priority:bool = false ##Weather to ignore priority checks for chunks. Makes all chunks max priority, used for debug.
@export var clear:bool = false: ##Debug var to clear and regen all chunks. Meant to test generation paramaters in editor.
	set(val):
		if chunk_container.get_child_count() > 0:
			for i in chunk_container.get_children():
				i.queue_free()
			chunk_dict.clear()
			lazy_chunk_queue.clear()
			update_chunks()
@export var localized_size: int = 4 ##Render distance. Higher values are much slower, be warned.
@export var deletion_distance_bias: float = 2.0 ##Bias we use to allow chunks to exist further away w/o being deleted.
@export var data: GenerationData ##Data resource used for generation.
@export var lazy_chunking_enabled: bool = true
@export var lazy_chunking_modifer: int = 1 ##The rate at which we lazychunk. Higher values are slower and more performant.
@export var dist_influance:float = 1.0 ##How much distance will influance chunk generation priority.
@export var view_influance:float = 1.0 ##How much view angle will influance chunk priority.
@export var behind_influance:float = 1.0 ##How much a chunk that is behind the camera will have its priority reduced. Recommended to have this fairly high.
var last_updated_pos:Vector3 = Vector3.ZERO ##Last chunk position of player.
var player_chunk:Vector3 = Vector3i.ZERO: ##Current player chunk position
	get():
		return round_position_to(player.global_position)
var chunk_dict: Dictionary ##Dictionary with all active chunks. Keys are world positional coords, values are refs to the chunks
var c_dict_size: int: ##Size of chunk dict. Used for debug.
	get():
		return chunk_dict.size()
var chunk_size: int: ##Amount of voxels per chunk. Redundant with GenerationData.cubes_per_chunk.
	get():
		if data:
			return data.cubes_per_chunk
		else:
			return 4
var lazy_chunk_queue: Dictionary ##Queue of chunks to be lazyloaded, keyed by priority.
var global_presampled_points_dict: Dictionary ##Deprecated. Meant as a global dict of all sampled noise points, caused issues when multithreading was fixed to actually work.
@onready var player: Player = $PlayerMark3 ##Player ref. TODO: Make this arbitarary and based off of a component
@onready var chunk_container:Node3D = $Node3D ##Parent of all chunks


func _ready() -> void:
	DebugOverlay.add_new_property(self,"player_chunk","Player Chunk: ") #Debug.
	DebugOverlay.add_new_property(self,"c_dict_size","Chunks Total: ")
	if chunk_container.get_child_count() > 0: #Clear existing chunks on start
		for i in chunk_container.get_children():
			i.queue_free()
	chunk_dict.clear() #more clearing
	lazy_chunk_queue.clear() #guess what
	last_updated_pos = player.global_position #reset pos

func round_position_to(pos:Vector3) -> Vector3: ##Rounds a global position to a chunk grid position. Not used for much atm.
	return round((pos-Vector3(chunk_size,chunk_size,chunk_size)/2)/chunk_size) 


func _physics_process(delta: float) -> void:
	if last_updated_pos != player_chunk: #If the player is in a different chunk
		update_chunks() #Recheck all chunks (SLOW)
	if lazy_chunking_enabled:
		run_lazy_chunks() #Also run any lazy chunks we have queued 
	last_updated_pos = player_chunk #Update pos
func update_chunks() -> void: ##Checks all chunks in render dist of player, weather or not they exist. Very slow, but important. This recursion is the main reason why larger chunks with smaller localized_size is more performant.
	lazy_chunk_queue.clear() #Clear the chunk queue so we can provide most up-to-date priority info
	var adjusted_player_chunk = player_chunk + round_position_to(player.velocity)
	#make_chunk(adjusted_player_chunk*chunk_size,true,true)
	@warning_ignore("integer_division") #scuffed. suppresses a warning that is rlly easy to fix but I'm lazy.
	for x in range(adjusted_player_chunk.x-localized_size/2,adjusted_player_chunk.x+localized_size/2): #All these for loops are itterating over all chunks in our render distances, WEATHER OR NOT THEY EXIST.
		@warning_ignore("integer_division")
		for y in range(adjusted_player_chunk.y-localized_size/2,adjusted_player_chunk.y+localized_size/2):
			@warning_ignore("integer_division")
			for z in range(adjusted_player_chunk.z-localized_size/2,adjusted_player_chunk.z+localized_size/2):
				
				var c_pos = Vector3(x+1,y+1,z+1)*chunk_size #World pos of the chunk we're checking. Needs a little fudge due to coordinet jank.
				if !chunk_dict.has(var_to_str(c_pos)): #If that world pos is found in the chunk dict
					if nine_point_test(c_pos): #Run NPT to check if there will be any mesh in the chunk
						if lazy_chunking_enabled:
							lazy_chunk_queue[c_pos] = get_chunk_priority(c_pos) #Assign to lazy chunk queue TODO: Set up a non-lazy loader alternative
						else:
							call_deferred("make_chunk",c_pos)
	cull_distant_chunks() #Cull distant chunks
			
func cull_distant_chunks() -> void: ##Checks for any chunks out of range of the player. Also very slow, could use a rework. Possibly send a signal to chunks when they exit a certain dist? idk
	var chunks_to_erase: Array[String] #Array of chunks we need to erase, can't do while we're itterating, otherwise will cause issues i think? TODO Test this
	for i in chunk_dict: #For all chunks
		if (str_to_var(i)).distance_to(player_chunk*chunk_size) > localized_size*chunk_size*deletion_distance_bias: #If its distance to our rounded global player pos is more than the global render dist (render dist * chunk size)
			var t = chunk_dict[i] #Temp var
			chunks_to_erase.append(i) #append to chunks to erase
			t.PREPARE_TO_DIE() #call PTD on chunk and let it lowtiergod itself to prevent thread shenanagins
	for i in chunks_to_erase: #For all chunks to erase
		chunk_dict.erase(i) #erase (who'da thought)

func nine_point_test(pos:Vector3) -> bool: ##Function to test if a chunk will have any mesh in it. Does this by sampling the 8 corners and the center and testing if they're all inside or outside the mesh. If so, there's (in theory) nothing in that chunk and we can skip it. TODO: Figure out a fix for this. Very prone to false positives.
	if skip_NPT:
		return true
	var pos2 = pos+position #scuffed global pos test. CRITICAL: THIS MIGHT NOT WORK IF NOT CENTERED ON ORIGIN. NEEDS TESTING.
	var inside = -1 #Should all points be inside or outside
	var mid = data.cubes_per_chunk/2.0 #Guh? We have a get_chunk_center func lol
	var mvec = Vector3(mid,mid,mid) #Middle of chunk
	var center_sample = remap(data.get_noise(pos2+mvec),0.0,1.0,-1.0,1.0) #Sample center
	inside = int(center_sample < data.iso) #Set inside, therefore if center is inside, then any outside samples on the corners will succede the NPT
	for i in MarchingCubesLibrary.NPT_OFFSETS_VECTOR: #For all the vectorized corner offsets
		var sample = remap(data.get_noise((pos2+Vector3(i*data.cubes_per_chunk))),0.0,1.0,-1.0,1.0) #Sample the corner and remap it to -1,1, same as mcube system
		var is_inside:bool = sample < data.iso #If inside
		if int(is_inside) != inside: #If point is not the same i/o as center, check passes
			return true
	return false #Otherwise check fails


func make_chunk(pos:Vector3,force_dbg:bool = false,empty:bool = false) -> Node3D: ##Creates a chunk at the spesified location. Force DBG creates a debug chunk, and empty skips the calling of chunk.u().

	var inst #Inst
	if debug or force_dbg:
		inst = DEBUG_OUTLINE_SCENE.instantiate() #If debugging inst = debug chunk
	else:
		inst = CHUNK_SCENE.instantiate() #otherwise normal chunk
	chunk_container.add_child(inst) #add as child to chunk container
	inst.owner = self #set owner so we can see it in editor scene tree for debugging
	inst.initalize(self) #initalize TODO: Fix redundancies with suffering temp vars
	if debug or force_dbg: #Debug chunks need to be scaled
		inst.scale = Vector3(chunk_size,chunk_size,chunk_size)
		
		#inst.set_priority(get_chunk_priority(pos))
		
	inst.position = pos #set pos
	chunk_dict[var_to_str(pos)] = inst #Save to chunk dict
	if !debug and !force_dbg: #If not a debug chunk
		inst.init(data) #Another init WHAT FIXME
		if !empty:
			inst.u() #If not empty, gen mesh
	return inst #Return chunk
func run_lazy_chunks() -> void: ##Generates queued chunks every X frames, ie a lazy_chunking_modifer of 2 generates a chunk every 2 frames, 1 every frame, 4 every 4 frames, etc.
	
	if lazy_chunk_queue.size() > 0 and Engine.get_frames_drawn() % lazy_chunking_modifer == 0: #If there's chunks in the queue and this is a frame where we want to make a chunk
		var four = lazy_chunk_queue.find_key(4) #HACK kinda. This whole mess is scuffed. First we check if there's any priority 4's, gen them, 3s, 2s, 1s, etc.
		if four!= null: #If there's a priority 4
			
			lazy_chunk_queue.erase(four) #erase from lazy chunk queue
			call_deferred("make_chunk",four) #make the chunk
			return #End lazy chunking for this frame
		var three = lazy_chunk_queue.find_key(3)
		if three!= null:
			lazy_chunk_queue.erase(three)
			call_deferred("make_chunk",three)
			return
		var two = lazy_chunk_queue.find_key(2)
		if two!= null:
			lazy_chunk_queue.erase(two)
			call_deferred("make_chunk",two)
			return
		var one = lazy_chunk_queue.find_key(1)
		if one!= null:
			lazy_chunk_queue.erase(one)
			call_deferred("make_chunk",one)
			return
		var zero = lazy_chunk_queue.find_key(0)
		if zero!= null:
			lazy_chunk_queue.erase(zero)
			call_deferred("make_chunk",zero)
			return

func get_chunk_priority(pos:Vector3) -> int: ##Returns the priority of a chunk position. Used to gauge weather it should be generated sooner or later. Based on position, view dir, and location relative to cam.
	if Engine.is_editor_hint() or ignore_priority: #If in editor, skip all this as player cannot be a tool script
		return 4
	var dist = pos.distance_to(player.global_position) #Get base dist to player
	var map = remap(dist,80,20,0,1)*dist_influance #Remap from 20m-80m to 0-1 (<0 = 80+ meters away, >1 = 20 or less meters away) Effectivly reverses it, where closer is a higher value
	var dir = player.camera.global_position.direction_to(get_chunk_center(pos)) # Dir to center of chunk from camera
	var dot = dir.dot(-player.camera.global_transform.basis.z)*view_influance #Dot product of dirto and forward vector of camera, times view influance
	var behind_mod = int(player.camera.is_position_behind(get_chunk_center(pos)))*behind_influance/dist #Additional mod that makes us prioritize chunks that are behind us, with a little fudge to make sure chunks really close by still get generated
	return int(clamp(round(map+dot-behind_mod),0,4)) #Clamp and round the final value, loses some percision but saves a massive amount of processing time

func get_chunk_center(opos: Vector3) -> Vector3: ## Self explanatory. Gets the center of a chunk from its origin pos, as by default they are unit cubes. TODO: Test to make sure this actually works. Get the feeling it's a lil scuffed.
	var offset = Vector3(chunk_size,chunk_size,chunk_size)/2
	return opos+offset

func terraform(col:ThreadedChunk,pos:Vector3,digging:bool) -> void: ##Function to terraform terrain. Deprecated as of now, while I work on fixing its issues with multithreading
	var adjacents = cube_dist_diff(get_chunk_center(col.global_position),pos) #Fancy math used to find the closest 7 chunks we need to regen
	#for p in col.presampled_points: #For all of the presampled points in the home chunk (the chunk we clicked on)'s saved points
		#if p.distance_to(pos) < 4.0: #if close enough
			#if digging:
				#global_presampled_points_dict[p] += 5 #increase the global point dicts values at that point WARNING: This is scuffed. While it means we won't have seams, it will cause unusual effects as only points in the home chunk will be modified. Needs a full rework.
			#else:
				#global_presampled_points_dict[p] -= 5
	#for i in adjacents:
		#if chunk_dict.get(var_to_str(col.global_position + i*chunk_size)):
			#if chunk_dict.get(var_to_str(col.global_position + i*chunk_size)).thread.is_alive():
				#return
	for i in adjacents: #For all adjacents
		var l = col.global_position + i*chunk_size #I'm not even documenting this. It's scuffed as hell and barely functional, and I'll be replacing it soon.
		var f = chunk_dict.get(var_to_str(l))
		if f:
			for p in f.presampled_points:
				if p.distance_to(pos) < 4.0:
					if digging:
						f.presampled_points[p] += 10
					else:
						f.presampled_points[p] -= 10
			#f.mesh.clear_surfaces()
			
			if !f.thread.is_alive():
				#f.thread.wait_to_finish()
				#print("worked")
				f.u()
			#var a = f.update_mesh(false)
			#f.gen_mesh(a)
		else:
			var new_chunk = make_chunk(l,false,true)
			new_chunk.u()
			new_chunk.thread.wait_to_finish()
			for p in new_chunk.presampled_points:
				if p.distance_to(pos) < 4.0:
					if digging:
						new_chunk.presampled_points[p] += 10
					else:
						new_chunk.presampled_points[p] -= 10
			if !new_chunk.thread.is_alive():
				new_chunk.u()
			#new_chunk.mesh.clear_surfaces()
			#var a = new_chunk.update_mesh(false)
			#new_chunk.gen_mesh(a)
			
			
	
	#var l = col.global_position + Vector3(0,0,chunk_size)
	#var f = chunk_dict[var_to_str(l)]
	#var l2 = col.global_position - Vector3(0,0,chunk_size)
	#var f2 = chunk_dict[var_to_str(l2)]
	#f.toggle_DBG()
	#f2.toggle_DBG()


	
	
func cube_dist(center: Vector3,pos: Vector3) -> float: ##The horrer. This function returns the CUBIC to the center of a cube. Basically what that means is it will be a 4 at any face or edge. 
	var x = min(abs(pos.x-center.x),abs(pos.x+center.x)) #terror.
	var y = min(abs(pos.y-center.y),abs(pos.y+center.y)) #fear.
	var z = min(abs(pos.z-center.z),abs(pos.z+center.z)) #JUDGEMENT
	return max(x,y,z)


func cube_dist_diff(center: Vector3,pos: Vector3) -> PackedVector3Array: ##Even more disgusting function. Basically what it does is finds the faces on each axis that a point is closest to, finds the chunks that share those faces (as well as the diagonals) and returns them. This allows us to figure out what we need to regen if we click on a corner.
	var x = sign(min_signed(pos.x,center.x)) #I don't even want to think about this. The scariest thing is that it works pretty well
	var y = sign(min_signed(pos.y,center.y))
	var z = sign(min_signed(pos.z,center.z))

	return PackedVector3Array([Vector3(0,0,0),Vector3(x,0,0),
	Vector3(0,y,0),
	Vector3(0,0,z),
	Vector3(x,y,z),
	Vector3(0,y,z),
	Vector3(x,0,z)])

func min_signed(posx:float,centerx:float) -> float: ##Signed minimum subtraction function. Finds weather x+y or x-y is FURTHER FROM ZERO and returns the it, signed. Yikes.
	var pxm = posx-centerx
	var pxa = posx+centerx
	if abs(pxm) < abs(pxa):
		return pxm
	elif abs(pxm) > abs(pxa):
		return pxa
	else:
		return min(pxa,pxm)
