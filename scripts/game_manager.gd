extends Node2D

# Game constants
const INITIAL_CARDS = 7
const BOT_THINK_TIME = 1.0

# Player management
var players = []
var current_player_index = 0
var direction = 1  # 1 for clockwise, -1 for counter-clockwise

# Game state
var deck = []
var discard_pile = []
var game_started = false
var waiting_for_color = false
var current_color = Card.CardColor.RED
var cards_to_draw = 0  # Track how many cards need to be drawn
var finished_players = []  # Track players who have finished
var active_players = []  # Track players still in game

# Signals
signal game_state_changed
signal player_turn_started
signal draw_penalty_changed(amount: int)  # New signal for draw penalties

# Bot AI instances
var bot_ais = []

func _ready():
	# Make this scene the main scene if it's run directly
	if get_parent() == null:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	else:
		setup_game()

func setup_game():
	# Initialize deck
	create_deck()
	
	# Create players (1 human + 3 bots)
	players = []
	bot_ais = []
	finished_players = []
	active_players = []
	
	# Human player
	players.append({
		"hand": [],
		"is_bot": false,
		"name": "Player"
	})
	
	# Add 3 bots
	for i in range(3):
		var bot_ai = BotAI.new()
		bot_ais.append(bot_ai)
		players.append({
			"hand": [],
			"is_bot": true,
			"name": "Bot " + str(i + 1),
			"ai": bot_ai
		})
	
	# Set active players
	active_players = players.duplicate()
	
	# Deal initial cards
	deal_initial_cards()
	emit_signal("game_state_changed")
	
	# Start game
	start_game()

func create_deck():
	deck = []
	
	# Add number cards (0-9)
	for color in range(4):  # Excluding WILD color
		# One zero card per color
		deck.append(Card.new(color, Card.CardType.NUMBER, 0))
		
		# One card each for numbers 1-9
		for number in range(1, 10):
			deck.append(Card.new(color, Card.CardType.NUMBER, number))
		
		# Add special cards (1 each per color)
		deck.append(Card.new(color, Card.CardType.SKIP))
		deck.append(Card.new(color, Card.CardType.REVERSE))
		deck.append(Card.new(color, Card.CardType.DRAW_TWO))
	
	# Add wild cards (2 of each type)
	for _i in range(2):
		deck.append(Card.new(Card.CardColor.WILD, Card.CardType.WILD))
		deck.append(Card.new(Card.CardColor.WILD, Card.CardType.WILD_DRAW_FOUR))
	
	# Shuffle deck
	deck.shuffle()

func deal_initial_cards():
	print("Dealing initial cards...")
	for _i in range(INITIAL_CARDS):
		for player in players:
			if deck.size() > 0:
				var card = deck.pop_back()
				player.hand.append(card)
				print("Dealt " + card.get_card_name() + " to " + player.name)
	
	# Place first card
	var initial_card = deck.pop_back()
	while initial_card.card_type in [Card.CardType.WILD, Card.CardType.WILD_DRAW_FOUR]:
		deck.push_front(initial_card)
		deck.shuffle()
		initial_card = deck.pop_back()
	
	discard_pile.append(initial_card)
	current_color = initial_card.color
	print("Initial card: " + initial_card.get_card_name())
	print("Deck size after dealing: " + str(deck.size()))
	emit_signal("game_state_changed")

func draw_card(player):
	if deck.is_empty():
		reshuffle_discard_pile()
	
	if deck.is_empty():
		print("Deck is completely empty! Game Over!")
		end_game()
		return null
		
	var card = deck.pop_back()
	player.hand.append(card)
	print(player.name + " drew " + card.get_card_name())
	emit_signal("game_state_changed")
	return card

func reshuffle_discard_pile():
	print("Reshuffling discard pile...")
	if discard_pile.size() > 1:
		var top_card = discard_pile.pop_back()
		deck = discard_pile.duplicate()
		discard_pile = [top_card]
		deck.shuffle()
		print("New deck size after reshuffle: " + str(deck.size()))
		emit_signal("game_state_changed")
	else:
		print("Not enough cards to reshuffle!")

func start_game():
	game_started = true
	current_player_index = 0
	process_turn()

func process_turn():
	if active_players.is_empty():
		return
		
	var current_player = active_players[current_player_index]
	print("Processing turn for " + current_player.name)
	
	if cards_to_draw > 0 and not current_player.is_bot:
		emit_signal("draw_penalty_changed", cards_to_draw)
	
	if current_player.is_bot:
		await get_tree().create_timer(BOT_THINK_TIME).timeout
		process_bot_turn(current_player)
	else:
		# Human turn is handled by UI input
		emit_signal("player_turn_started")
	
	emit_signal("game_state_changed")

func process_bot_turn(bot):
	var top_card = discard_pile.back()
	var chosen_card = null
	
	# If there's a draw penalty, try to play a matching draw card first
	if cards_to_draw > 0:
		for card in bot.hand:
			if (card.card_type == Card.CardType.DRAW_TWO and top_card.card_type == Card.CardType.DRAW_TWO) or \
			   (card.card_type == Card.CardType.WILD_DRAW_FOUR and top_card.card_type == Card.CardType.WILD_DRAW_FOUR):
				chosen_card = card
				break
		
		if not chosen_card:
			draw_penalty_cards(bot)
			return
	
	# Normal turn logic
	if not chosen_card:
		chosen_card = bot.ai.choose_best_card(bot.hand, top_card)
	
	if chosen_card and can_play_card(chosen_card):
		print(bot.name + " playing " + chosen_card.get_card_name())
		play_card(bot, chosen_card)
		if not waiting_for_color:
			next_turn()
	else:
		print(bot.name + " drawing a card")
		draw_card(bot)
		
		# Try to play the drawn card
		if not bot.hand.is_empty():
			chosen_card = bot.ai.choose_best_card([bot.hand.back()], top_card)
			if chosen_card and can_play_card(chosen_card):
				print(bot.name + " playing drawn card: " + chosen_card.get_card_name())
				play_card(bot, chosen_card)
				if not waiting_for_color:
					next_turn()
			else:
				next_turn()

func play_card(player, card):
	player.hand.erase(card)
	discard_pile.append(card)
	print(player.name + " played " + card.get_card_name())
	
	# Check if player has finished - this is now a win condition
	if player.hand.is_empty():
		print(player.name + " has won the game!")
		handle_player_finished(player)
		return
	
	# Check if deck is empty after playing
	if deck.is_empty() and discard_pile.size() <= 1:
		print("No more cards available! Game ending...")
		end_game()
		return
	
	# Update current color immediately unless it's a wild card waiting for color selection
	if card.card_type != Card.CardType.WILD and card.card_type != Card.CardType.WILD_DRAW_FOUR:
		current_color = card.color
	
	# Update AI probabilities
	for bot_ai in bot_ais:
		bot_ai.update_probabilities(card)
	
	# Handle special cards
	match card.card_type:
		Card.CardType.SKIP:
			current_player_index = (current_player_index + direction) % active_players.size()
			print("Skip! Next player will be skipped")
		Card.CardType.REVERSE:
			direction *= -1
			print("Reverse! Direction changed")
		Card.CardType.DRAW_TWO:
			cards_to_draw += 2
			emit_signal("draw_penalty_changed", cards_to_draw)
			print("Draw 2 played! Total cards to draw: " + str(cards_to_draw))
		Card.CardType.WILD:
			if player.is_bot:
				choose_bot_wild_color(player)
			else:
				waiting_for_color = true
		Card.CardType.WILD_DRAW_FOUR:
			cards_to_draw += 4
			emit_signal("draw_penalty_changed", cards_to_draw)
			print("Draw 4 played! Total cards to draw: " + str(cards_to_draw))
			if player.is_bot:
				choose_bot_wild_color(player)
			else:
				waiting_for_color = true
	
	emit_signal("game_state_changed")

func handle_player_finished(player):
	# Add the winning player to finished players first
	finished_players.append(player)
	
	# Remove player from active players
	var player_index = active_players.find(player)
	if player_index != -1:
		active_players.remove_at(player_index)
		
		# Adjust current player index if needed
		if player_index <= current_player_index:
			current_player_index = max(0, current_player_index - 1)
	
	# End game immediately as we have a winner
	end_game()

func check_game_end():
	# End game if deck is empty or only one player remains
	if deck.is_empty() or active_players.size() <= 1:
		end_game()

func end_game():
	# Sort remaining players by card count
	var remaining_players = active_players.duplicate()
	remaining_players.sort_custom(func(a, b): return a.hand.size() < b.hand.size())
	
	# If we have finished players (someone won by playing all cards), they stay in order
	# Otherwise, rank everyone by card count
	var final_rankings = []
	if finished_players.size() > 0:
		final_rankings = finished_players + remaining_players
	else:
		final_rankings = remaining_players
	
	print("\nGame Over! Final Rankings:")
	for i in range(final_rankings.size()):
		var player = final_rankings[i]
		var place = ["1st", "2nd", "3rd", "4th"][i]
		print("%s Place: %s (%d cards)" % [place, player.name, player.hand.size()])
	
	# Load game over scene
	var game_over_scene = load("res://scenes/game_over.tscn").instantiate()
	game_over_scene.set_rankings(final_rankings)
	get_tree().root.add_child(game_over_scene)
	queue_free()

func next_turn():
	if not waiting_for_color:
		current_player_index = (current_player_index + direction) % active_players.size()
		process_turn()

func draw_penalty_cards(player):
	if cards_to_draw > 0:
		print(player.name + " drawing " + str(cards_to_draw) + " penalty cards")
		for i in range(cards_to_draw):
			draw_card(player)
		cards_to_draw = 0
		emit_signal("draw_penalty_changed", 0)
		next_turn()
		return true
	return false

func can_play_card(card: Card) -> bool:
	if cards_to_draw > 0:
		# Can only play a Draw Two on a Draw Two, or a Draw Four on a Draw Four
		var top_card = discard_pile.back()
		if card.card_type == Card.CardType.WILD_DRAW_FOUR and top_card.card_type == Card.CardType.WILD_DRAW_FOUR:
			return true
		if card.card_type == Card.CardType.DRAW_TWO and top_card.card_type == Card.CardType.DRAW_TWO:
			return true
		return false
		
	if discard_pile.is_empty():
		return true
		
	var top_card = discard_pile.back()
	return card.can_play_on(top_card) or card.color == current_color

func choose_bot_wild_color(bot):
	# Bot chooses most common color in its hand
	var color_counts = {}
	for hand_card in bot.hand:
		if hand_card.color != Card.CardColor.WILD:
			color_counts[hand_card.color] = color_counts.get(hand_card.color, 0) + 1
	
	var max_color = Card.CardColor.RED
	var max_count = 0
	for color in color_counts:
		if color_counts[color] > max_count:
			max_color = color
			max_count = color_counts[color]
	
	current_color = max_color
	waiting_for_color = false

func _on_color_selected(color: String):
	var color_enum = Card.CardColor[color.to_upper()]
	current_color = color_enum
	waiting_for_color = false
	print("Color selected: " + color)
	emit_signal("game_state_changed")
	next_turn() 
