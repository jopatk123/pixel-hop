extends Node
## 全局游戏状态与存档。挂在「自动加载」里，跨关卡、跨场景重载都能保留。

## 一关的起始命数
const START_LIVES := 3
## 存档文件路径
const SAVE_PATH := "user://save.cfg"

signal coins_changed(total: int)
signal lives_changed(remaining: int)
signal time_changed(seconds: float)

## 本关已收集金币
var coins := 0
## 剩余命数
var lives := START_LIVES
## 本关已用时间（秒）
var elapsed := 0.0

## 存档：历史最佳通关时间，0 表示还没通关过
var best_time := 0.0
## 存档：累计收集金币
var total_coins := 0

var _timer_running := false


func _ready() -> void:
	load_game()


func _process(delta: float) -> void:
	# 暂停时计时也要停
	if not _timer_running or get_tree().paused:
		return
	elapsed += delta
	time_changed.emit(elapsed)


## 重新开一关时重置本局状态
func start_run() -> void:
	coins = 0
	lives = START_LIVES
	elapsed = 0.0
	_timer_running = true
	coins_changed.emit(coins)
	lives_changed.emit(lives)
	time_changed.emit(elapsed)


func add_coin() -> void:
	coins += 1
	total_coins += 1
	coins_changed.emit(coins)


## 掉一条命，返回是否还有命可复活
func lose_life() -> bool:
	lives = maxi(lives - 1, 0)
	lives_changed.emit(lives)
	return lives > 0


## 通关结算：停表、刷新最佳成绩并写盘
func finish_level() -> void:
	_timer_running = false
	if best_time <= 0.0 or elapsed < best_time:
		best_time = elapsed
	save_game()


func save_game() -> void:
	var config := ConfigFile.new()
	config.set_value("progress", "best_time", best_time)
	config.set_value("progress", "total_coins", total_coins)
	var error := config.save(SAVE_PATH)
	if error != OK:
		push_warning("存档写入失败：%s" % error_string(error))


func load_game() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	best_time = config.get_value("progress", "best_time", 0.0)
	total_coins = config.get_value("progress", "total_coins", 0)
