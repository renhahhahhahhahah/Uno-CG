extends Node

@onready var game_manager = get_parent()
@onready var player_hand = $"../PlayerHand"
@onready var bot_hands = [$"../Bot1Hand", $"../Bot2Hand", $"../Bot3Hand"]
@onready var discard_pile = $"../CenterContainer/HBoxContainer/DiscardPile"
@onready var draw_pile = $"../CenterContainer/HBoxContainer/DrawPile"
@onready var color_selector = $"../ColorSelector"
@onready var current_turn_label = $"../InfoPanel/HBoxContainer/CurrentTurn"
@onready var current_color_label = $"../InfoPanel/HBoxContainer/CurrentColor"
@onready var direction_label = $"../InfoPanel/HBoxContainer/DirectionLabel"
@onready var direction_arrow = $"../DirectionArrow"
@onready var draw_indicator = $"../DrawIndicator"
@onready var player_labels = [$"../Player1Label", $"../Player2Label", $"../Player3Label", $"../Player4Label"]

const CARD_WIDTH = 100
const CARD_HEIGHT = 150
const CARD_SPACING = -70
const SIDE_BOT_CARD_WIDTH = 150  # Wider for horizontal card design
const SIDE_BOT_CARD_HEIGHT = 100  # Shorter for horizontal card design
const SIDE_BOT_CARD_SPACING = -110  # Adjusted to match vertical card overlap ratio
const BOT_CARD_BACK = preload("res://Asset Lib/Deck.png")
const BOT_CARD_BACK_SIDE = preload("res://Asset Lib/Deck_Rotated.png")  # Vertical UNO text for left bot
const BOT_CARD_BACK_SIDE_OTHER = preload("res://Asset Lib/Deck_OtherRotated.png")  # Vertical UNO text for right bot
const BOT_CARD_BACK_UPSIDE = preload("res://Asset Lib/Deck_Upside.png")  # Upside down UNO text for top bot

func _ready():
	# Connect signals
	game_manager.connect("player_turn_started", _on_player_turn_started)
	game_manager.connect("game_state_changed", _on_game_state_changed)
	game_manager.connect("draw_penalty_changed", _on_draw_penalty_changed)
	
	# Connect color selector buttons
	for button in color_selector.get_children():
		button.pressed.connect(_on_color_selected.bind(button.text.to_lower()))
	
	# Hide draw indicator initially
	draw_indicator.hide()
	
	# Set bot hand spacing and sizes
	bot_hands[0].custom_minimum_size = Vector2(SIDE_BOT_CARD_HEIGHT, 400)  # Left bot - using height as width since rotated
	bot_hands[1].custom_minimum_size = Vector2(500, CARD_HEIGHT)  # Top bot - normal size
	bot_hands[2].custom_minimum_size = Vector2(SIDE_BOT_CARD_HEIGHT, 400)  # Right bot - using height as width since rotated
	
	# Ensure the containers are wide enough for the rotated cards
	bot_hands[0].size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bot_hands[2].size_flags_horizontal = Control.SIZE_SHRINK_END
	
	bot_hands[0].add_theme_constant_override("separation", SIDE_BOT_CARD_SPACING)
	bot_hands[1].add_theme_constant_override("separation", CARD_SPACING)  # Normal spacing for top
	bot_hands[2].add_theme_constant_override("separation", SIDE_BOT_CARD_SPACING)
	
	# Wait for next frame to ensure game manager is initialized
	await get_tree().process_frame
	
	# Initial UI update
	update_ui()

func update_ui():
	if not is_instance_valid(game_manager) or game_manager.players.size() == 0:
		return
	update_hands()
	update_piles()
	update_labels()
	update_draw_indicator()
	update_direction()

func update_direction():
	var direction_text = "Clockwise" if game_manager.direction == 1 else "Counter-Clockwise"
	direction_label.text = "Direction: " + direction_text
	direction_arrow.text = "↻" if game_manager.direction == 1 else "↺"

func update_draw_indicator():
	if game_manager.cards_to_draw > 0 and game_manager.current_player_index == 0:
		draw_indicator.text = "Draw " + str(game_manager.cards_to_draw) + " cards!"
		draw_indicator.show()
	else:
		draw_indicator.hide()

func _on_draw_penalty_changed(amount: int):
	if amount > 0 and game_manager.current_player_index == 0:
		draw_indicator.text = "Draw " + str(amount) + " cards!"
		draw_indicator.show()
	else:
		draw_indicator.hide()

func update_hands():
	# Clear all hands
	for child in player_hand.get_children():
		child.queue_free()
	for bot_hand in bot_hands:
		for child in bot_hand.get_children():
			child.queue_free()
	
	# Update player's hand (bottom)
	if game_manager.players.size() > 0:
		var player = game_manager.players[0]
		for card in player.hand:
			var card_button = TextureButton.new()
			if card.texture:
				card_button.texture_normal = card.texture
				card_button.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
				card_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				card_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				card_button.ignore_texture_size = true
				card_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
				card_button.mouse_filter = Control.MOUSE_FILTER_STOP
				card_button.visible = true
				card_button.modulate.a = 1.0  # Ensure full opacity
				card_button.pressed.connect(_on_card_pressed.bind(card))
				card_button.mouse_entered.connect(_on_card_hover_enter.bind(card_button))
				card_button.mouse_exited.connect(_on_card_hover_exit.bind(card_button))
				player_hand.add_child(card_button)
				# Force card to be visible
				card_button.show()
			else:
				print("Warning: Card texture is null for card in player's hand")
	
	# Update bot hands (left, top, right)
	for i in range(3):
		if game_manager.players.size() > i + 1:
			var bot = game_manager.players[i + 1]
			for _card in bot.hand:
				var card_texture = TextureRect.new()
				if i == 1:  # Top bot
					card_texture.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
				else:  # Side bots
					card_texture.custom_minimum_size = Vector2(SIDE_BOT_CARD_WIDTH, SIDE_BOT_CARD_HEIGHT)
				
				card_texture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				card_texture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				card_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				card_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
				card_texture.visible = true
				
				# Rotate all cards to point towards center
				if i == 0: # Left bot (Bot 1)
					card_texture.texture = BOT_CARD_BACK_SIDE
					card_texture.rotation_degrees = 90  # Rotate left side cards 90 degrees
					card_texture.pivot_offset = Vector2(SIDE_BOT_CARD_WIDTH/2, SIDE_BOT_CARD_HEIGHT/2)
				elif i == 1: # Top bot (Bot 2)
					card_texture.texture = BOT_CARD_BACK_UPSIDE
					card_texture.rotation_degrees = 180  # Rotate top cards 180 degrees
					card_texture.pivot_offset = Vector2(CARD_WIDTH/2, CARD_HEIGHT/2)
				elif i == 2: # Right bot (Bot 3)
					card_texture.texture = BOT_CARD_BACK_SIDE_OTHER
					card_texture.rotation_degrees = 450  # Rotate right side cards 450 degrees (270 + 180)
					card_texture.pivot_offset = Vector2(SIDE_BOT_CARD_WIDTH/2, SIDE_BOT_CARD_HEIGHT/2)
				
				bot_hands[i].add_child(card_texture)
				# Force card to be visible
				card_texture.show()

func _on_card_hover_enter(card_button: TextureButton):
	# Raise hovered card
	card_button.position.y = -20
	card_button.z_index = 1

func _on_card_hover_exit(card_button: TextureButton):
	# Lower card back to normal position
	card_button.position.y = 0
	card_button.z_index = 0

func update_piles():
	# Update discard pile
	if not game_manager.discard_pile.is_empty():
		var top_card = game_manager.discard_pile.back()
		if top_card and top_card.texture:
			discard_pile.texture = top_card.texture
			discard_pile.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
			discard_pile.show()
			print("Updated discard pile with: " + top_card.get_card_name())
			
			# Update color based on the top card if it's not a wild card waiting for color
			if not game_manager.waiting_for_color and (top_card.card_type != Card.CardType.WILD and top_card.card_type != Card.CardType.WILD_DRAW_FOUR):
				game_manager.current_color = top_card.color
		else:
			discard_pile.hide()
		print("No cards in discard pile")
	
	# Update draw pile
	if not game_manager.deck.is_empty():
		draw_pile.texture = BOT_CARD_BACK
		draw_pile.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
		draw_pile.show()
	else:
		draw_pile.hide()
	
	if not draw_pile.is_connected("gui_input", _on_draw_pile_clicked):
		draw_pile.gui_input.connect(_on_draw_pile_clicked)

func update_labels():
	if game_manager.players.size() > 0:
		var current_player = game_manager.players[game_manager.current_player_index]
		current_turn_label.text = "Current Turn: " + current_player.name
		
		# Get current color name
		var color_name = "Wild"
		if not game_manager.discard_pile.is_empty():
			var top_card = game_manager.discard_pile.back()
			if game_manager.waiting_for_color:
				color_name = "Choosing..."
			elif game_manager.current_color >= 0 and game_manager.current_color < Card.CardColor.size():
				color_name = Card.CardColor.keys()[game_manager.current_color].capitalize()
		
		current_color_label.text = "Current Color: " + color_name
		
		# Update color label appearance
		match game_manager.current_color:
			Card.CardColor.RED:
				current_color_label.add_theme_color_override("font_color", Color(1, 0, 0))
			Card.CardColor.BLUE:
				current_color_label.add_theme_color_override("font_color", Color(0, 0, 1))
			Card.CardColor.GREEN:
				current_color_label.add_theme_color_override("font_color", Color(0, 0.8, 0))
			Card.CardColor.YELLOW:
				current_color_label.add_theme_color_override("font_color", Color(1, 0.9, 0))
			_:
				current_color_label.add_theme_color_override("font_color", Color(1, 1, 1))
		
		# Update player labels
		for i in range(4):
			if i < game_manager.players.size():
				player_labels[i].text = game_manager.players[i].name
				player_labels[i].show()
			else:
				player_labels[i].hide()

func _on_card_pressed(card: Card):
	if game_manager.current_player_index == 0 and game_manager.can_play_card(card):
		game_manager.play_card(game_manager.players[0], card)
		if not game_manager.waiting_for_color:
			game_manager.next_turn()
		update_ui()

func _on_draw_pile_clicked(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if game_manager.current_player_index == 0:
			if game_manager.cards_to_draw > 0:
				game_manager.draw_penalty_cards(game_manager.players[0])
			else:
				game_manager.draw_card(game_manager.players[0])
				update_ui()
				
				var drawn_card = game_manager.players[0].hand.back()
				if game_manager.can_play_card(drawn_card):
					await get_tree().create_timer(0.5).timeout
					_on_card_pressed(drawn_card)
				else:
					game_manager.next_turn()

func _on_color_selected(color: String):
	var color_enum = Card.CardColor[color.to_upper()]
	game_manager.current_color = color_enum
	game_manager.waiting_for_color = false
	color_selector.hide()
	update_ui()
	game_manager.next_turn()

func _on_player_turn_started():
	update_ui()

func _on_game_state_changed():
	update_ui()
	
	if game_manager.waiting_for_color:
		color_selector.show()
	else:
		color_selector.hide() 
