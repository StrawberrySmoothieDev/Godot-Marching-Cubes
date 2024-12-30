#@tool
extends Sprite2D
@export var noise:Noise
#@export var img_scale: Vector3i = Vector3i(64,64,64)
#var itter = 0
#var imgs: Array[Image]
#func _ready() -> void:
	#imgs = noise.get_image_3d(img_scale.x,img_scale.y,img_scale.z)
#func _physics_process(delta: float) -> void:
	#if imgs.size() > 0:
		#if itter < imgs.size()-1:
			#itter += 1
		#else:
			#itter = 0
		#texture = ImageTexture.create_from_image(imgs[itter])
