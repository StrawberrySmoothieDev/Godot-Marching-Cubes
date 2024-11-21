extends Node
var props: Dictionary
var active_labels: Array[Label]
var container: HBoxContainer
func _ready() -> void:
	container = HBoxContainer.new()
	add_child(container)
func add_new_property(node: Node, property: String, label_name: String = ""):
	props[property] = node
	var i: Label = Label.new()
	active_labels.append(i)
	container.add_child(i)
	if label_name != "":
		i.name = label_name
func _physics_process(delta: float) -> void:
	if props.size() > 0:
		var l = 0
		for i in props:
			active_labels[l].text = active_labels[l].name+str(props[i].get(i))
			l+=1
