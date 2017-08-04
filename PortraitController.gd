extends Panel

onready var Portraits = {
	Globals.Character.Bishop   : get_node("bishop"),
	Globals.Character.Merchant : get_node("merchant"),
	Globals.Character.Advisor  : get_node("advisor"),
	Globals.Character.General  : get_node("general"),
	Globals.Character.Baroness : get_node("baroness")
}

var active_character = null

func _ready():
	for i in Portraits:
		Portraits[i].hide()

func update_portrait(var new_character):
	if active_character != new_character:
		print("Changing the active portrait from ", active_character, " to ", new_character)
		# hide the previous portrait
		if active_character != null:
				Portraits[active_character].hide()
				
		# Show the new portrait
		active_character = new_character
		Portraits[active_character].show()
		
		rect_clip_content = true
	else:
		pass # New character is the same as the old one