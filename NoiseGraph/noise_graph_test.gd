@tool
extends SubViewport
class_name Rasterizer
@onready var sprite = $NoiseGraphTest
@export var images: Array[Image]
@export var rasterize: bool = false:
	set(val):
		raster()
		

@export var res: int = 64:
	set(val):
		res = val
		size = Vector2(res,res)
		sprite.position = Vector2(res/2,res/2)
		sprite.texture.width = res
		sprite.texture.height = res
#@export var debug: Vector3:
	#set(val):
		#debug = val
		#terraform(debug)
var is_rasterizing = false
signal done_rasterizing
func raster():
	if !is_rasterizing:
		is_rasterizing = true
		images.clear()
		
		for i in range(int(res)):
			var depth:float = float(i)*(1.0/float(res))
			print("Rasterizing layer "+str(depth))
			#await RenderingServer.frame_pre_draw
			sprite.material.set_shader_parameter("Depth",depth)
			
			await RenderingServer.frame_post_draw
			var img = get_texture().get_image()
			img.convert(Image.FORMAT_L8)
			images.append(img)
		is_rasterizing = false
		done_rasterizing.emit()
	return images
		

func terraform(position:Vector3):
	var upscale = 15.5
	for index in range(images.size()):
		if abs((index*upscale)-position.z) < 2:
			var temp_img:Image = images[index]
			temp_img.set_pixelv(Vector2(position.x,position.y)/upscale,Color.WHITE)
			
