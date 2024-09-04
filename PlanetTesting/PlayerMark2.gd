
  #___       _     __  __     ___    ___      ___   ___    ___    _   _   ___  
 #|_ _|     /_\   |  \/  |   / __|  / _ \    | _ \ | _ \  / _ \  | | | | |   \ 
  #| |     / _ \  | |\/| |   \__ \ | (_) |   |  _/ |   / | (_) | | |_| | | |) |
 #|___|   /_/ \_\ |_|  |_|   |___/  \___/    |_|   |_|_\  \___/   \___/  |___/
extends RigidBody3D

class_name Player

@export var mouse_sense = 0.1
@export var sped = 15.0
@export var sprint_sped = 25.0
@export var jump_force = 2.0
@export var on_floor_normal_range = 0.5
@export var hold_power = 100.0
@export var throw_power = 10.0
@export var double_jump = 2
@export var gravity_correct = true
@export var o2 = 1000.0
@export var o2_max = 1000.0

@onready var camera = $CameraTransform/SecondaryTransform/Camera
@onready var primary_camera_transform = $CameraTransform
@onready var secondary_camera_transform = $CameraTransform/SecondaryTransform

@onready var aim_adjust_marker = $CameraTransform/SecondaryTransform/Camera/AimAdjustMarker
@onready var look_checker = $CameraTransform/SecondaryTransform/Camera/CrosshairChecker
@onready var phys_checker = $CameraTransform/SecondaryTransform/Camera/Area3D
@onready var friction_timer = $FrictionTimer

var mouse_input : Vector2
var grav: Vector3 = Vector3.DOWN
var input_disable = false
var is_zoomed = false

var held_phys_obj: RigidBody3D = null
var pda_open = false

var def_weapon_manager_pos
var col_disabled = false
var sprinting = false 
var free_vert_movement = false
var deploying_item = false
var vel_parent: RigidBody3D
var last_parent_linear_vel = Vector3.ZERO
@export_category("Camera Sway Variables")
@export var cam_rotation_amount : float = 1
@export var cam_rotation_max : float = 4
@export var weapon_sway_amount : float = 5
@export var weapon_rotation_amount : float = 1
@export var invert_weapon_sway : bool = false

var tp_to = null
var tp_to_transform = null

func _ready():
	look_checker.add_exception(self)
	
	

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta):
	o2-=2*delta
	var h_rot = primary_camera_transform.rotation.y
	var force = Input.get_action_strength("move_backward") - Input.get_action_strength("move_forward")
	
	var force2 = Input.get_action_strength("move_right")-Input.get_action_strength("move_left")

	var basis2 = global_transform.basis.rotated(grav.normalized(),-h_rot)
	var basis3 = global_transform.basis.rotated(grav.normalized(),-h_rot)
	if (abs(force) > 0 or abs(force2) > 0) and is_on_floor():
		#footstep_player.play_footstep()
		friction_timer.start()
	apply_central_force((sprint_sped if sprinting and !free_vert_movement else sped)*force*Vector3(basis2.z))
	apply_central_force((sprint_sped if sprinting and !free_vert_movement else sped)*force2*Vector3(basis3.x))
	if Input.is_action_pressed("jump") and is_on_floor():
		apply_central_impulse(jump_force*Vector3(global_transform.basis.y))
	elif Input.is_action_pressed("jump") and free_vert_movement:
		apply_central_force(12.0*Vector3(global_transform.basis.y))
	if sprinting and free_vert_movement:
		apply_central_force(-12.0*Vector3(global_transform.basis.y))

	if Input.is_action_just_pressed("jump") and double_jump:
		apply_central_impulse(jump_force*Vector3(global_transform.basis.y))
		double_jump -=1
	if friction_timer.is_stopped() and is_on_floor():
		physics_material_override.friction = lerp(physics_material_override.friction,10.0,0.7*delta)
	else:
		physics_material_override.friction = 0.0

	#var move_input = Input.get_vector("move_left","move_right","move_backward","move_forward")
	#apply_central_force(Vector3(move_input.x,0.0,move_input.y))
	
func _input(event):
	look_checker.force_raycast_update()
	var col2 = look_checker.get_collider()

	if Input.is_action_just_pressed("Zoom"):

		is_zoomed = !is_zoomed
		$CameraTransform/SecondaryTransform/Camera.fov = 75 if !is_zoomed else 20
		mouse_sense = 0.1 if !is_zoomed else 0.05
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mouse_input = event.relative
		primary_camera_transform.rotate_y(deg_to_rad(-event.relative.x * mouse_sense))
		secondary_camera_transform.rotate_x(deg_to_rad(-event.relative.y * mouse_sense))
		secondary_camera_transform.rotation.x = clamp(secondary_camera_transform.rotation.x, deg_to_rad(-90), deg_to_rad(65))
		if gravity_correct:
			primary_camera_transform.global_transform = align_with_y(primary_camera_transform.global_transform,-grav)

	if Input.is_action_just_pressed("Flashlight"):
		$CameraTransform/SecondaryTransform/Camera/SpotLight3D.visible = !$CameraTransform/SecondaryTransform/Camera/SpotLight3D.visible
	if Input.is_action_just_pressed("UnlockMouse"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

		
		sprinting = Input.is_action_pressed("Shift")
func _integrate_forces(state:PhysicsDirectBodyState3D):
	if tp_to:
		state.transform.origin = tp_to
		tp_to = null
	if tp_to_transform:
		state.transform = tp_to_transform
		tp_to_transform = null
	elif gravity_correct:
		var force2 = Input.get_action_strength("move_right")-Input.get_action_strength("move_left")
		var gravity_vec = state.total_gravity
		if gravity_vec == Vector3.ZERO or gravity_vec == Vector3.DOWN:
			gravity_vec = Vector3(0,-1,0)
		var up = -gravity_vec
		grav = gravity_vec
		global_transform = align_with_y(global_transform,up)
	#if vel_parent:
		##state.linear_velocity -= last_parent_linear_vel
		#state.linear_velocity += vel_parent.linear_velocity*0.016
		#last_parent_linear_vel = vel_parent.linear_velocity
	#up = tgt.global_position-global_position
	#rotation = rotation.slerp(Vector3(up.x,up.y,up.z),1.0)



func align_with_y(xform:Transform3D, new_y:Vector3):
	xform.basis.y = new_y #Sets the LOCAL y to the new y
	xform.basis.x = -xform.basis.z.cross(new_y) #
	xform.basis = xform.basis.orthonormalized()
	return xform





	
func is_on_floor():
	var state:PhysicsDirectBodyState3D = PhysicsServer3D.body_get_direct_state(get_rid())
	var col_count = state.get_contact_count()
	if col_count == 0:
		return false
	for contact in col_count:
		var contact_norm = state.get_contact_local_normal(contact)
		var norm_grav = grav.normalized()
		var inv_grav = -grav
		var dir = contact_norm.dot(inv_grav)
		if dir >= on_floor_normal_range:
			if state.get_contact_collider_object(contact) is RigidBody3D:
				vel_parent = state.get_contact_collider_object(contact)
		return dir >= on_floor_normal_range
	return false
	






func teleport(pos: Vector3):
	tp_to = pos

func teleport_transform(pos: Transform3D):
	tp_to_transform = pos
