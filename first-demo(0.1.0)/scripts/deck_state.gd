extends RefCounted
class_name DeckState


static func create_initial_deck() -> Array[Dictionary]:
	var deck: Array[Dictionary] = []
	var pairs := _get_initial_pairs()
	for i in range(pairs.size()):
		var card: Dictionary = pairs[i]
		deck.append({
			"id": str(i),
			"cardId": String(card.get("cardId", "")),
			"material": "bone",
		})
	return deck


static func _get_initial_pairs() -> Array:
	var pairs: Array = []
	var regular_tiles: Array = []
	regular_tiles.append_array(CardData.BAMS)
	regular_tiles.append_array(CardData.CRACKS)
	regular_tiles.append_array(CardData.DOTS)

	for card in regular_tiles:
		pairs.append(card)

	return pairs
