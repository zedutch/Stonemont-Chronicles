extends Node

var event_pool = []
var poor_pool  = []
var rich_pool  = []
var event_data = {}

var temperature = 0
var day = -1

onready var council = get_node("council")
onready var debug   = get_node("debug_ui")
onready var lblTemp = get_node("debug_ui/container/temperature")
onready var lblEvnt = get_node("debug_ui/container/event_id")
onready var lblDay  = get_node("council/day")

var current_event
var current_event_id
var current_province
var current_enemy
var current_variable
var flags = {}
var variables = {}
var poor_provinces = []
var rich_provinces = []

var chars = {
	"bishop"   : Globals.Character.Bishop,
	"merchant" : Globals.Character.Merchant,
	"advisor"  : Globals.Character.Advisor,
	"general"  : Globals.Character.General,
	"baroness" : Globals.Character.Baroness
}

func _ready():
	if false:
		print("Running in debug mode")
	else:
		debug.hide()

	print("Loading event manager")
	var file = File.new()
	file.open("res://events.json", File.READ)
	var json_str
	if file.get_error():
		json_str = Globals.json
	else:
		json_str = file.get_as_text()
	event_data = parse_json(json_str)
	for event in event_data.initial_pool:
		event_pool.append(event)
	for event in event_data.poor_pool:
		poor_pool.append(event)
	for event in event_data.rich_pool:
		rich_pool.append(event)
	print("Number of events in pool: %d" % event_pool.size())
	update_temperature(0)
	new_day()
	show_event("tutorial1")
#	set_process(true)
#
#func _process(delta):
#	if Input.is_action_just_released("dbg_flags"):
#		print("Flags: ", flags)
#	elif Input.is_action_just_released("dbg_variables"):
#		print("Vars: ", variables)
#	elif Input.is_action_just_released("dbg_aggressiveness"):
#		print("Aggressivenesses:")
#		for enemy in get_enemies():
#			print(enemy.name, " -> ", enemy.aggressiveness)

func show_event(event_id):
	print("Number of events in pool: %d. Now showing: %s" % [event_pool.size(), event_id])
	
	if event_id == "random":
		return choose_random_event()
	
	var event        = event_data[event_id]
	current_event    = event
	current_event_id = event_id
	lblEvnt.text     = event_id
	
	if   "max_temp" in event and event.max_temp < temperature:
		if not "repeat" in event or !event.repeat:
			event_pool.erase(event_id)
		return show_event(event["else"])
	elif "min_temp" in event and event.min_temp > temperature:
		if not "repeat" in event or !event.repeat:
			event_pool.erase(event_id)
		return show_event(event["else"])
	
	if   "max_wealth" in event and event.max_wealth < current_province.wealth:
		if not "repeat" in event or !event.repeat:
			event_pool.erase(event_id)
		if "else_wealth" in event:
			return show_event(event["else_wealth"])
		else:
			return show_event(event["else"])
	elif "min_wealth" in event and event.min_wealth > current_province.wealth:
		if not "repeat" in event or !event.repeat:
			event_pool.erase(event_id)
		return show_event(event["else"])
	
	if   "max_provinces" in event and event.max_provinces < get_provinces().size():
		if not "repeat" in event or !event.repeat:
			event_pool.erase(event_id)
		return show_event(event["else"])
	elif "min_provinces" in event and event.min_provinces > get_provinces().size():
		if not "repeat" in event or !event.repeat:
			event_pool.erase(event_id)
		return show_event(event["else"])
	
	if "has_flag" in event and not flags.has(event.has_flag):
		if not "repeat" in event or !event.repeat:
			event_pool.erase(event_id)
		return show_event(event["else"])
	
	if "if_can_take_province" in event and event.if_can_take_province:
		var ok = false
		for enemy in get_enemies():
			if ok: break
			for province in get_provinces():
				if ok: break
				if enemy.can_attack(temperature, province.id):
					current_enemy = enemy
					current_province = province
					ok = true
		if not ok:
			print("No country can take a province")
			show_event(event["else"])
			if not "repeat" in event or !event.repeat:
				event_pool.erase(event_id)
			return
	
	parse_commands(event)
	
	# This has to be done before formatting the text to make sure all strings are correct
	if "character" in event:
		council.set_character(chars[event.character])
	
	if "set_rand_enemy" in event and event.set_rand_enemy:
		current_enemy = choose_random_enemy()
	
	if "set_var_enemy" in event and event.set_var_enemy:
		current_enemy = get_enemy(current_variable)
	
	if "set_rand_prov" in event and event.set_rand_prov:
		current_province = choose_random_province()
	
	if "set_var_prov" in event and event.set_var_prov:
		current_province = get_province(current_variable)
		
	if "set_adj_prov" in event and event.set_adj_prov:
		current_province = choose_adjacent_province(current_enemy.id)
		if current_province == null and "set_rand_enemy" in event and event.set_rand_enemy:
			while current_province != null:
				current_enemy = choose_random_enemy()
				current_province = choose_adjacent_province(current_enemy.id)
	
	if "if_has_prov" in event and event.if_has_prov and not current_province.owner == "player":
		if not "repeat" in event or !event.repeat:
			event_pool.erase(event_id)
		return show_event(event["else"])
	
	var text = event.text
	if "format" in event:
		text = format_string(text, event.format)
	council.set_text(text)
	
	council.remove_options()
	
	if "options" in event:
		for option in event.options:
			if can_show_option(option):
				var opt_text = option.text
				if "format" in option:
					opt_text = format_string(opt_text, option.format)
				council.add_option(opt_text, funcref(self, "option_clicked"), option)
	else:
		for option in event_data[event.options_copy].options:
			if can_show_option(option):
				var opt_text = option.text
				if "format" in option:
					opt_text = format_string(opt_text, option.format)
				council.add_option(opt_text, funcref(self, "option_clicked"), option)
	
	if not "repeat" in event or !event.repeat:
		event_pool.erase(event_id)

func can_show_option(option):
	if   "max_temp" in option and option.max_temp < temperature:
		return false
	elif "min_temp" in option and option.min_temp > temperature:
		return false
	if "has_flag" in option and not flags.has(option.has_flag):
		return false
	if "if_can_take_province" in option and option.if_can_take_province:
		var ok = false
		for enemy in get_enemies():
			if ok: break
			for province in get_provinces():
				if ok: break
				ok = enemy.can_attack(temperature, province.id)
		if not ok:
			return false
	if   "max_wealth" in option and option.max_wealth < current_province.wealth:
		return false
	elif "min_wealth" in option and option.min_wealth > current_province.wealth:
		return false
	if   "max_provinces" in option and option.max_provinces < get_provinces().size():
		return false
	elif "min_provinces" in option and option.min_provinces > get_provinces().size():
		return false
	
	return true

func parse_commands(object):
	if "new_day" in object:
		new_day()
	
	if "move_wealth" in object:
		var from = object.move_wealth.split("-")[0]
		var to   = object.move_wealth.split("-")[1]
		var to_move
		match from:
			"all" : to_move = current_province.wealth
			_     : to_move = int(from)
		move_wealth(current_province.id, to, to_move)
	
	if "receive_wealth" in object:
		var amount = object.receive_wealth.split("-")[0]
		var from   = object.receive_wealth.split("-")[1]
		move_wealth(from, current_province.id, int(amount))

	if "set_flag" in object:
		flags[object.set_flag] = true
	if "clear_flag" in object:
		flags.erase(object.set_flag)
	
	if "get_var" in object and variables.has(object.get_var):
		current_variable = variables[object.get_var]
	if "set_var" in object:
		var val = object.var_value
		if val == "act_prov":
			val = current_province.id
		if val == "act_enemy":
			val = current_enemy.id
		variables[object.set_var] = val
	if "clear_var" in object:
		variables.erase(object.clear_var)
	
	if "change_act_prov" in object and object.change_act_prov:
		current_province.set_owner(current_enemy.id)
	
	if "retake_act_prov" in object and object.retake_act_prov:
		current_province.set_owner("player")
	
	if "temp_change" in object:
		update_temperature(object.temp_change)
	
	if "wealth_change" in object:
		current_province.add_wealth(object.wealth_change)
	
	if "wealth_change_all" in object:
		for province in get_provinces():
			province.add_wealth(object.wealth_change_all)
	
	if "show_wealth" in object and object.show_wealth:
		get_node("world/prov1").show_data()
		get_node("world/prov2").show_data()
		get_node("world/prov3").show_data()
		get_node("world/prov4").show_data()
		get_node("world/prov5").show_data()
	
	if "set_can_take" in object and object.set_can_take:
		current_enemy.may_take(current_province.id)
	
	if "followup_list" in object:
		for ev in object.followup_list:
			event_pool.append(ev)
	
	if "followup_list_copy" in object:
		for ev in event_data[object.followup_list_copy].followup_list:
			event_pool.append(ev)

func check_provinces_wealth():
	for province in get_provinces():
		if province.get_wealth_perc() <= 0:
			if not poor_provinces.has(province):
				poor_provinces.append(province)
				current_province = province
				return choose_random_poor_event()
		elif poor_provinces.has(province):
			poor_provinces.erase(province)
		if province.get_wealth_perc() >= 1:
			if not rich_provinces.has(province):
				rich_provinces.append(province)
				current_province = province
				return choose_random_rich_event()
		elif rich_provinces.has(province):
			rich_provinces.erase(province)

func get_province(var id):
	return get_node("world/" + id)

func choose_random_province():
	var provinces = get_provinces()
	return provinces[floor(provinces.size() * randf())]

func choose_adjacent_province(enemy):
	var provinces = []
	match enemy:
		"enemy1" :
			add_province_if_player("prov1", provinces)
			add_province_if_player("prov2", provinces)
			if owns_either_province(enemy, "prov1", "prov2"):
				add_province_if_player("prov5", provinces)
			if owns_either_province(enemy, "prov2", "prov5"):
				add_province_if_player("prov3", provinces)
			if owns_either_province(enemy, "prov3", "prov5"):
				add_province_if_player("prov4", provinces)
		"enemy2" :
			add_province_if_player("prov2", provinces)
			add_province_if_player("prov3", provinces)
			if owns_either_province(enemy, "prov2", "prov3"):
				add_province_if_player("prov5", provinces)
			if owns_either_province(enemy, "prov2", "prov5"):
				add_province_if_player("prov1", provinces)
			if owns_either_province(enemy, "prov3", "prov5"):
				add_province_if_player("prov4", provinces)
		"enemy3" :
			add_province_if_player("prov3", provinces)
			add_province_if_player("prov4", provinces)
			if owns_either_province(enemy, "prov3", "prov4"):
				add_province_if_player("prov5", provinces)
			if owns_either_province(enemy, "prov3", "prov5"):
				add_province_if_player("prov2", provinces)
			if owns_either_province(enemy, "prov2", "prov5"):
				add_province_if_player("prov1", provinces)
		"enemy4" :
			add_province_if_player("prov1", provinces)
			add_province_if_player("prov4", provinces)
			add_province_if_player("prov5", provinces)
			if owns_either_province(enemy, "prov1", "prov5"):
				add_province_if_player("prov2", provinces)
			if owns_either_province(enemy, "prov4", "prov5"):
				add_province_if_player("prov3", provinces)
	if provinces.size() > 0:
		return provinces[floor(provinces.size() * randf())]
	else:
		return null

func add_province_if_player(province_id, list):
	if get_province(province_id).owner == "player": list.append(get_province(province_id))

func owns_either_province(enemy, province_id1, province_id2):
	return get_province(province_id1).owner == enemy or get_province(province_id2).owner == enemy

func get_provinces():
	var provinces = []
	if get_node("world/prov1").owner == "player":
		provinces.append(get_node("world/prov1"))
	if get_node("world/prov2").owner == "player":
		provinces.append(get_node("world/prov2"))
	if get_node("world/prov3").owner == "player":
		provinces.append(get_node("world/prov3"))
	if get_node("world/prov4").owner == "player":
		provinces.append(get_node("world/prov4"))
	if get_node("world/prov5").owner == "player":
		provinces.append(get_node("world/prov5"))
	return provinces

func get_enemies():
	return [get_enemy("enemy1"), get_enemy("enemy2"), get_enemy("enemy3"), get_enemy("enemy4")]

func get_enemy(var id):
	return get_node("world/" + id)

func choose_random_enemy():
	var enemies = get_enemies()
	return enemies[floor(enemies.size() * randf())]

func format_string(text, format):
	var f = []
	for string in format:
		_format_match(string, f)
	return text % f

func _format_match(string, f):
	match string:
		"country"   : f.append(Globals.country_name)
		"days"      : f.append(day)
		"act_prov"  : f.append(current_province.name)
		"act_enemy" : f.append(current_enemy.name)
		"prov1"     : f.append(get_node("world/prov1").name)
		"prov2"     : f.append(get_node("world/prov2").name)
		"prov3"     : f.append(get_node("world/prov3").name)
		"prov4"     : f.append(get_node("world/prov4").name)
		"prov5"     : f.append(get_node("world/prov5").name)
		"enemy1"    : f.append(get_node("world/enemy1").name)
		"enemy2"    : f.append(get_node("world/enemy2").name)
		"enemy3"    : f.append(get_node("world/enemy3").name)
		"enemy4"    : f.append(get_node("world/enemy4").name)
		"char_name" : f.append(council.current_advisor_name())
		"var"       : _format_match(current_variable, f)
		_           : f.append("MISSING STRING ["+str(string)+"]")
		
func update_temperature(temp_change):
	temperature += temp_change
	lblTemp.text = "Temp: %d" % temperature

func new_day():
	day += 1
	if day > 0:
		if day == 1: lblDay.show()
		lblDay.text = "Day %d" % day
	else:
		lblDay.hide()
		
func choose_random_event():
	print("Main event pool:")
	choose_random_event_from_pool(event_pool)

func choose_random_poor_event():
	print("Poor pool:")
	choose_random_event_from_pool(poor_pool)

func choose_random_rich_event():
	print("Rich pool:")
	choose_random_event_from_pool(rich_pool)

func choose_random_event_from_pool(pool):
	print("Number of events in this pool: %d. Choosing one at random." % pool.size())
	randomize()
	var next_ev = floor(pool.size() * randf())
	var event_id = pool[next_ev]
	while event_id == current_event_id:
		next_ev = floor(pool.size() * randf())
		event_id = pool[next_ev]
	show_event(event_id)

func option_clicked(option):
	print("You selected '", option.text, "'. Number of events in pool: ", event_pool.size())
	
	if "restart_game" in option:
		return get_tree().reload_current_scene()
	elif "close_game" in option:
		return get_tree().quit()
		
	parse_commands(option)
			
	if "followup" in option:
		var event = option.followup
		if "immediate" in option and option.immediate:
			return show_event(event)
		else:
			event_pool.append(event)
			print("Event added to pool, should pick a new random event")
			choose_random_event()
	else:
		print("No more followups, should pick a new random event")
		choose_random_event()
	
	check_provinces_wealth()

func move_wealth(from, to, amount):
	var move_from = []
	if from == "all":
		move_from = get_provinces()
		if to != "all":
			move_from.erase(get_province(to))
	else:
		move_from.append(get_province(from))
	var move_to = []
	if to == "all":
		move_to = get_provinces()
		if from != "all":
			move_to.erase(get_province(from))
	else:
		move_to.append(get_province(to))
	
	var num_from = move_from.size()
	var num_to   = move_to.size()
	if num_to > 0 and num_from > 0:
		print("Moving ", amount, " wealth from ", num_from, " provinces to ", num_to, " other province(s)")
		var actual_amount = 0
		var each_from = amount / num_from
		for prov in move_from:
			if prov.wealth >= each_from:
				actual_amount += each_from
			else:
				actual_amount += prov.wealth
			prov.add_wealth(-each_from)
			
		print("Managed to collect ", actual_amount, " wealth of the ", amount, " requested")
		var each_to = actual_amount / num_to
		for prov in move_to:
			prov.add_wealth(each_to)