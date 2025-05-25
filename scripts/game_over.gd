extends Control

@onready var first_place = %FirstPlace
@onready var second_place = %SecondPlace
@onready var third_place = %ThirdPlace
@onready var fourth_place = %FourthPlace
@onready var play_again_button = $VBoxContainer/PlayAgainButton
@onready var main_menu_button = $VBoxContainer/MainMenuButton

func _ready():
	play_again_button.pressed.connect(_on_play_again_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)

func set_rankings(rankings: Array):
	var medal_emojis = ["🥇", "🥈", "🥉", ""]
	var place_labels = [first_place, second_place, third_place, fourth_place]
	var place_names = ["1st", "2nd", "3rd", "4th"]
	
	# Make sure we have all our labels
	if not first_place or not second_place or not third_place or not fourth_place:
		push_error("Game Over scene: Missing place labels!")
		return
	
	print("Setting rankings for " + str(rankings.size()) + " players")
	
	for i in range(rankings.size()):
		var player_name = rankings[i].name
		var cards_left = rankings[i].hand.size()
		var text = "%s %s Place: %s" % [medal_emojis[i], place_names[i], player_name]
		if cards_left > 0:
			text += " (%d cards)" % cards_left
		place_labels[i].text = text
		place_labels[i].show()
	
	# Hide unused labels
	for i in range(rankings.size(), place_labels.size()):
		place_labels[i].hide()

func _on_play_again_pressed():
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_main_menu_pressed():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn") 
