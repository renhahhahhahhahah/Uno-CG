extends Control

@onready var progress_bar = $VBoxContainer/ProgressBar
@onready var loading_dots = $VBoxContainer/LoadingDots
@onready var loading_label = $VBoxContainer/LoadingLabel
@onready var yellow_reverse = $YellowReverse
@onready var red_reverse = $RedReverse
@onready var green_reverse = $GreenReverse
@onready var blue_reverse = $BlueReverse

var dots = ["", ".", "..", "..."]
var current_dot = 0
var loading_time = 0
var target_scene = "res://scenes/game.tscn"
var spin_speed = 2.0  # Rotations per second

func _ready():
	# Start the loading animation
	progress_bar.value = 0
	loading_dots.text = dots[0]
	
	# Create and start the loading timer
	var timer = Timer.new()
	timer.name = "LoadingTimer"
	timer.wait_time = 0.5
	timer.timeout.connect(_on_loading_timer_timeout)
	add_child(timer)
	timer.start()

func _process(delta):
	# Rotate the cards clockwise
	yellow_reverse.rotation += spin_speed * delta
	red_reverse.rotation += spin_speed * delta
	green_reverse.rotation += spin_speed * delta
	blue_reverse.rotation += spin_speed * delta

func _on_loading_timer_timeout():
	# Update loading dots animation
	current_dot = (current_dot + 1) % dots.size()
	loading_dots.text = dots[current_dot]
	
	# Simulate progress
	progress_bar.value = min(progress_bar.value + 5, 100)
	
	# If loading is complete, change to the game scene
	if progress_bar.value >= 100:
		$LoadingTimer.stop()
		get_tree().change_scene_to_file(target_scene) 
