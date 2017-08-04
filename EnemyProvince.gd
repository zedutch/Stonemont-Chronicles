extends Node2D

export(String) var name = ""
onready var lblName = get_node("name")

onready var id = get_name()
var aggressiveness
var available = []

func _ready():
	lblName.text = name
	randomize()
	aggressiveness = floor(randf() * 100)

func can_attack(var temperature, var province_id):
	return temperature >= aggressiveness and available.has(province_id)

func may_take(var province_id):
	available.append(province_id)