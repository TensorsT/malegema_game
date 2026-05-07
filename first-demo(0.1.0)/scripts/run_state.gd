extends RefCounted
class_name RunState

const TUTORIAL_SEED := "tutorial-seed"
const ITEM_COST := 3
const ITEM_POOL_SIZE := 9
const ITEM_COUNT := 5
const REROLL_COST := 1

const PATHS := {
	"r": ["garnet", "ruby"],
	"g": ["jade", "emerald"],
	"b": ["topaz", "sapphire"],
	"k": ["quartz", "obsidian"],
}

const DIFFICULTY := {
	"easy": {
		"timer": {"exp": 1.02, "lin": 0.3},
		"point": {"initial": 40, "exp": 2.0, "lin": 5},
	},
	"medium": {
		"timer": {"exp": 1.05, "lin": 0.8},
		"point": {"initial": 40, "exp": 2.1, "lin": 10},
	},
	"hard": {
		"timer": {"exp": 1.1, "lin": 1.0},
		"point": {"initial": 40, "exp": 2.2, "lin": 15},
	},
}


static func initial_run_state(run_id: String) -> Dictionary:
	var difficulty := "easy"
	if run_id == TUTORIAL_SEED:
		difficulty = "easy"
	else:
		var letter := run_id.substr(0, 1)
		match letter:
			"E": difficulty = "easy"
			"M": difficulty = "medium"
			"H": difficulty = "hard"
			_: difficulty = "easy"

	var stage := "game"
	var tutorial_step = null
	if run_id == TUTORIAL_SEED:
		stage = "intro"
		tutorial_step = 1

	return {
		"runId": run_id,
		"money": 0,
		"round": 1,
		"stage": stage,
		"retries": 0,
		"attempts": 0,
		"difficulty": difficulty,
		"totalPoints": 0,
		"createdAt": int(Time.get_unix_time_from_system() * 1000.0),
		"items": [],
		"reroll": 0,
		"tutorialStep": tutorial_step,
	}


static func generate_round(round_id: int, run: Dictionary) -> Dictionary:
	var run_id := String(run.get("runId", ""))
	var rng := create_rng("round-%s-%d" % [run_id, round_id])
	var diff := String(run.get("difficulty", "easy"))
	var tuning: Dictionary = DIFFICULTY.get(diff, DIFFICULTY["easy"])
	var timer: Dictionary = tuning.get("timer", {})
	var point: Dictionary = tuning.get("point", {})

	var var1: float = _variation(rng)
	var var2: float = _variation(rng)
	var level := round_id - 1
	var timer_lin := float(timer.get("lin", 0.0))
	var timer_exp := float(timer.get("exp", 1.0))
	var point_initial := float(point.get("initial", 0.0))
	var point_lin := float(point.get("lin", 0.0))
	var point_exp := float(point.get("exp", 1.0))
	var timer_points: float = ((level * timer_lin + pow(timer_exp, level)) / 20.0) * var1
	var point_objective := int(round((point_initial + level * point_lin + pow(level, point_exp)) * var2))

	return {
		"id": round_id,
		"timerPoints": timer_points,
		"pointObjective": point_objective,
	}


static func _variation(rng: RandomNumberGenerator) -> float:
	var rand := rng.randf()
	return 1.0 + (rand * 2.0 - 1.0) * 0.1


static func calculate_income(run: Dictionary) -> int:
	return int(round(4.0 * sqrt(float(run.get("round", 1)))))


static func round_persistent_key(run: Dictionary) -> String:
	return "%s-%d" % [String(run.get("runId", "")), int(run.get("round", 1))]


static func get_levels(run_id: String) -> Array:
	var rng := create_rng(run_id)
	var non_black_dragons: Array = []
	var black_dragons: Array = []
	for card in CardData.DRAGONS:
		if String(card.get("rank", "")) == "k":
			black_dragons.append(card)
		else:
			non_black_dragons.append(card)

	var blue_shadow := _find_card(CardData.SHADOWS, "b")
	var red_shadow := _find_card(CardData.SHADOWS, "r")
	var green_shadow := _find_card(CardData.SHADOWS, "g")

	var first_sets := _shuffle_array([
		CardData.RABBITS,
		CardData.FROGS,
		CardData.LOTUSES,
		CardData.SPARROWS,
	], rng)
	var second_sets := _shuffle_array([
		CardData.FLOWERS,
		CardData.MUTATIONS,
		CardData.TAIJITU,
		CardData.PHOENIXES,
	], rng)
	var third_sets := _shuffle_array([
		CardData.ELEMENTS,
		CardData.GEMS,
		CardData.JOKERS,
		black_dragons,
	], rng)
	var extra_sets := _shuffle_array([
		CardData.BAMS,
		CardData.CRACKS,
		CardData.DOTS,
	], rng)

	return _create_levels([
		[0, [CardData.BAMS, CardData.CRACKS, CardData.DOTS]],
		[CardData.WINDS.size(), [CardData.WINDS]],
		[1, [non_black_dragons]],
		[0, [extra_sets[0]]],
		[1, [first_sets[0]]],
		[1, [first_sets[1]]],
		[0, []],
		[1, [first_sets[2]]],
		[1, [first_sets[3]]],
		[1, [[red_shadow]]],
		[0, [extra_sets[1]]],
		[1, [second_sets[0]]],
		[1, [second_sets[1]]],
		[1, [second_sets[2]]],
		[0, []],
		[1, [second_sets[3]]],
		[1, [[blue_shadow]]],
		[1, [third_sets[0]]],
		[0, [extra_sets[2]]],
		[1, [third_sets[1]]],
		[1, [third_sets[2]]],
		[1, [third_sets[3]]],
		[0, []],
		[1, [[green_shadow]]],
	])


static func generate_items(run: Dictionary, levels: Array) -> Array:
	var run_id := String(run.get("runId", ""))
	var round := int(run.get("round", 1))
	if run.has("freeze") and run["freeze"] != null:
		round = int(run["freeze"].get("round", round))

	var rng := create_rng("items-%s-%d" % [run_id, round])
	var item_ids := {}
	for item in run.get("items", []):
		item_ids[String(item.get("id", ""))] = true

	var initial_pool: Array = []
	for level in levels:
		if int(level.get("level", 0)) <= round:
			initial_pool.append_array(level.get("tileItems", []))

	if initial_pool.is_empty():
		return []

	var pool_size := initial_pool.size()
	var reroll := int(run.get("reroll", 0))
	if run.has("freeze") and run["freeze"] != null:
		reroll = int(run["freeze"].get("reroll", reroll))

	var start := (ITEM_COUNT * reroll) % pool_size
	var shuffled := _shuffle_array(initial_pool, rng)
	var filtered: Array = []
	for item in shuffled:
		if not item_ids.has(String(item.get("id", ""))):
			filtered.append(item)

	var items: Array = []
	for i in range(ITEM_COUNT):
		if filtered.is_empty():
			break
		var index := (start + i) % filtered.size()
		items.append(filtered[index])

	return items


static func get_next_materials(tiles: Array, path: String) -> Array:
	var count := _count_by_material(tiles)
	count["bone"] = int(count.get("bone", 0)) + 1
	var new_count := _merge_counts(count, path)

	var order := _material_order(path)
	var result: Array = []
	for material in order:
		var amount := int(new_count.get(material, 0))
		for i in range(amount):
			result.append(material)
	return result


static func get_next_material(tiles: Array, path: String) -> String:
	var materials := get_next_materials(tiles, path)
	if materials.is_empty():
		return "bone"
	return materials[materials.size() - 1]


static func get_transformation(tiles: Array, path: String) -> Dictionary:
	var next_materials := get_next_materials(tiles, path)
	var current_materials: Array = []
	for tile in tiles:
		current_materials.append(String(tile.get("material", "bone")))

	var updates: Dictionary = {}
	var removes: Array = []
	var adds := false

	for i in range(tiles.size()):
		var tile: Dictionary = tiles[i]
		var mat := ""
		if i < next_materials.size():
			mat = next_materials[i]
		if mat == "":
			removes.append(String(tile.get("id", "")))
			continue
		if mat != String(tile.get("material", "bone")):
			updates[String(tile.get("id", ""))] = mat

	for i in range(next_materials.size()):
		if i >= current_materials.size():
			adds = true

	return {"adds": adds, "updates": updates, "removes": removes}


static func buy_tile(run: Dictionary, item: Dictionary, deck: Array, reward: bool = false) -> bool:
	var cost := int(item.get("cost", 0))
	if reward:
		cost = 0
	var money := int(run.get("money", 0))
	if cost > money:
		return false

	run["money"] = money - cost
	run["items"].append(item)

	var id := _next_deck_id(deck)
	deck.append({
		"id": id,
		"cardId": String(item.get("cardId", "")),
		"material": "bone",
	})
	return true


static func upgrade_tile(run: Dictionary, item: Dictionary, deck: Array, path: String) -> bool:
	var cost := int(item.get("cost", 0))
	var money := int(run.get("money", 0))
	if cost > money:
		return false

	run["money"] = money - cost
	run["items"].append(item)

	var tiles := []
	for deck_tile in deck:
		if String(deck_tile.get("cardId", "")) == String(item.get("cardId", "")):
			tiles.append(deck_tile)

	var transformation := get_transformation(tiles, path)
	var updates: Dictionary = transformation["updates"]
	var removes: Array = transformation["removes"]

	for deck_tile in deck:
		var tile_id := String(deck_tile.get("id", ""))
		if updates.has(tile_id):
			deck_tile["material"] = updates[tile_id]

	if not removes.is_empty():
		for i in range(deck.size() - 1, -1, -1):
			if removes.has(String(deck[i].get("id", ""))):
				deck.remove_at(i)

	return true


static func create_rng(seed_key: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed_from_string(seed_key)
	return rng


static func _seed_from_string(value: String) -> int:
	return int(abs(value.hash()))


static func _create_levels(info: Array) -> Array:
	var levels: Array = []
	for level_index in range(info.size()):
		var entry: Array = info[level_index]
		var rewards := int(entry[0])
		var collections: Array = entry[1]
		var tile_items: Array = []

		for i in range(collections.size()):
			var cards: Array = collections[i]
			for j in range(cards.size()):
				var card: Dictionary = cards[j]
				for k in range(ITEM_POOL_SIZE):
					var card_id := String(card.get("cardId", ""))
					var suit_value := level_index - 1
					if _is_suit(card_id):
						suit_value = 1
					var cost := ITEM_COST + int(floor(float(suit_value) / 2.0))
					tile_items.append({
						"id": "%d-%d-%d-%d" % [level_index, i, j, k],
						"cardId": card_id,
						"type": "tile",
						"cost": cost,
					})

		levels.append({
			"level": level_index,
			"rewards": rewards,
			"tileItems": tile_items,
		})

	return levels


static func _shuffle_array(input: Array, rng: RandomNumberGenerator) -> Array:
	var arr: Array = input.duplicate(true)
	for i in range(arr.size() - 1, 0, -1):
		var j := int(floor(rng.randf() * float(i + 1)))
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
	return arr


static func shuffle_array(input: Array, rng: RandomNumberGenerator) -> Array:
	return _shuffle_array(input, rng)


static func _find_card(cards: Array, rank: String) -> Dictionary:
	for card in cards:
		if String(card.get("rank", "")) == rank:
			return card
	return {}


static func _is_suit(card_id: String) -> bool:
	var card := CardData.get_card_by_id(card_id)
	var suit := String(card.get("suit", ""))
	return suit == "bam" or suit == "crack" or suit == "dot"


static func _material_order(path: String) -> Array:
	var order := ["bone"]
	if PATHS.has(path):
		order.append_array(PATHS[path])
	return order


static func _count_by_material(tiles: Array) -> Dictionary:
	var count := {}
	for tile in tiles:
		var material: String = String(tile.get("material", "bone"))
		count[material] = int(count.get(material, 0)) + 1
	return count


static func _merge_counts(count: Dictionary, path: String) -> Dictionary:
	var order := _material_order(path)
	var new_count := count.duplicate(true)
	for i in range(order.size()):
		if i + 1 >= order.size():
			break
		var material: String = String(order[i])
		var next: String = String(order[i + 1])
		if not new_count.has(material):
			continue

		while int(new_count.get(material, 0)) >= 3:
			new_count[material] = int(new_count.get(material, 0)) - 3
			new_count[next] = int(new_count.get(next, 0)) + 1
			if int(new_count.get(material, 0)) == 0:
				new_count.erase(material)

	return new_count


static func _next_deck_id(deck: Array) -> String:
	var max_id := -1
	for tile in deck:
		var id_str := String(tile.get("id", ""))
		var id := int(id_str)
		if id > max_id:
			max_id = id
	return str(max_id + 1)
