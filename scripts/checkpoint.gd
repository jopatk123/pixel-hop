extends Area2D
## 检查点：玩家第一次碰到就点亮，并把这里设为新的复活点。

const INACTIVE_COLOR := Color(0.42, 0.45, 0.55)
const ACTIVE_COLOR := Color(0.06, 0.86, 0.47)

const Effects := preload("res://scripts/effects.gd")

## 点亮时把复活点位置（检查点坐标 + 偏移）发给关卡
signal activated(spawn_point: Vector2)

## 复活点相对检查点的偏移
@export var spawn_offset := Vector2(0.0, -20.0)

var is_active := false

@onready var _visual: ColorRect = $Visual


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if is_active or not body.is_in_group("player"):
		return

	is_active = true
	_visual.color = ACTIVE_COLOR
	Audio.play("checkpoint")
	Effects.checkpoint_burst(get_parent(), global_position)
	activated.emit(global_position + spawn_offset)
