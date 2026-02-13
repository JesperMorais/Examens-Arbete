# Paddle.gd
extends ColorRect
var assigned_mac = ""
var sensitivity = 1.0
var current_roll = 0.0
var smooth_speed = 8.0 # Ju högre, desto snabbare (testa dig fram)
var target_x = 0.0


var _vp_size: Vector2

func _ready():
	_vp_size = get_viewport().size
	get_viewport().size_changed.connect(_on_viewport_resized)

func _on_viewport_resized():
	_vp_size = get_viewport().size

func _set_color(color_str):
	color = Color(color_str)

func update_roll(smoothed_roll):
	current_roll = smoothed_roll

func _process(delta):
	if assigned_mac == "":
		return
	var norm_x = clamp(current_roll / (PI/2.0), -1, 1)
	target_x = _vp_size.x/2 + norm_x * (_vp_size.x/2 - size.x/2) * sensitivity
	position.x = lerp(position.x, target_x, smooth_speed * delta)
