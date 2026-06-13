extends Node

## PvPState — 对战状态管理器（Autoload）
## 房主权威：所有状态由房主（peer_id=1）维护和广播

const PHASE_WAITING := "waiting"
const PHASE_COUNTDOWN := "countdown"
const PHASE_PLAYING := "playing"
const PHASE_ENDED := "ended"

const BEST_OF := 3  # 三局两胜
const WIN_NEED := 2  # 需要赢 2 局

signal state_changed
signal score_updated(peer_id: int, score: int)
signal energy_updated(peer_id: int, energy: int)
signal phase_changed(new_phase: String)
signal round_over(winner_id: int, reason: String)
signal match_over(winner_id: int)

# ── 对局状态 ─────────────────────────────────────────────────
var phase: String = PHASE_WAITING
var round_number: int = 0
var board_seed: int = 0

# ── 双方数据 ─────────────────────────────────────────────────
# peer_id → 数值
var scores: Dictionary = {}       # {1: 0, 2: 0}
var energies: Dictionary = {}     # {1: 0, 2: 0}
var match_wins: Dictionary = {}   # {1: 0, 2: 0}
var tiles_cleared: Dictionary = {}  # {1: 0, 2: 0}

# ── 锁定牌 ──────────────────────────────────────────────────
# tile_id → peer_id（谁正在选这张牌）
var locked_tiles: Dictionary = {}

# ── 上次成功消除时间（连击判定） ────────────────────────────
var last_match_time: Dictionary = {}  # {peer_id: unix_time}

# ── 攻击冷却 ────────────────────────────────────────────────
var attack_cooldowns: Dictionary = {}  # {peer_id: cooldown_remaining}

# ── 超时追踪 ────────────────────────────────────────────────
var last_action_time: Dictionary = {}  # {peer_id: unix_time}
const IDLE_TIMEOUT := 15.0  # 15 秒无操作判负


func reset_for_new_match() -> void:
	phase = PHASE_WAITING
	round_number = 0
	board_seed = 0
	scores = {1: 0, 2: 0}
	energies = {1: 0, 2: 0}
	match_wins = {1: 0, 2: 0}
	tiles_cleared = {1: 0, 2: 0}
	locked_tiles.clear()
	last_match_time.clear()
	attack_cooldowns.clear()
	last_action_time.clear()
	state_changed.emit()


func reset_for_new_round() -> void:
	round_number += 1
	phase = PHASE_COUNTDOWN
	scores = {1: 0, 2: 0}
	energies = {1: 0, 2: 0}
	locked_tiles.clear()
	last_match_time.clear()
	attack_cooldowns = {1: 0.0, 2: 0.0}
	last_action_time.clear()
	var now: float = Time.get_ticks_msec() / 1000.0
	last_action_time = {1: now, 2: now}
	state_changed.emit()
	phase_changed.emit(PHASE_COUNTDOWN)


func start_playing() -> void:
	phase = PHASE_PLAYING
	state_changed.emit()
	phase_changed.emit(PHASE_PLAYING)


## ── 分数操作 ────────────────────────────────────────────────
func add_score(peer_id: int, amount: int) -> void:
	if not scores.has(peer_id):
		scores[peer_id] = 0
	scores[peer_id] += amount
	score_updated.emit(peer_id, scores[peer_id])
	state_changed.emit()


func get_score(peer_id: int) -> int:
	return scores.get(peer_id, 0)


## ── 能量操作 ────────────────────────────────────────────────
func add_energy(peer_id: int, amount: int) -> void:
	if not energies.has(peer_id):
		energies[peer_id] = 0
	energies[peer_id] += amount
	energy_updated.emit(peer_id, energies[peer_id])
	state_changed.emit()


func consume_energy(peer_id: int, amount: int) -> bool:
	if energies.get(peer_id, 0) < amount:
		return false
	energies[peer_id] -= amount
	energy_updated.emit(peer_id, energies[peer_id])
	state_changed.emit()
	return true


func get_energy(peer_id: int) -> int:
	return energies.get(peer_id, 0)


## ── 牌锁定 ──────────────────────────────────────────────────
func lock_tile(tile_id: String, peer_id: int) -> bool:
	if locked_tiles.has(tile_id):
		return false  # 已被别人锁定
	locked_tiles[tile_id] = peer_id
	state_changed.emit()
	return true


func unlock_tile(tile_id: String) -> void:
	locked_tiles.erase(tile_id)
	state_changed.emit()


func is_tile_locked(tile_id: String) -> bool:
	return locked_tiles.has(tile_id)


func get_tile_locker(tile_id: String) -> int:
	return locked_tiles.get(tile_id, 0)


func unlock_all_for_peer(peer_id: int) -> void:
	var to_remove: Array[String] = []
	for tile_id in locked_tiles.keys():
		if locked_tiles[tile_id] == peer_id:
			to_remove.append(tile_id)
	for tile_id in to_remove:
		locked_tiles.erase(tile_id)
	state_changed.emit()


## ── 连击检测 ────────────────────────────────────────────────
func record_match_time(peer_id: int) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	last_match_time[peer_id] = now


func is_combo(peer_id: int) -> bool:
	var last: float = last_match_time.get(peer_id, 0.0)
	var now: float = Time.get_ticks_msec() / 1000.0
	return (now - last) <= 5.0  # 5 秒内再次消除 = 连击


## ── 活动时间追踪 ────────────────────────────────────────────
func record_action(peer_id: int) -> void:
	last_action_time[peer_id] = Time.get_ticks_msec() / 1000.0


func is_idle(peer_id: int) -> bool:
	var last: float = last_action_time.get(peer_id, 0.0)
	var now: float = Time.get_ticks_msec() / 1000.0
	return (now - last) > IDLE_TIMEOUT


## ── 攻击冷却 ────────────────────────────────────────────────
func tick_cooldowns(delta: float) -> void:
	for peer_id in attack_cooldowns.keys():
		var current: float = attack_cooldowns.get(peer_id, 0.0)
		attack_cooldowns[peer_id] = maxf(0.0, current - delta)


func is_attack_on_cooldown(peer_id: int) -> bool:
	return attack_cooldowns.get(peer_id, 0.0) > 0.0


func start_attack_cooldown(peer_id: int, duration: float = 5.0) -> void:
	attack_cooldowns[peer_id] = duration


## ── 胜负判定 ────────────────────────────────────────────────
func check_round_end(tile_db: Dictionary) -> Dictionary:
	## 检查一局是否结束，返回 {"ended": bool, "winner_id": int, "reason": String}
	var alive_count: int = 0
	for tile in tile_db.values():
		if not bool((tile as Dictionary).get("deleted", false)):
			alive_count += 1

	if alive_count == 0:
		# 牌全部清空：分数高者赢
		var winner: int = _score_winner()
		return {"ended": true, "winner_id": winner, "reason": "empty-board"}

	# 检查无可消对
	var pairs: Array = GameLoop.get_available_pairs(tile_db)
	if pairs.is_empty():
		var winner: int = _score_winner()
		return {"ended": true, "winner_id": winner, "reason": "no-pairs"}

	# 检查挂机超时
	for peer_id in [1, 2]:
		if is_idle(peer_id):
			var other: int = 2 if peer_id == 1 else 1
			return {"ended": true, "winner_id": other, "reason": "idle-timeout"}

	return {"ended": false, "winner_id": 0, "reason": ""}


func resolve_round(winner_id: int, reason: String) -> void:
	phase = PHASE_ENDED
	if not match_wins.has(winner_id):
		match_wins[winner_id] = 0
	match_wins[winner_id] += 1
	state_changed.emit()
	round_over.emit(winner_id, reason)


func check_match_over() -> int:
	## 检查三局两胜是否结束，返回胜者 peer_id（0=还没结束）
	for peer_id in match_wins.keys():
		if match_wins[peer_id] >= WIN_NEED:
			match_over.emit(peer_id)
			return peer_id
	return 0


func _score_winner() -> int:
	var s1: int = scores.get(1, 0)
	var s2: int = scores.get(2, 0)
	if s1 > s2:
		return 1
	elif s2 > s1:
		return 2
	else:
		# 平局时比消除数
		var t1: int = tiles_cleared.get(1, 0)
		var t2: int = tiles_cleared.get(2, 0)
		if t1 >= t2:
			return 1
		return 2
