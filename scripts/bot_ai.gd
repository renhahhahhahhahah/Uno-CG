extends Node

class_name BotAI

# Probability tables for Naive Bayes
var color_probabilities: Dictionary = {}
var type_probabilities: Dictionary = {}
var value_probabilities: Dictionary = {}

# Additional probability tables from new implementation
var color_likelihood: Dictionary = {}  # P(Player plays card | Color)
var value_likelihood: Dictionary = {}  # P(Player plays card | Value)

# Game state tracking
var cards_played: Array = []
var opponent_cards_count: Dictionary = {}
var known_opponent_cards: Dictionary = {}
var player_history: Array = []  # Track player's moves for better learning

func _init():
	_initialize_probabilities()

func _initialize_probabilities():
	# Initialize probability tables for colors
	for color in Card.CardColor.keys():
		color_probabilities[color] = 0.2  # Equal initial probability
		color_likelihood[color] = 0.25  # Equal initial likelihood
	
	# Initialize probability tables for card types
	for type in Card.CardType.keys():
		if type == "NUMBER":
			type_probabilities[type] = 0.6  # Numbers are more common
		else:
			type_probabilities[type] = 0.08  # Special cards are less common
	
	# Initialize probability tables for values (0-9)
	for i in range(10):
		value_probabilities[i] = 0.1  # Equal probability for each number
		value_likelihood[str(i)] = 0.1  # Equal initial likelihood

	# Initialize likelihood for special values
	for type in ["SKIP", "REVERSE", "DRAW_TWO", "WILD", "WILD_DRAW_FOUR"]:
		value_likelihood[type] = 0.1

func update_probabilities(played_card: Card):
	cards_played.append(played_card)
	player_history.append(played_card)  # Track for advanced learning
	
	# Update probabilities based on played card
	var total_cards = cards_played.size()
	
	# Update color probabilities
	for color in Card.CardColor.keys():
		var color_count = cards_played.count(func(card): return card.color == Card.CardColor[color])
		color_probabilities[color] = float(color_count) / total_cards
	
	# Update type probabilities
	for type in Card.CardType.keys():
		var type_count = cards_played.count(func(card): return card.card_type == Card.CardType[type])
		type_probabilities[type] = float(type_count) / total_cards
	
	# Update value probabilities for number cards
	var number_cards = cards_played.filter(func(card): return card.card_type == Card.CardType.NUMBER)
	var total_numbers = number_cards.size()
	if total_numbers > 0:
		for i in range(10):
			var value_count = number_cards.count(func(card): return card.value == i)
			value_probabilities[i] = float(value_count) / total_numbers
	
	# Update likelihood based on player history (from new implementation)
	if player_history.size() >= 2:
		var last_card = player_history[-2]  # Get second to last card
		var current_card = player_history[-1]  # Get last card
		
		# Update color likelihood
		if last_card.color == current_card.color:
			color_likelihood[Card.CardColor.keys()[current_card.color]] = 0.7  # Higher probability for matching color
		else:
			for color in Card.CardColor.keys():
				color_likelihood[color] = max(0.1, color_likelihood[color] * 0.9)  # Decay other probabilities
		
		# Update value likelihood
		var current_value = str(current_card.value) if current_card.card_type == Card.CardType.NUMBER else Card.CardType.keys()[current_card.card_type]
		var last_value = str(last_card.value) if last_card.card_type == Card.CardType.NUMBER else Card.CardType.keys()[last_card.card_type]
		
		if current_value == last_value:
			value_likelihood[current_value] = 0.7  # Higher probability for matching value
		else:
			for value in value_likelihood.keys():
				value_likelihood[value] = max(0.1, value_likelihood[value] * 0.9)  # Decay other probabilities

func choose_best_card(hand: Array, top_card: Card) -> Card:
	var playable_cards = hand.filter(func(card): return card.can_play_on(top_card))
	if playable_cards.is_empty():
		return null
		
	var best_card = null
	var highest_score = -1.0
	
	for card in playable_cards:
		var score = _calculate_card_score(card)
		if score > highest_score:
			highest_score = score
			best_card = card
	
	return best_card

func _calculate_card_score(card: Card) -> float:
	var score = 1.0
	
	# Color score incorporating both prior and likelihood
	var color_key = Card.CardColor.keys()[card.color]
	score *= color_probabilities[color_key] * (1 - color_likelihood[color_key])
	
	# Type score
	var type_key = Card.CardType.keys()[card.card_type]
	score *= type_probabilities[type_key]
	
	# Value score incorporating both prior and likelihood
	if card.card_type == Card.CardType.NUMBER:
		var value_key = str(card.value)
		score *= value_probabilities[card.value] * (1 - value_likelihood[value_key])
	else:
		score *= (1 - value_likelihood[type_key])
	
	# Enhanced special card scoring from new implementation
	if card.card_type == Card.CardType.WILD_DRAW_FOUR:
		score *= 2.0  # Highest priority for Wild Draw Four
	elif card.card_type == Card.CardType.WILD:
		score *= 1.5  # High priority for Wild
	elif card.card_type in [Card.CardType.SKIP, Card.CardType.REVERSE, Card.CardType.DRAW_TWO]:
		var opponents_with_few_cards = opponent_cards_count.values().count(func(count): return count <= 2)
		score *= (1.5 + (opponents_with_few_cards * 0.2))  # Enhanced bonus for special cards
	
	return score

func update_opponent_cards(player_id: int, card_count: int):
	opponent_cards_count[player_id] = card_count

func record_opponent_card(player_id: int, card: Card):
	if not known_opponent_cards.has(player_id):
		known_opponent_cards[player_id] = []
	known_opponent_cards[player_id].append(card)

# New helper function from the provided implementation
func choose_best_color(hand: Array) -> int:
	var color_counts = {}
	for color in Card.CardColor.keys():
		color_counts[color] = 0
	
	for card in hand:
		if card.color != Card.CardColor.WILD:  # Assuming WILD is the last color in the enum
			var color_key = Card.CardColor.keys()[card.color]
			color_counts[color_key] += 1
	
	var best_color = Card.CardColor.RED  # Default to red
	var max_count = 0
	
	for color in Card.CardColor.keys():
		if color_counts[color] > max_count:
			max_count = color_counts[color]
			best_color = Card.CardColor[color]
	
	return best_color 