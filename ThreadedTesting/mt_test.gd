extends Node3D

var thread1: Thread
var thread2: Thread

func _ready() -> void:
	thread1 = Thread.new()
	thread2 = Thread.new()
	thread1.start(func1)
	thread2.start(func2)
func func1():
	print("T1 finished")
func func2():
	print("T2 finished")
func _exit_tree() -> void:
	thread1.wait_to_finish()
	thread2.wait_to_finish()
