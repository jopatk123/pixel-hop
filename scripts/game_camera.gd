extends Camera2D
## 跟随 + 震屏：前瞻、纵向软区、随机抖动衰减。
## 相机挂在玩家下，用 offset 做前瞻与纵向滞后，不拆场景树。

@export_group("跟随")
## 朝移动方向偏移的最大像素（前瞻）
@export var look_ahead_distance := 52.0
## 前瞻收敛速度
@export var look_ahead_speed := 5.0
## 玩家纵向移动多少像素内镜头不跟（小跳不晃镜头）
@export var vertical_deadzone := 28.0
## 超出死区后镜头纵向追赶速度
@export var vertical_follow_speed := 4.5

@export_group("震屏")
## 单次震动的默认时长（秒）
@export var default_shake_duration := 0.22

var _strength := 0.0
var _decay := 0.0
var _look_ahead := 0.0
var _anchor_y := 0.0
var _anchor_ready := false

var _player: CharacterBody2D


func _ready() -> void:
	_player = get_parent() as CharacterBody2D
	if _player != null:
		_anchor_y = _player.global_position.y
		_anchor_ready = true


## 当前震屏强度（测试与调试）
func get_shake_strength() -> float:
	return _strength


## 抖一下。duration 内线性收敛，重复调用取更强的那次。
func shake(strength: float, duration := -1.0) -> void:
	if strength <= 0.0:
		return
	var dur := default_shake_duration if duration < 0.0 else duration
	_decay = maxf(strength, _strength) / maxf(dur, 0.001)
	_strength = maxf(_strength, strength)


## 复活后重置前瞻与纵向锚点，避免镜头卡在上一次的位置
func reset_follow_state() -> void:
	_look_ahead = 0.0
	offset = Vector2.ZERO
	_strength = 0.0
	if _player != null:
		_anchor_y = _player.global_position.y


func _process(delta: float) -> void:
	var follow := _compute_follow_offset(delta)
	var shake := _compute_shake_offset(delta)
	offset = follow + shake


func _compute_follow_offset(delta: float) -> Vector2:
	if _player == null:
		return Vector2.ZERO

	var px := _player.global_position.x
	var py := _player.global_position.y

	var move_dir := 0.0
	if absf(_player.velocity.x) > 12.0:
		move_dir = signf(_player.velocity.x)
	elif Input.get_axis("move_left", "move_right") != 0.0:
		move_dir = Input.get_axis("move_left", "move_right")

	var target_look := move_dir * look_ahead_distance
	_look_ahead = lerpf(_look_ahead, target_look, look_ahead_speed * delta)

	if not _anchor_ready:
		_anchor_y = py
		_anchor_ready = true
	else:
		var dy := py - _anchor_y
		if absf(dy) > vertical_deadzone:
			var excess := absf(dy) - vertical_deadzone
			_anchor_y += signf(dy) * excess * clampf(vertical_follow_speed * delta, 0.0, 1.0)

	return Vector2(_look_ahead, _anchor_y - py)


func _compute_shake_offset(delta: float) -> Vector2:
	if _strength <= 0.0:
		return Vector2.ZERO

	_strength = maxf(_strength - _decay * delta, 0.0)
	if _strength <= 0.0:
		return Vector2.ZERO

	return Vector2(
		randf_range(-_strength, _strength),
		randf_range(-_strength, _strength)
	)
