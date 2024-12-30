
extends CharacterBody3D
#TODO Redo the movement code
class_name Player
@export_category("Movement Variables")
@export var base_speed: float = 15.0
@export var sprinting_speed: float = 25.0
@export var jump_force: float = 8.0
@export var jump_count = 2
@export var gravity_multiplier = 1.0
@export_category("Physics Pickup Variables")
@export var hold_power: float = 400.0
@export var throw_power: float = 10.0
@export var hold_rot_lock_power: float = 10.0
@export_category("Misc. Options")
@export var mouse_sensitivity: float = 0.1
@export var smooth_up_dir_threshold: float = 0.5
@export var smooth_up_dir_snap_level: float = 0.05

@export_category("Movement Sway Variables")
@export var cam_rotation_amount : float = 1
@export var cam_rotation_max : float = 4
@export var weapon_sway_amount : float = 5
@export var weapon_rotation_amount : float = 1
@export var invert_weapon_sway : bool = false
var base_mouse_sense: float = 0.1
@onready var camera: Camera3D = $Camera
@onready var look_checker:RayCast3D = $Camera/CrosshairChecker
@onready var flashlight = $Camera/SpotLight3D
@onready var phys_checker = $Camera/Area3D


@onready var def_crosshair: TextureRect = $MainUILayer/Control/DefCrosshair
@onready var hold_crosshair: TextureRect = $MainUILayer/Control/HoldCrosshair
@onready var highlights_ui_layer: CanvasLayer = $HighlightsLayer
var def_weapon_manager_pos: Vector3
var current_gravity: Vector3 = Vector3.DOWN*9.8
var current_grav_dir: Vector3 = Vector3.DOWN
var mouse_input: Vector2
var is_zoomed = false
var holding_control
var deploying_item = false
var held_physics_object: RigidBody3D
var is_sprinting = false
var input_disable = false
var col_disabled = false
var gravity_correct = true
var free_vert_movement = false
var frozen = false

var last_frame_up_dir = Vector3.UP
var lerping_up = false
var digging = false
func _ready() -> void:
	base_mouse_sense = mouse_sensitivity
	look_checker.add_exception(self)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	pass
func _physics_process(_delta: float) -> void: #this is where the magic happens uwu
	update_gravity_direction()
	if gravity_correct:
		if lerping_up:
			print(str(1-last_frame_up_dir.dot(-get_gravity().normalized())))
			if 1-last_frame_up_dir.dot(-get_gravity().normalized()) <= smooth_up_dir_snap_level:
				lerping_up = false
				global_transform = snap_with_y(global_transform,-current_grav_dir)
			else:
				global_transform = lerp_with_y(global_transform,-current_grav_dir,_delta)
		else:
			global_transform = snap_with_y(global_transform,-current_grav_dir)
	handle_movement(get_input_direction())
	#handle_shmoovement()
	update_highlights()
	process_held_object()
	cam_tilt()
	#look_checker.force_raycast_update()
	#var col = look_checker.get_collider()
	#var p = look_checker.get_collision_point()
	#var A = ""
	#if col and col is StaticBody3D:
		#A = col.owner.suffering.cube_dist(col.owner.suffering.get_chunk_center(col.owner.global_position),p)
	#$MainUILayer/Control/RichTextLabel2.text = str(A)
	if Input.is_action_just_pressed("M1"): #TODO: Rework to function w/multthreading
		look_checker.force_raycast_update()
		var col = look_checker.get_collider()
		var pos = look_checker.get_collision_point()
		if col and col.owner is ThreadedChunk:
			col.owner.suffering.terraform(col.owner,pos,digging)
	
func _input(event: InputEvent) -> void:
	handle_rotation(event)
	input_call()
	
		
func snap_with_y(xform:Transform3D, new_y:Vector3):
	new_y = new_y.normalized() #Normalize the vector for usage in unscaled basis
	xform.basis.y = new_y #Sets the LOCAL y to the new y
	xform.basis.x = -xform.basis.z.cross(new_y) #Takes the cross product of the current Z and new Y (gives a vector perpendicular to both)
	xform.basis = xform.basis.orthonormalized() #Orthonormalizes the matrix, making all 3 vectors perpendicular to each other.
	return xform

func lerp_with_y(xform:Transform3D, new_y:Vector3,_delta:float):
	xform.basis.y = lerp(xform.basis.y,new_y,1*_delta) #Sets the LOCAL y to the new y
	xform.basis.x = -xform.basis.z.cross(xform.basis.y) #	
	xform.basis = xform.basis.orthonormalized()
	return xform

func update_gravity_direction():
	var g = get_gravity()
	last_frame_up_dir = -current_grav_dir
	if -g != Vector3.ZERO:
		up_direction = -g
		current_gravity = g
		current_grav_dir = g.normalized()
	else:
		up_direction = Vector3.UP
		current_gravity = ProjectSettings.get_setting("physics/3d/default_gravity_vector")*ProjectSettings.get_setting("physics/3d/default_gravity")
		current_grav_dir = ProjectSettings.get_setting("physics/3d/default_gravity_vector")
	#print(str(-current_grav_dir.dot(last_frame_up_dir)))
	#1.0 = parallel 0.0 = 90 degrees -1 = antiparallel
	if (-current_grav_dir.dot(last_frame_up_dir)) <= smooth_up_dir_threshold:
		lerping_up = true
	
func get_input_direction() -> Vector3:
	var h_rot = camera.rotation.y
	var x_force = Input.get_action_strength("move_right")-Input.get_action_strength("move_left")
	#var y_force = Input.get_action_strength("Up")-Input.get_action_strength("Down")* 1.0 if free_vert_movement else 0.0
	var z_force = Input.get_action_strength("move_backward") - Input.get_action_strength("move_forward")
	var m_vec = Vector3.ZERO
	var b = global_transform.basis.rotated(up_direction,h_rot)
	m_vec += x_force*b.x
	#m_vec += y_force*b.y
	m_vec += z_force*b.z
	
	return(m_vec.normalized())

	
	
func handle_movement(input: Vector3):
	var delta:float = 1./60.
	var iif = is_on_floor()
	if not iif:
		velocity += gravity_multiplier*current_gravity * delta
	if !is_sprinting:
		velocity = lerp(velocity,input*base_speed,(4.3*delta*(1.0 if iif else 0.3)))
	else:
		velocity = lerp(velocity,input*sprinting_speed,(4.5*delta*(1.0 if iif else 0.3)))
	if Input.is_action_pressed("ui_accept") and iif:
	
		velocity += global_transform.basis.y*jump_force
	
	if !frozen:
		move_and_slide()
	
func handle_rotation(event:InputEvent):
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mouse_input = event.relative
		var relative_rads = Vector3(-mouse_input.y,-mouse_input.x,0.0)*mouse_sensitivity*0.016
		camera.rotation += relative_rads
		camera.rotation.x = clamp(camera.rotation.x,-PI/2,PI/2)




func get_aabb_global_endpoints(mesh_instance: VisualInstance3D) -> Array:
	if not is_instance_valid(mesh_instance):
		return []
	var mesh
	if mesh_instance is MeshInstance3D:
		mesh = mesh_instance.mesh
		if not mesh:
			return []
	elif mesh_instance is CSGPrimitive3D:
		mesh = mesh_instance
	var aabb: AABB = mesh.get_aabb()
	var global_endpoints := []
	for i in range(8):
		var local_endpoint: Vector3 = aabb.get_endpoint(i)
		var global_endpoint: Vector3 = mesh_instance.to_global(local_endpoint)
		global_endpoints.push_back(global_endpoint)
	return global_endpoints

func get_min_max_positions(cornerarray):
	var min_x = cornerarray[0].x
	var min_y = cornerarray[0].y
	var max_x = cornerarray[0].x
	var max_y = cornerarray[0].y
	for i in 8:
		if cornerarray[i].x < min_x:
			min_x = cornerarray[i].x
		if cornerarray[i].y < min_y:
			min_y = cornerarray[i].y
		if cornerarray[i].x > max_x:
			max_x = cornerarray[i].x
		if cornerarray[i].y > max_y:
			max_y = cornerarray[i].y
		
	return [Vector2(min_x,min_y),Vector2(min_x,max_y),Vector2(max_x,min_y),Vector2(max_x,max_y)]


func set_obj_highlights(target):
	highlights_ui_layer.show()
	var cornerarray = get_aabb_global_endpoints(target)
	var corner2D = []
	for l in 8:
		corner2D.push_front(camera.unproject_position(cornerarray[l]))
	var minMax = get_min_max_positions(corner2D)
	for x in 4:
		highlights_ui_layer.get_child(x).position = minMax[x]
	
func update_highlights():
	var col = look_checker.get_collider()
	if col:
		if col is VisualInstance3D and col.is_in_group("highlight"):
			set_obj_highlights(col)
		elif col.is_in_group("highlight"):
			for i in col.get_children():
				if i is VisualInstance3D:
					set_obj_highlights(i)
					break
		else:
			highlights_ui_layer.hide()
	else:
		highlights_ui_layer.hide()

func toggle_zoom():
	is_zoomed = !is_zoomed
	camera.fov = 75 if !is_zoomed else 20
	mouse_sensitivity = base_mouse_sense if !is_zoomed else base_mouse_sense*0.5

func input_call():
	is_sprinting = Input.is_action_pressed("Shift")
	if is_ginput_valid():
		if Input.is_action_just_pressed("M2"):
			look_checker.force_raycast_update()
			var col = look_checker.get_collider()
			if col and col.owner is ThreadedChunk:
				col.owner.toggle_DBG()

		if Input.is_action_just_pressed("Zoom"):
			toggle_zoom()

		if Input.is_action_just_pressed("Flashlight"):
			toggle_flashlight()
		if Input.is_action_just_pressed("UnlockMouse"):
			toggle_mouse_mode()
		if Input.is_action_just_pressed("Dig"):
			digging = !digging



func try_trigger():
	var col = look_checker.get_collider()
	if look_checker.is_colliding() and col.is_in_group("player_triggerable"): #so much better.
		$InteractDelayTimer.start()
		col.trigger(self)

func toggle_flashlight(state = !flashlight.visible):
	flashlight.visible = state

func toggle_mouse_mode():
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func process_held_object():
	if is_instance_valid(held_physics_object):
		if is_ginput_valid():
			if Input.is_action_just_pressed("Left_Click"):
				held_physics_object.linear_damp = 0
				def_crosshair.show()
				hold_crosshair.hide()
				held_physics_object.apply_central_impulse((phys_checker.global_position-camera.global_position)*throw_power)
				held_physics_object = null
			elif Input.is_action_just_pressed("Right_Click"):
				held_physics_object.linear_damp = 0
				def_crosshair.show()
				hold_crosshair.hide()
				held_physics_object = null
			else:
				
				var hold_force = (phys_checker.global_position-held_physics_object.global_position)*hold_power
				held_physics_object.apply_central_force(hold_force)
		else:
			var hold_force = (phys_checker.global_position-held_physics_object.global_position)*hold_power
			held_physics_object.apply_central_force(hold_force)
	else:
		def_crosshair.show()
		hold_crosshair.hide()
#TODO: Fix some jank with item holding

func is_ginput_valid():
	return true

func check_for_pickups():
	if held_physics_object == null:
		for i in phys_checker.get_overlapping_bodies():
			if i is RigidBody3D and !i is Player:
				held_physics_object = i
				held_physics_object.linear_damp = 8
				held_physics_object.angular_damp = 8
				hold_crosshair.show()
				def_crosshair.hide()
	else:
		held_physics_object.linear_damp = 0
		held_physics_object.angular_damp = 0
		held_physics_object = null
		def_crosshair.show()
		hold_crosshair.hide()

func get_team():
	push_error("get_team() SHOULD NOT BE CALLED.")
	breakpoint 
	
	
	return 0

func cam_tilt():
	var delta: float = 1./60.
	var input_x = Input.get_action_strength("move_right")-Input.get_action_strength("move_left")
	if is_ginput_valid() and !input_disable:
		camera.rotation.z = clamp(lerp(camera.rotation.z, -input_x * cam_rotation_amount, 10 * delta),-cam_rotation_max,cam_rotation_max) #WARNING: Could cause issues. Swapped to rotating camera for cam sway. Needs TEST




	
func toggle_input_disable():
	input_disable = !input_disable
	frozen = !frozen
	
func teleport(pos:Vector3):
	global_position = pos

func toggle_collision():
	col_disabled = !col_disabled
	if col_disabled:
		set_collision_layer_value(1,false)
		set_collision_mask_value(1,false)
		set_collision_layer_value(4,false)
		set_collision_mask_value(4,false)
	else:
		set_collision_layer_value(1,true)
		set_collision_mask_value(1,true)
		set_collision_layer_value(4,true)
		set_collision_mask_value(4,true)
		


	
	
