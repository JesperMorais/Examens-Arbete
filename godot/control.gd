#control.gd
#menu script
extends Control

var selected_game_index = -1

@export var pong_scene: PackedScene
var last_axis_y := {}       # mac -> previous y-axis value

var menu_items := [] #kommer innehålla alla menuitems-noder
var item_positions := [] #Motsvarande globala positioner
var current_index := {} #mac_adress -> valt index

var blobs := {} # mac -> blob node
var _last_button_state := {} # mac -> bool (for edge detection)
var blob_scene := preload("res://Scenes/blob.tscn")


func _ready() -> void:
	WebSocketManager.set_current_scene(self)
	WebSocketManager.register_player_list(get_node("PanelContainer2/VBoxContainer2/VBoxContainer/playerList"))
	WebSocketManager.register_player_list_txt(get_node("PanelContainer3/VBoxContainer/ItemList"))
	
	#hämta alla menyalternativ
	menu_items = get_tree().get_nodes_in_group("MenuItem")
	print("Hittade", menu_items.size(), "meny-items")
	# spara deras positioner
	for i in range(menu_items.size()):
		var it = menu_items[i]
		print("   [", i, "]", it.name, "@", it.global_position, "visible?", it.visible)
		item_positions.append(it.global_position)
	current_index.clear()

func _process(_delta: float) -> void:
	_update_all_blobs()
	
func _on_game_list_item_selected(index: int) -> void:
	selected_game_index = index
	print("Picked index:",index)

func _handle_button_press(mac:String) -> void:
	#print("inside _handle_button_press, is_inside_tree? ", is_inside_tree())
	#print("get_tree() == ", get_tree())
	var idx = current_index[mac]
	var btn = menu_items[idx]            # MenuItem-knapp
	var txt = btn.text                   # “Start”, “Pong” osv
	print("Button press handled for MAC:", mac, " Item:", txt)
	if txt == "Start":
		# Bekräfta valt spel
		if selected_game_index >= 1:
			match selected_game_index:
				1:
					if not ResourceLoader.exists("res://Scenes/pong.tscn"):
						push_error("COULD NOT FIND FILE")
						return
					#print("Försöker gå in tree")
					get_tree().change_scene_to_packed(pong_scene)
				2:
					if not ResourceLoader.exists("res://Scenes/draw.tscn"):
						push_error("COULD NOT FIND DRAW SCENE")
						return
					
					get_tree().change_scene_to_file("res://Scenes/draw.tscn")
				3:
					print("selected Not so cool game")
				4:
					print("selected draw.io")
		else:
			print("🚫 Inget spel valt – navigera till ett spel först!")
	else:
		# Det är ett spel-objekt → spara det i selected_game_index
		selected_game_index = idx
		print("✅ Valde spel:", txt)
		# (Frivilligt) sätt en visuell markering på just det spelet
		# t.ex. ändra outline-färg eller gör en blink-animation

func _update_all_blobs() -> void:
	var mac_map = WebSocketManager.get_active_macs_map()
	#var player_list_node = get_node("PanelContainer2/VBoxContainer2/VBoxContainer/playerList")
	for mac in mac_map.keys():
		var data = WebSocketManager.get_blob_data(mac)
		if data.is_empty():
			continue

		var joy_x: float = data.get("joystick_x", 0.0)
		var joy_y: float = -data.get("joystick_y", 0.0)
		var vel := Vector2(joy_x, joy_y)

		if not blobs.has(mac):
			var b = blob_scene.instantiate()
			add_child(b)
			b.position = get_viewport_rect().size / 2
			b.color = Color(mac_map[mac])
			b.mac = mac
			blobs[mac] = b
			current_index[mac] = 0
			last_axis_y[mac] = 0.0

		blobs[mac].set_velocity(vel)
		_navigate_menu(mac, vel)

		var pressed: bool = data.get("button_state", false)
		var was_pressed: bool = _last_button_state.get(mac, false)
		_last_button_state[mac] = pressed
		if pressed and not was_pressed:
			_handle_button_press(mac)
	
const MENU_NAV_THRESHOLD := 0.6

func _navigate_menu(mac:String, vel:Vector2) -> void:
	var axis := vel.y

	# 1) Initiera vid behov
	if not current_index.has(mac):
		current_index[mac] = 0

	var idx    = current_index[mac]
	var prev   = last_axis_y[mac]
	var new_idx = idx

	# 2) Debounce på Y-axeln
	if axis > MENU_NAV_THRESHOLD and prev <= MENU_NAV_THRESHOLD:
		new_idx = min(idx + 1, menu_items.size() - 1)
	elif axis < -MENU_NAV_THRESHOLD and prev >= -MENU_NAV_THRESHOLD:
		new_idx = max(idx - 1, 0)

	last_axis_y[mac] = axis

	# 3) Om index ändrats – snap & outline
	if new_idx != idx:
		current_index[mac] = new_idx
		blobs[mac].global_position = item_positions[new_idx]
		_update_outline(mac, new_idx)
		print("📌 %s hoppade till [%d] %s" %
			  [mac, new_idx, menu_items[new_idx].name])
		
func _update_outline(mac:String, idx:int) -> void:
	for item in menu_items:
		item.set_outline(Color.TRANSPARENT)
	menu_items[idx].set_outline(blobs[mac].color)
