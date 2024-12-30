@tool
extends Node3D
@export var chunk_size:int = 8


	
func cube_dist(center: Vector3,pos: Vector3):
	var x = min(abs(pos.x-center.x),abs(pos.x+center.x))
	var y = min(abs(pos.y-center.y),abs(pos.y+center.y))
	var z = min(abs(pos.z-center.z),abs(pos.z+center.z))
	return max(x,y,z)
	#return Vector3(x,y,z)

func _physics_process(delta: float) -> void:
	$DebugOutline/MeshInstance3D/Label3D.text = str(cube_dist_diff(get_chunk_center($DebugOutline.global_position),$Marker3D.global_position))

func get_chunk_center(opos: Vector3): #TODO: Test to make sure this actually works. Get the feeling it's a lil scuffed.
	var offset = Vector3(chunk_size,chunk_size,chunk_size)/2
	return opos+offset

func cube_dist_diff(center: Vector3,pos: Vector3):
	var x = min_signed(pos.x,center.x)
	var y = min_signed(pos.y,center.y)
	var z = min_signed(pos.z,center.z)
	return Vector3(x,y,z)

func min_signed(posx:float,centerx:float) -> float:
	var pxm = posx-centerx
	var pxa = posx+centerx
	if abs(pxm) < abs(pxa):
		return pxm
	elif abs(pxm) > abs(pxa):
		return pxa
	else:
		return min(pxa,pxm)
	
