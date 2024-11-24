extends RichTextLabel


var longest_frame_time = 0.0
var inc = 0
func _process(delta: float) -> void:
	inc += 1
	if delta > longest_frame_time:
		longest_frame_time = delta
	if inc > 120:
		inc = 0
		longest_frame_time = delta
	text = "FPS:"+str(Engine.get_frames_per_second()) + "\nLast frame time: "+str(snapped(delta,0.01))+"\nLongest frame time: "+str(longest_frame_time)
