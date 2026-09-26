extends Area2D
## 弹簧：玩家踩上来就被高高弹起，比普通跳跃高得多。

## 弹起速度（负值向上）
@export var launch_velocity := -430.0

const SQUASH_TIME := 0.1
const VISUAL_HALF := Vector2(12.0, 6.0)

@onready var _visual: ColorRect = $Visual


func _ready() -> void:
	# 以底边中点为缩放中心，压下去的时候看起来才像被踩扁
	_visual.pivot_offset = Vector2(VISUAL_HALF.x, VISUAL_HALF.y * 2.0)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player") or body.is_dying:
		return

	body.bounce(launch_velocity)
	Audio.play("spring", -2.0, randf_range(0.94, 1.04))

	_visual.scale.y = 0.45
	var tween := create_tween()
	tween.tween_property(_visual, "scale:y", 1.0, SQUASH_TIME)
