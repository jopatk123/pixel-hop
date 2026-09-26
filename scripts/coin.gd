extends Area2D
## 金币：玩家碰到就加分并消失。灰盒阶段用色块占位。

## 拾取动效时长
const PICKUP_TIME := 0.12
## 色块半径，用于设置缩放中心
const VISUAL_RADIUS := 6.0

const Effects := preload("res://scripts/effects.gd")

@onready var _visual: ColorRect = $Visual


func _ready() -> void:
	_visual.pivot_offset = Vector2(VISUAL_RADIUS, VISUAL_RADIUS)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	GameState.add_coin()
	# 先关掉判定，避免同一帧被重复计数
	set_deferred("monitoring", false)
	Audio.play("coin", -3.0, randf_range(0.97, 1.05))
	Effects.sparkle(get_parent(), global_position)
	_play_pickup()


func _play_pickup() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_visual, "scale", Vector2(1.5, 0.0), PICKUP_TIME)
	tween.tween_property(_visual, "modulate:a", 0.0, PICKUP_TIME)
	await tween.finished
	queue_free()
