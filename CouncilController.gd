extends Control

onready var portrait = get_node("portrait")
onready var lbl_name = get_node("text_box/margin/container/name")
onready var text_box = get_node("text_box/margin/container/text")
onready var options  = get_node("text_box/margin/container/options")

export(PackedScene) var options_scene

var names = {
	Globals.Character.Bishop   : "Archbishop Archibald the Second",
	Globals.Character.Merchant : "Haji, Head of the Merchant's Guild",
	Globals.Character.Advisor  : "Grima, Your Personal Advisor",
	Globals.Character.General  : "General Kiska",
	Globals.Character.Baroness : "Madame Carolina Mary de Wittacère, Baroness de Vastra"
}

var active_character = null

func _ready():
	set_character(Globals.Character.Bishop)
#	set_process(true)
#
## For debugging
#func _process(delta):
#	if Input.is_action_just_pressed("ui_accept"):
#		if active_character == Globals.Character.Bishop:
#			set_character(Globals.Character.Merchant)
#		else:
#			set_character(Globals.Character.Bishop)

func set_text(var text):
	text_box.set_text(text)

func add_option(var text, var callback, var id):
	var opt = options_scene.instance()
	options.add_child(opt)
	opt.set_text(text)
	opt.add_callback(callback, id)

func remove_options():
	for child in options.get_children():
		options.remove_child(child)

func current_advisor_name():
	return names[active_character]

func set_character(var new_character):
	active_character = new_character
	portrait.update_portrait(active_character)
	lbl_name.text = current_advisor_name() + ":"