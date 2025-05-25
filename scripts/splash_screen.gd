extends Control

@onready var animation_player = $AnimationPlayer
@onready var logo = $Logo
@onready var color_rect = $ColorRect

func _ready():
	print("Splash screen started")  # Debug print
	
	# Set initial states
	logo.modulate.a = 0
	color_rect.modulate.a = 1
	
	# Initial delay
	await get_tree().create_timer(2.0).timeout  # Increased initial delay
	
	# Create animation library
	var library = AnimationLibrary.new()
	animation_player.add_animation_library("", library)
	
	# Create fade-in animation
	var fade_in = Animation.new()
	var track_index = fade_in.add_track(Animation.TYPE_VALUE)
	fade_in.track_set_path(track_index, "Logo:modulate")
	fade_in.track_insert_key(track_index, 0.0, Color(1, 1, 1, 0))
	fade_in.track_insert_key(track_index, 4.0, Color(1, 1, 1, 1))  # Increased fade-in duration
	fade_in.length = 4.0
	
	# Add easing to the fade-in animation
	var curve = Curve.new()
	curve.add_point(Vector2(0, 0), 0, 0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
	curve.add_point(Vector2(0.2, 0.1), 0, 0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
	curve.add_point(Vector2(0.8, 0.9), 0, 0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
	curve.add_point(Vector2(1, 1), 0, 0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
	fade_in.track_set_interpolation_type(track_index, Animation.INTERPOLATION_CUBIC)
	fade_in.track_set_interpolation_loop_wrap(track_index, false)
	fade_in.track_set_key_transition(track_index, 0, 0.5)
	fade_in.track_set_key_transition(track_index, 1, 0.5)
	
	library.add_animation("fade_in", fade_in)
	
	# Create fade-out animation
	var fade_out = Animation.new()
	track_index = fade_out.add_track(Animation.TYPE_VALUE)
	fade_out.track_set_path(track_index, "Logo:modulate")
	fade_out.track_insert_key(track_index, 0.0, Color(1, 1, 1, 1))
	fade_out.track_insert_key(track_index, 3.0, Color(1, 1, 1, 0))  # Increased fade-out duration
	fade_out.length = 3.0
	library.add_animation("fade_out", fade_out)
	
	print("Starting fade-in animation")  # Debug print
	# Start the animation sequence
	animation_player.play("fade_in")
	await animation_player.animation_finished
	
	print("Fade-in complete, waiting...")  # Debug print
	# Wait for 4 seconds
	await get_tree().create_timer(0.6).timeout  # Increased display time
	
	print("Starting fade-out animation")  # Debug print
	# Fade out and change scene
	animation_player.play("fade_out")
	await animation_player.animation_finished
	
	print("Transitioning to main menu")  # Debug print
	# Change to main menu
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn") 
