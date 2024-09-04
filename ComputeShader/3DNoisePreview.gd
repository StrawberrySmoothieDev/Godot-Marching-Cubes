@tool
extends Sprite3D
@export var raster: Rasterizer
@export_range(0,1) var depth: float = 0.0:
	set(val):
		depth = val
		update_sprite()
func update_sprite():
	if raster:
		var index = int(depth*raster.images.size())
		texture = ImageTexture.create_from_image(raster.images[index])
