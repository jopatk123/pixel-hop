extends CharacterBody2D
## 巡逻敌人：在出生点两侧来回走，撞墙掉头。
## 玩家从上方落下时把它踩死，从侧面或下方碰到则玩家死亡。

const GRAVITY := 900.0
const MAX_FALL_SPEED := 500.0
## 被踩死后压扁停留的时间
const SQUASH_TIME := 0.15
## 判定踩头时，玩家中心至少要高出敌人中心这么多（平地并肩走只有 1px，不会误判成踩头）
const MIN_STOMP_OFFSET := 6.0

const Effects := preload("res://scripts/effects.gd")

@export var speed := 40.0
## 从出生点向两侧巡逻的距离
@export var patrol_distance := 56.0
## 被踩中后给玩家的反弹速度
@export var stomp_bounce_velocity := -220.0

var _direction := -1.0
var _origin_x := 0.0
var _dead := false

@onready var _visual: ColorRect = $Visual
@onready var _hitbox: Area2D = $Hitbox


func _ready() -> void:
	_origin_x = global_position.x
	_hitbox.body_entered.connect(_on_hitbox_body_entered)


func _physics_process(delta: float) -> void:
	if _dead:
		return

	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
	velocity.x = _direction * speed

	# 撞墙或超出巡逻半径就掉头
	if is_on_wall():
		_direction = - _direction
	elif global_position.x <= _origin_x - patrol_distance:
		_direction = 1.0
	elif global_position.x >= _origin_x + patrol_distance:
		_direction = -1.0

	move_and_slide()


func _on_hitbox_body_entered(body: Node2D) -> void:
	if _dead or not body.is_in_group("player") or body.is_dying:
		return

	if _is_stomped_by(body):
		_squash()
		body.bounce(stomp_bounce_velocity)
	else:
		body.die()


## 玩家在下落，且身体中心明显高于敌人中心 → 判定为踩头
func _is_stomped_by(body: Node2D) -> bool:
	return body.velocity.y > 0.0 and body.global_position.y < global_position.y - MIN_STOMP_OFFSET


func _squash() -> void:
	_dead = true
	velocity = Vector2.ZERO
	_hitbox.set_deferred("monitoring", false)

	_visual.offset_top = -3.0
	_visual.offset_bottom = 3.0
	_visual.color = Color(0.95, 0.55, 0.75)

	Audio.play("stomp", -2.0, randf_range(0.95, 1.05))
	Effects.stomp(get_parent(), global_position)

	await get_tree().create_timer(SQUASH_TIME).timeout
	queue_free()
