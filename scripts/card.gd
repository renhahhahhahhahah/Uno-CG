extends Node2D

class_name Card

enum CardColor {RED, BLUE, GREEN, YELLOW, WILD}
enum CardType {NUMBER, SKIP, REVERSE, DRAW_TWO, WILD, WILD_DRAW_FOUR}

var color: CardColor
var card_type: CardType
var value: int = -1  # Only used for number cards
var texture: Texture2D
var face_up: bool = false

func _init(col: CardColor, type: CardType, val: int = -1):
	color = col
	card_type = type
	value = val
	_load_texture()
	
func _load_texture():
	var texture_path = "res://Asset Lib/"
	
	if card_type == CardType.WILD or card_type == CardType.WILD_DRAW_FOUR:
		texture_path += "Wild" + ("_Draw" if card_type == CardType.WILD_DRAW_FOUR else "") + ".png"
	else:
		var color_name = str(CardColor.keys()[color]).capitalize()
		texture_path += color_name + "_"
		
		match card_type:
			CardType.NUMBER:
				texture_path += str(value)
			CardType.SKIP:
				texture_path += "Skip"
			CardType.REVERSE:
				texture_path += "Reverse"
			CardType.DRAW_TWO:
				texture_path += "Draw"
		texture_path += ".png"
	
	print("Attempting to load card texture from: " + texture_path)
	texture = load(texture_path)
	if texture:
		print("Successfully loaded texture: " + texture_path)
	else:
		push_error("Failed to load card texture: " + texture_path)
		# Try to verify if the file exists
		var file = FileAccess.open(texture_path, FileAccess.READ)
		if file:
			print("File exists but failed to load as texture")
			file = null
		else:
			print("File does not exist at path: " + texture_path)

func can_play_on(top_card: Card) -> bool:
	if color == CardColor.WILD:
		return true
	if top_card.color == color:
		return true
	if card_type == CardType.NUMBER and top_card.card_type == CardType.NUMBER:
		return value == top_card.value
	if card_type == top_card.card_type:
		return true
	return false

func get_card_name() -> String:
	var col_name = CardColor.keys()[color].capitalize()
	match card_type:
		CardType.NUMBER:
			return col_name + " " + str(value)
		CardType.WILD, CardType.WILD_DRAW_FOUR:
			return CardType.keys()[card_type].capitalize().replace("_", " ")
		_:
			return col_name + " " + CardType.keys()[card_type].capitalize() 