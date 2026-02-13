#player.gd
extends StaticBody2D

var win_height : int 
var p_height : int
const PLAYER_SPEED: float = 500
const SMOOTH_FACTOR: float = 10.0
var velocity: float = 0.0
var color = ""
var _was_pressed := false

@export var assigned_mac: String = ""
@export var is_cpu: bool = false

@onready var _ball: Node2D = $"../ball"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	win_height = get_viewport_rect().size.y
	p_height = $ColorRect.get_size().y
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if is_cpu:
		_process_cpu(delta)
	else:
		var data = WebSocketManager.get_blob_data(assigned_mac)
		
		var target_speed = -data.get("joystick_y", 0.0) * PLAYER_SPEED
		velocity = lerp(velocity, target_speed, 1.0 - exp(-SMOOTH_FACTOR * delta))
		position.y += velocity * delta
		position.y = clamp(position.y, p_height/2, win_height-p_height/2)
		var press: bool = data.get("button_state", false)
		if press and not _was_pressed:
			get_tree().change_scene_to_file("res://Scenes/menu_scene.tscn")
		_was_pressed = press
			
	# Hämta noden som tar emot sensor-data

func _process_cpu(delta: float) -> void:
	var dist = position.y - _ball.position.y
	var move_by = 0.0
	if abs(dist) > PLAYER_SPEED * delta:
		move_by = PLAYER_SPEED * delta * signf(dist)
	else:
		move_by = dist
		
	position.y -= move_by
	position.y = clamp(position.y, p_height/2, win_height-p_height/2)
