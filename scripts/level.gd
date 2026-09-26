extends Node2D
## 关卡编排：金币、敌人、机关各自管自己的逻辑，这里只负责流程——
## 开始计时、记录检查点、死亡扣命、通关结算。

## 死亡到复活之间的停顿（秒）
const RESPAWN_DELAY := 0.6

@onready var _player: CharacterBody2D = $Player
@onready var _hud: CanvasLayer = $HUD
@onready var _goal: Area2D = $Goal

var _spawn_point := Vector2.ZERO
var _is_game_over := false


func _ready() -> void:
	GameState.start_run()
	Audio.play_bgm("level_01")

	_spawn_point = _player.global_position
	_player.set_respawn_point(_spawn_point)
	_player.died.connect(_on_player_died)

	_goal.body_entered.connect(_on_goal_entered)

	# 检查点自己知道该把复活点放在哪，关卡只负责记住
	for checkpoint in get_tree().get_nodes_in_group("checkpoints"):
		checkpoint.activated.connect(_on_checkpoint_activated)


func _on_checkpoint_activated(spawn_point: Vector2) -> void:
	_spawn_point = spawn_point
	_player.set_respawn_point(spawn_point)


func _on_player_died() -> void:
	if _is_game_over:
		return

	if not GameState.lose_life():
		_is_game_over = true
		Audio.play("game_over")
		_hud.show_game_over()
		return

	# 停顿一拍再送回检查点，让死亡有个反馈
	await get_tree().create_timer(RESPAWN_DELAY).timeout
	if is_instance_valid(_player):
		_player.revive_at(_spawn_point)


func _on_goal_entered(body: Node2D) -> void:
	if _is_game_over or not body.is_in_group("player"):
		return

	GameState.finish_level()
	Audio.play("clear")
	_hud.show_level_clear()
