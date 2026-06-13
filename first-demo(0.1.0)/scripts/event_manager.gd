extends RefCounted
class_name EventManager

## 特殊关卡事件管理器
## 负责查询当前回合的事件类型，以及事件对 game_state 的修饰逻辑。
## 不依赖任何 Node，可在任意上下文中静态调用。

# ── 事件类型常量 ──────────────────────────────────────────────────────────────
const EVENT_NONE          := ""
const EVENT_RUSH          := "rush"          ## 急速关卡：时间惩罚翻倍，HUD 变橙
const EVENT_GOLDEN_TOUCH  := "golden_touch"  ## 黄金消除：本局所有牌视为 topaz 材质计分
const EVENT_TILE_STORM    := "tile_storm"    ## 风暴关卡：每隔固定秒数往棋盘补一张牌

# ── 关卡事件表（round_id → event type）─────────────────────────────────────
## 设计原则：
##   Round  3 → 急速（第一次让玩家感受紧张感）
##   Round  7 → 黄金消除（中期奖励型，分数爆发）
##   Round 10 → 风暴（第一个挑战性节点，牌越来越多）
##   Round 15 → 急速（高难度重现）
##   Round 20 → 黄金消除（高级版）
##   Round 23 → 风暴（终局决战）
const EVENT_SCHEDULE: Dictionary = {
	3:  EVENT_RUSH,
	7:  EVENT_GOLDEN_TOUCH,
	10: EVENT_TILE_STORM,
	15: EVENT_RUSH,
	20: EVENT_GOLDEN_TOUCH,
	23: EVENT_TILE_STORM,
}

# ── 事件参数配置 ──────────────────────────────────────────────────────────────
## 急速关卡：时间惩罚系数倍增
const RUSH_TIMER_MULTIPLIER := 2.5

## 黄金消除：全场牌额外加分（每次配对成功，额外 +N 分）
const GOLDEN_BONUS_PER_PAIR := 8

## 风暴关卡：每隔多少秒触发一次随机风向
const STORM_INTERVAL_SECONDS := 20.0


# ── 公共 API ──────────────────────────────────────────────────────────────────

## 获取当前回合的事件类型（如果没有特殊事件返回空字符串）
static func get_event_for_round(round_id: int) -> String:
	return String(EVENT_SCHEDULE.get(round_id, EVENT_NONE))


## 把事件类型写入 game_state，供棋盘和 HUD 读取
static func apply_event_to_state(game_state: Dictionary, event: String) -> void:
	game_state["round_event"] = event


## 从 game_state 读取事件类型
static func get_current_event(game_state: Dictionary) -> String:
	return String(game_state.get("round_event", EVENT_NONE))


## 急速关卡：对 timerPoints 应用倍增系数
static func modify_timer_points(base_timer_points: float, event: String) -> float:
	if event == EVENT_RUSH:
		return base_timer_points * RUSH_TIMER_MULTIPLIER
	return base_timer_points


## 黄金消除：获得每对额外加分（在 board.gd 的配对成功回调里调用）
static func get_golden_bonus(event: String) -> int:
	if event == EVENT_GOLDEN_TOUCH:
		return GOLDEN_BONUS_PER_PAIR
	return 0


## 获取事件的显示名称（用于开屏提示标题）
static func get_event_display_name(event: String) -> String:
	match event:
		EVENT_RUSH:
			return "⚡ 急速关卡"
		EVENT_GOLDEN_TOUCH:
			return "✨ 黄金消除"
		EVENT_TILE_STORM:
			return "🌪 风暴关卡"
		_:
			return ""


## 获取事件的副标题描述（用于开屏提示）
static func get_event_description(event: String) -> String:
	match event:
		EVENT_RUSH:
			return "时间压力大幅增加！\n快速消牌，每一秒都至关重要。"
		EVENT_GOLDEN_TOUCH:
			return "本局每次配对消除额外获得 +%d 分！\n大量消牌，得分爆发的时刻到了。" % GOLDEN_BONUS_PER_PAIR
		EVENT_TILE_STORM:
			return "每隔 %d 秒，一阵随机风向席卷棋盘！\n牌随风移动，注意阵型变化！" % int(STORM_INTERVAL_SECONDS)
		_:
			return ""


## 获取事件的 HUD 颜色调色板（用于给棋盘 HUD 染色）
static func get_event_hud_color(event: String) -> Color:
	match event:
		EVENT_RUSH:
			return Color(1.0, 0.45, 0.1, 1.0)      # 橙红
		EVENT_GOLDEN_TOUCH:
			return Color(1.0, 0.85, 0.15, 1.0)     # 金黄
		EVENT_TILE_STORM:
			return Color(0.5, 0.75, 1.0, 1.0)      # 天蓝紫
		_:
			return Color(0.9, 0.85, 0.7, 1.0)      # 默认米色


## 获取事件横幅背景色（开屏提示面板颜色）
static func get_event_banner_color(event: String) -> Color:
	match event:
		EVENT_RUSH:
			return Color(0.55, 0.2, 0.05, 0.92)
		EVENT_GOLDEN_TOUCH:
			return Color(0.45, 0.35, 0.04, 0.92)
		EVENT_TILE_STORM:
			return Color(0.1, 0.2, 0.45, 0.92)
		_:
			return Color(0.12, 0.14, 0.18, 0.92)
