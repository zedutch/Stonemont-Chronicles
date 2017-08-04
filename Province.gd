extends Node2D

export(String)   var name   = ""
export(int, 100) var wealth = 50

onready var lblName   = get_node("name")
onready var sprite    = get_node("sprite")
onready var data      = get_node("data")
onready var prgWealth = get_node("data/wealth")

var owner = "player"
onready var id = get_name()

var mouse_over = false

func _ready():
	lblName.text    = name
	prgWealth.value = wealth
	data.hide()
#	set_process(true)
#
#func _process(delta):
#	if Input.is_action_just_released("dbg_click") and mouse_over:
#		match owner:
#			"player" : set_owner("enemy1")
#			"enemy1" : set_owner("enemy2")
#			"enemy2" : set_owner("enemy3")
#			"enemy3" : set_owner("enemy4")
#			"enemy4" : set_owner("player")

func show_data():
	data.show()

func set_owner(var new_owner):
	print("Changing owner of ", name, " from ", owner, " to ", new_owner)
	owner = new_owner
	sprite.set_animation(owner)
	if owner != "player":
		data.hide()
	else:
		data.show()

func add_wealth(var amount):
	prgWealth.value += amount
	if prgWealth.value < 0: prgWealth.value = 0
	elif prgWealth.value > 100: prgWealth.value = 100
	wealth = prgWealth.value

func get_wealth_perc():
	return prgWealth.value / prgWealth.max_value

func _on_area_mouse_entered():
	mouse_over = true
#	print("Hovering over ", name)

func _on_area_mouse_exited():
	mouse_over = false