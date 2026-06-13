extends Node
class_name EventStormController

## 风暴关卡控制器（随机风向版）
## 由 board.gd 在风暴关卡开始时 add_child，结束时 queue_free。
## 每隔 EventManager.STORM_INTERVAL_SECONDS 秒，随机选择一个风向（n/s/e/w），
## 通知 board 调用 storm_apply_wind() 推动棋盘上的牌。

## 每次风暴触发时发出，携带本次风向字符串（"n"/"s"/"e"/"w"）
signal wave_triggered(wind_rank: String)

const WIND_RANKS: Array[String] = ["n", "s", "e", "w"]

var _board: Node
var _timer: Timer
var _rng: RandomNumberGenerator
var _wave_count: int = 0


func start(board: Node) -> void:
	_board = board
	_rng = RandomNumberGenerator.new()
	_rng.randomize()

	_timer = Timer.new()
	_timer.wait_time = _random_interval()
	_timer.one_shot = true
	_timer.autostart = true
	_timer.timeout.connect(_on_wave_timer)
	add_child(_timer)


func stop() -> void:
	if is_instance_valid(_timer):
		_timer.stop()
	queue_free()


func _on_wave_timer() -> void:
	if not is_instance_valid(_board):
		stop()
		return

	_wave_count += 1
	var wind_rank: String = WIND_RANKS[_rng.randi() % WIND_RANKS.size()]

	# 通知 board 执行风向推移
	_board.storm_apply_wind(wind_rank)

	wave_triggered.emit(wind_rank)
	_play_storm_flash()

	# 随机 6~8 秒后再次触发
	_timer.wait_time = _random_interval()
	_timer.start()


func _random_interval() -> float:
	## 返回 6.0 ~ 8.0 秒的随机间隔
	return _rng.randf_range(6.0, 8.0)


func _play_storm_flash() -> void:
	## 蓝白闪光提示风暴触发
	var flash_layer := CanvasLayer.new()
	flash_layer.layer = 60
	get_tree().root.add_child(flash_layer)

	var flash_rect := ColorRect.new()
	flash_rect.color = Color(0.4, 0.7, 1.0, 0.0)
	flash_rect.position = Vector2.ZERO
	# 明确设置大小覆盖全屏
	var vp_size := get_viewport().get_visible_rect().size
	flash_rect.size = vp_size
	flash_layer.add_child(flash_rect)

	var tween := flash_rect.create_tween()
	tween.tween_property(flash_rect, "color:a", 0.28, 0.06)
	tween.tween_property(flash_rect, "color:a", 0.0, 0.38)
	tween.tween_callback(flash_layer.queue_free)
