extends Node

const STAGE_INTRO := "intro"
const STAGE_GAME := "game"
const STAGE_REWARD := "reward"
const STAGE_SHOP := "shop"
const STAGE_END := "end"

const STAGE_SCENES := {
	STAGE_INTRO: "res://scene/gameStar.tscn",
	STAGE_GAME: "res://scene/board.tscn",
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


func start_new_run(run_id: String = "") -> void:
	if run_id == "":
		run_id = _generate_run_id()

	run = RunState.initial_run_state(run_id)
	deck = DeckState.create_initial_deck()
	levels = RunState.get_levels(run_id)
	last_round_result = {}


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
	return RunState.generate_round(int(run.get("round", 1)), run)


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
	return "%s-%d" % [letter, int(Time.get_unix_time_from_system())]
