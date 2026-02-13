#node.gd
#handles websocket data mainly
extends Node

# Ange websocket-URL:en (inkludera ws:// och porten)
@export var websocket_url: String = "ws://localhost:8080/ws"
var player_list_node_txt: ItemList  # ← den andra ItemList för ms-text
var player_list_node = null
var current_scene_ref

var active_mac_map: Dictionary  = {}
var blob_data: Dictionary = {} # STORES RELATED DATA from all macs
var _ui_macs: Dictionary = {} # mac -> true, fast duplicate check for player list

var roll_history_per_mac = {}   # mac -> Array[float]
var offset_per_mac = {}         # mac -> float
var calibration_count = {}
var roll_calib_sum = {}

const HISTORY_SIZE = 50
const CALIB_SAMPLES = 30
var _mac_regex := RegEx.new()

var _smoothed_roll_cache: Dictionary = {} # mac -> float

func get_smoothed_roll(mac: String) -> float:
	return _smoothed_roll_cache.get(mac, 0.0)

func _update_smoothed_roll(mac: String) -> void:
	var hist = roll_history_per_mac.get(mac)
	if hist == null or hist.size() == 0:
		return
	var arr = hist.duplicate()
	arr.sort()
	var mid: int = arr.size() / 2
	if arr.size() % 2 == 1:
		_smoothed_roll_cache[mac] = arr[mid]
	else:
		_smoothed_roll_cache[mac] = (arr[mid - 1] + arr[mid]) / 2.0
	
var latency_samples : Dictionary = {}
var _latency_sums : Dictionary = {} # mac -> int (running sum)
var _refresh_dirty : bool = false
var _refresh_cooldown : float = 0.0
const REFRESH_INTERVAL : float = 0.5

var drawing_scene = null

func register_drawing_scene(scene):
	drawing_scene = scene

func register_player_list_txt(node: ItemList) -> void:
	player_list_node_txt = node

func update_blob_data(data: Dictionary) -> void:
	var mac = data.get("mac_address", "")
	if mac != "":
		var ay := float(data.get("accel_x", 0.0))
		var az := float(data.get("accel_z", 0.0))
		var roll := atan2(-ay, az)

		if not roll_history_per_mac.has(mac):
			roll_history_per_mac[mac] = []
			roll_calib_sum[mac] = 0.0
			calibration_count[mac] = 0
			offset_per_mac[mac] = 0.0

		var count: int = calibration_count[mac]
		if count < CALIB_SAMPLES:
			roll_calib_sum[mac] += roll
			count += 1
			calibration_count[mac] = count
			if count == CALIB_SAMPLES:
				offset_per_mac[mac] = roll_calib_sum[mac] / CALIB_SAMPLES
		else:
			var hist: Array = roll_history_per_mac[mac]
			hist.append(roll - offset_per_mac[mac])
			if hist.size() > HISTORY_SIZE:
				hist.pop_front()
			_update_smoothed_roll(mac)
				
		blob_data[mac] = data
		_add_latency_sample(mac)
		_refresh_dirty = true

		if drawing_scene:
			drawing_scene._on_sensor_data(mac, data)

func _add_latency_sample(mac: String) -> void:
	var d = blob_data[mac]
	var sent   = int(d.get("sent_timestamp_ms", 0))
	#var server = int(d.get("server_time_ms",   0))
	var now_sec = Time.get_unix_time_from_system()
	var now_ms = int(now_sec * 1000)
	var total  = now_ms - sent
	if not latency_samples.has(mac):
		latency_samples[mac] = []
		_latency_sums[mac] = 0
	var arr = latency_samples[mac]
	arr.append(total)
	_latency_sums[mac] += total
	if arr.size() > 100:
		_latency_sums[mac] -= arr.pop_front()

func _refresh_player_list()-> void:
	if player_list_node_txt == null:
		return
	player_list_node_txt.clear()
	
	for mac in active_mac_map.keys():
		if not latency_samples.has(mac) or latency_samples[mac].size() == 0:
			player_list_node_txt.add_item("%s – … ms" % mac)
		else:
			var avg = int(_latency_sums[mac] / latency_samples[mac].size())
			player_list_node_txt.add_item("%s – avg %d ms" % [mac, avg])
	

func get_blob_data(mac: String) -> Dictionary:
	if blob_data.has(mac):
		return blob_data[mac]
	return {}

func update_mac_map(mac: String, _color: String) -> void:
	if active_mac_map.has(mac):
		return # It already exists
	#it didnt exist
	print("added "+ mac +" to list with color ", _color)
	active_mac_map[mac] = _color

#retunerar map och macs
func get_active_macs_map() -> Dictionary:
	return active_mac_map

func set_current_scene(scene):
	current_scene_ref = scene

var _color_icons := {
	"red": preload("res://assets/RÖD.png"),
	"blue": preload("res://assets/BLÅ.png"),
	"green": preload("res://assets/GRÖN.png"),
}

func register_player_list(node):
	player_list_node = node
	
# Skapa en WebSocketPeer-instans
var socket: WebSocketPeer = WebSocketPeer.new()
var _json_parser := JSON.new()

var color = "blue"

func _ready() -> void:
	_mac_regex.compile("^([0-9A-F]{2}:){5}[0-9A-F]{2}$")
	var err = socket.connect_to_url(websocket_url)
	if err != OK:
		print("Kunde inte ansluta till websocket på ", websocket_url)
		set_process(false)
	else:
		print("Ansluten till websocket på ", websocket_url)

func _process(_delta: float) -> void:
	# Throttled UI refresh
	_refresh_cooldown -= _delta
	if _refresh_dirty and _refresh_cooldown <= 0.0:
		_refresh_player_list()
		_refresh_dirty = false
		_refresh_cooldown = REFRESH_INTERVAL

	socket.poll()
	var state = socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		# Medan det finns meddelanden i kön, hämta dem.
		while socket.get_available_packet_count() > 0:
			var received: String = socket.get_packet().get_string_from_utf8()
			var parse_error = _json_parser.parse(received)

			if parse_error == OK:
				var data = _json_parser.get_data()
				
				if typeof(data) == TYPE_DICTIONARY:
					if data.has("color"):
						color = data["color"]
					update_blob_data(data)
					if data.has("mac_address"):
						var mac_addr = data["mac_address"]
						if typeof(mac_addr) == TYPE_STRING:
							update_mac_map(mac_addr, color)
							update_mac_list_ui(mac_addr, color)
				else:
					print("Ogiltigt dataformat (ej dictionary): ", received)
			else:
				print("Kunde inte parsa JSON: ", received)

	elif state == WebSocketPeer.STATE_CLOSING:
		# Hantera ev. stängningslogik om du vill.
		pass
	elif state == WebSocketPeer.STATE_CLOSED:
		var code = socket.get_close_code()
		print("WebSocket stängd med kod: %d. Clean: %s" % [code, code != -1])
		set_process(false)

func is_valid_mac_address(mac: String) -> bool:
	# Must be 17 chars long (XX:XX:XX:XX:XX:XX)
	if mac.length() != 17:
		return false
		
	if !_mac_regex.search(mac):
		return false
		
	# Not all zeros
	if mac == "00:00:00:00:00:00":
		return false
		
	# Not broadcast
	if mac == "FF:FF:FF:FF:FF:FF":
		return false
		
	return true

#lägger till nya macaddresser i listan
func update_mac_list_ui(mac_address: String, device_color: String) -> void:
	#FINNS LISTAN AV SPELARE
	if player_list_node:
		# Validate the MAC address - reject invalid formats and all-zeros
		if !is_valid_mac_address(mac_address):
			return

		if _ui_macs.has(mac_address):
			return
		_ui_macs[mac_address] = true
		var icon = _color_icons.get(device_color, _color_icons["green"])
		player_list_node.add_item(mac_address, icon, true)
		print("Added player with MAC: " + mac_address + " (" + device_color + ")")
