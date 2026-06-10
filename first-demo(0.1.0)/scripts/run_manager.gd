extends Node

const STAGE_INTRO := "intro"
const STAGE_GAME := "game"
const STAGE_SETTLEMENT := "settlement"
const STAGE_REWARD := "reward"
const STAGE_SHOP := "shop"
const STAGE_END := "end"

const STAGE_SCENES := {
	STAGE_INTRO: "res://scene/tutorial.tscn",
	STAGE_GAME: "res://scene/board.tscn",
	STAGE_SETTLEMENT: "res://scene/run_end.tscn",
	STAGE_REWARD: "res://scene/run_reward.tscn",
	STAGE_SHOP: "res://scene/run_shop.tscn",
	STAGE_END: "res://scene/run_end.tscn",
}

var run: Dictionary = {}
var deck: Array[Dictionary] = []
var levels: Array = []
var last_round_result: Dictionary = {}


func has_active_run() -> bool:
	return not run.is_empty()


func ensure_deck_initialized() -> void:
	if deck.is_empty():
		deck = DeckState.create_initial_deck()


func start_new_run(run_id: String = "") -> void:
	if run_id == "":
		run_id = _generate_run_id()

	run = RunState.initial_run_state(run_id)
	deck = DeckState.create_initial_deck()
	levels = RunState.get_levels(run_id)
	last_round_result = {}


func start_tutorial() -> void:
	start_new_run(RunState.TUTORIAL_SEED)


func enter_stage(stage: String) -> void:
	if not has_active_run():
		return
	if not STAGE_SCENES.has(stage):
		return

	run["stage"] = stage
	get_tree().change_scene_to_file(String(STAGE_SCENES[stage]))


func get_round() -> Dictionary:
	if not has_active_run():
		return {}
	var round := RunState.generate_round(int(run.get("round", 1)), run)
	var run_id := String(run.get("runId", ""))
	var round_id := int(run.get("round", 1))
	var max_points_map: Dictionary = run.get("roundMaxPoints", {}) as Dictionary

	if run_id != "":
		var key := "%s-%d" % [run_id, round_id]
		# 棋盘最大可得分（从 _remember_round_max_points 写入）
		var table_max := int(max_points_map.get(key, 0))
		# 牌组牌力估算（基于 deck 的基础分 + 材质加成）
		var deck_power := _estimate_deck_power()

		if table_max > 0:
			# 动态目标分：棋盘最高分的 75%~90%，根据牌力微调
			# 牌力越高 → 要求越高（乘数越大），但上限 90%
			var power_factor := clampf(0.75 + deck_power * 0.002, 0.75, 0.90)
			var dynamic_objective := int(ceil(table_max * power_factor))
			# 取公式值和动态值的较小者，确保目标分永远可达成
			round["pointObjective"] = mini(int(round.get("pointObjective", 0)), dynamic_objective)

	return round


## 估算牌组牌力：每张牌的基础分 + 材质加成之和
func _estimate_deck_power() -> int:
	if deck.is_empty():
		return 0
	var total := 0
	for tile: Dictionary in deck:
		var card_id := String(tile.get("cardId", ""))
		var material := String(tile.get("material", "bone"))
		var card := CardData.get_card_by_id(card_id)
		var card_points := int(card.get("points", 0))
		var material_points := _material_point_value(material)
		total += card_points + material_points
	return total


## 材质分查表（与 GameLoop._get_material_points 保持一致）
static func _material_point_value(material: String) -> int:
	match material:
		"topaz", "quartz", "garnet":
			return 1
		"jade":
			return 2
		"sapphire", "obsidian", "ruby":
			return 24
		"emerald":
			return 48
		_:
			return 0


func get_round_rng() -> RandomNumberGenerator:
	if not has_active_run():
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		return rng
	var seed_key := "round-%s-%d" % [String(run.get("runId", "")), int(run.get("round", 1))]
	return RunState.create_rng(seed_key)


func get_levels() -> Array:
	return levels


func get_items() -> Array:
	return RunState.generate_items(run, levels)


func evaluate_round(game_state: Dictionary) -> Dictionary:
	if not has_active_run():
		return {}

	var round_info := get_round()
	var points := int(game_state.get("points", 0))
	var time := float(game_state.get("time", 0.0))
	var coins := int(game_state.get("coins", 0))
	var timer_points := float(round_info.get("timerPoints", 0.0))
	var penalty := time * timer_points
	var total_points := int(round(points - penalty))
	var objective := int(round_info.get("pointObjective", 0))
	var end_condition := String(game_state.get("end_condition", ""))
	var win := end_condition == "empty-board" and total_points >= objective
	var achievement := 0.0
	if objective > 0:
		achievement = float(total_points) / float(objective)
	var over_achievement := achievement - 1.0
	var over_achievement_coins := 0
	if over_achievement > 0.0:
		over_achievement_coins = min(int(floor(over_achievement * 2.0)), 12)

	var income := RunState.calculate_income(run)
	var next_stage := _next_round_stage()

	last_round_result = {
		"points": points,
		"time": time,
		"penalty": penalty,
		"totalPoints": total_points,
		"objective": objective,
		"coins": coins,
		"income": income,
		"overAchievementCoins": over_achievement_coins,
		"win": win,
		"round": int(run.get("round", 1)),
		"endCondition": end_condition,
		"nextStage": next_stage,
	}

	return last_round_result


func advance_after_win() -> void:
	if last_round_result.is_empty():
		return
	if not bool(last_round_result.get("win", false)):
		return

	var income := int(last_round_result.get("income", 0))
	var coins := int(last_round_result.get("coins", 0))
	var bonus := int(last_round_result.get("overAchievementCoins", 0))
	var total_points := int(last_round_result.get("totalPoints", 0))
	var next_stage := String(last_round_result.get("nextStage", STAGE_END))

	run["money"] = int(run.get("money", 0)) + income + coins + bonus
	run["totalPoints"] = int(run.get("totalPoints", 0)) + total_points
	run["stage"] = next_stage


func retry_round() -> void:
	run["retries"] = int(run.get("retries", 0)) + 1
	last_round_result = {}


func advance_to_next_round() -> void:
	run["round"] = int(run.get("round", 1)) + 1
	run["stage"] = STAGE_GAME
	last_round_result = {}


func apply_reward_items(items: Array) -> void:
	for item in items:
		RunState.buy_tile(run, item, deck, true)


func _next_round_stage() -> String:
	var round_id := int(run.get("round", 1))
	for level in levels:
		if int(level.get("level", -1)) == round_id:
			if int(level.get("rewards", 0)) > 0:
				return STAGE_REWARD
			return STAGE_SHOP
	return STAGE_END


func _generate_run_id() -> String:
	var letter := "E"
	var ms := int(Time.get_unix_time_from_system() * 1000.0)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var salt := rng.randi_range(1000, 9999)
	return "%s-%d-%d" % [letter, ms, salt]
