extends RigidBody3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func align_with_y(xform:Transform3D, new_y:Vector3):
	xform.basis.y = new_y #Sets the LOCAL y to the new y
	xform.basis.x = -xform.basis.z.cross(new_y) #
	xform.basis = xform.basis.orthonormalized()
	return xform
