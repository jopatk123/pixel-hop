extends CanvasLayer
## HUD：金币 / 命数 / 计时，外加暂停、通关、失败三种遮罩。
## 本节点的 process_mode 设为 ALWAYS，暂停时依然能响应按键。

@onready var _coins_label: Label = $TopBar/Row/Coins
@onready var _lives_label: Label = $TopBar/Row/Lives
@onready var _time_label: Label = $TopBar/Row/Time
@onready var _pause_panel: Control = $PausePanel
@onready var _clear_panel: Control = $ClearPanel
@onready var _clear_detail: Label = $ClearPanel/Detail
@onready var _game_over_panel: Control = $GameOverPanel


func _ready() -> void:
	GameState.coins_changed.connect(_on_coins_changed)
	GameState.lives_changed.connect(_on_lives_changed)
	GameState.time_changed.connect(_on_time_changed)

	_on_coins_changed(GameState.coins)
	_on_lives_changed(GameState.lives)
	_on_time_changed(GameState.elapsed)

	_pause_panel.hide()
	_clear_panel.hide()
	_game_over_panel.hide()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _is_result_visible():
		_toggle_pause()
		get_viewport().set_input_as_handled()
		return

	# 结算或失败后按 R 重开
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_R and _is_result_visible():
			_restart_level()
			get_viewport().set_input_as_handled()


## 命数耗尽时由关卡调用
func show_game_over() -> void:
	get_tree().paused = true
	_game_over_panel.show()


## 到达终点时由关卡调用
func show_level_clear() -> void:
	get_tree().paused = true
	var best_text := "无记录" if GameState.best_time <= 0.0 else "%.2f 秒" % GameState.best_time
	_clear_detail.text = "用时 %.2f 秒    金币 %d\n最佳成绩 %s\n\n按 R 重玩" % [
		GameState.elapsed, GameState.coins, best_text
	]
	_clear_panel.show()


func _is_result_visible() -> bool:
	return _clear_panel.visible or _game_over_panel.visible


func _toggle_pause() -> void:
	var paused := not get_tree().paused
	get_tree().paused = paused
	_pause_panel.visible = paused
	# 恢复时音调高一点，和暂停区分开
	Audio.play("pause", -3.0, 1.0 if paused else 1.2)


func _restart_level() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_coins_changed(total: int) -> void:
	_coins_label.text = "金币 %d" % total


func _on_lives_changed(remaining: int) -> void:
	_lives_label.text = "命 %d" % remaining


func _on_time_changed(seconds: float) -> void:
	var minutes := int(seconds) / 60
	var rest := seconds - minutes * 60
	_time_label.text = "%02d:%04.1f" % [minutes, rest]
