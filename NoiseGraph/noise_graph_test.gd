@tool
extends SubViewport
@onready var sprite = $NoiseGraphTest
@export var images: Array[Image]
@export var rasterize: bool = false:
	set(val):
		raster()
@export var depth: int = 64
var is_rasterizing = false
signal done_rasterizing
func raster():
	if !is_rasterizing:
		is_rasterizing = true
		images.clear()
		
		for i in range(depth):
			var depth:float = float(i)*(1.0/float(depth))
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
		
