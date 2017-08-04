extends Container

onready var marker      = get_node("content/marker")
onready var button      = get_node("content/button")
onready var placeholder = get_node("content/placeholder")

var style = StyleBoxFlat.new()
var callback
var id

func _ready():
	self.add_style_override("panel", style)
	hide_marker()

func set_text(var text):
	button.text = text

func add_callback(var callback, var id):
	self.callback = callback
	self.id = id

func _on_option_mouse_entered():
	show_marker()

func _on_option_mouse_exited():
	hide_marker()

func hide_marker():
	marker.hide()
	placeholder.show()
	style.bg_color = Color(1.0, 1.0, 1.0, 0.0)

func show_marker():
	marker.show()
	placeholder.hide()
	style.bg_color = Color(1.0, 1.0, 1.0, 0.5)

func _on_option_gui_input( ev ):
	if ev is InputEventMouseButton and not ev.is_pressed() and ev.get_button_index() == BUTTON_LEFT:
		callback.call_func(id)