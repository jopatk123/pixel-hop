extends CharacterBody2D
## 灰盒手感原型：所有手感参数都挂在检查器上，边跑边调。
## 死亡与复活的时机由关卡决定，这里只提供 die() / revive_at() 两个动作。

## 掉出关卡下沿的高度阈值，视为死亡
const FALL_OUT_Y := 420.0
## 落地的最小下落速度，低于这个值的着地（走路时的贴地）不触发扬尘和挤压
const LAND_MIN_FALL_SPEED := 120.0
## 起跳/落地挤压后恢复原样的时间（秒）
const SQUASH_RECOVER_TIME := 0.12

## 起跳与落地时的挤压比例
const JUMP_STRETCH := Vector2(0.75, 1.25)
const LAND_SQUASH := Vector2(1.3, 0.7)

const Effects := preload("res://scripts/effects.gd")
const GameCamera := preload("res://scripts/game_camera.gd")

@export_group("水平移动")
## 最大水平速度（像素/秒）
@export var max_speed := 200.0
## 地面加速度，越大越跟手
@export var ground_acceleration := 1500.0
## 地面摩擦，越大停得越快
@export var ground_friction := 1800.0
## 空中加速度，通常低于地面值，保留一点惯性
@export var air_acceleration := 900.0
## 空中摩擦，越小越飘
@export var air_friction := 400.0

@export_group("跳跃高度")
## 最高跳跃高度（像素）
@export var jump_height := 64.0
## 起跳到最高点的时间（秒），越短跳跃越脆
@export var jump_time_to_peak := 0.36
## 最高点落回地面的时间（秒），短于上升时间会更有重量感
@export var jump_time_to_descent := 0.28

@export_group("跳跃手感")
## 松开跳跃键后上升段的重力倍率，决定可变跳跃高度
@export var jump_cut_multiplier := 2.4
## 离开平台后仍可起跳的宽容时间（秒），即土狼时间
@export var coyote_time := 0.10
## 落地前提前按跳会被记住的时间（秒），即跳跃缓冲
@export var jump_buffer_time := 0.12
## 最高点附近的重力衰减，制造滞空感
@export var apex_gravity_multiplier := 0.7
## 判定为最高点附近的垂直速度阈值
@export var apex_velocity_threshold := 40.0
## 最大下落速度
@export var max_fall_speed := 500.0

@export_group("交互")
## 踩中敌人后获得的向上速度
@export var stomp_bounce_velocity := -220.0
## 按「下 + 跳」时忽略单向平台的时长（秒）
@export var drop_through_time := 0.25

@export_group("反馈")
## 死亡时震屏强度
@export var death_shake_strength := 6.0
## 落地时震屏强度（0 为关闭）
@export var land_shake_strength := 2.0
## 死亡顿帧时长（秒）
@export var death_hit_stop_duration := 0.07
## 死亡顿帧时的时间缩放
@export var death_hit_stop_scale := 0.06
## 起跳/受伤闪白时长
@export var flash_duration := 0.08
## 水平速度低于此值时不算「在跑」
@export var turn_dust_speed_threshold := 48.0

## 死亡时抛出，关卡据此扣命或结算
signal died

## 当前的复活点，由关卡通过 set_respawn_point() 设置
var respawn_point := Vector2.ZERO
## 死亡中：物理暂停，等待关卡决定复活还是结束
var is_dying := false

var _jump_velocity := 0.0
var _rise_gravity := 0.0
var _fall_gravity := 0.0
var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _drop_through_timer := 0.0
## 当前这次上升是不是玩家自己按出来的，决定要不要受「提前松手」影响
var _variable_jump := false
## 上一帧是否踩在地面上，用来分辨「刚落地」和「一直站着」
var _was_on_floor := false
var _ignored_platform: Node = null
var _squash_tween: Tween = null
var _flash_tween: Tween = null
var _last_facing := 0.0

@onready var _visual: ColorRect = $Visual
@onready var _camera: GameCamera = $Camera2D


func _ready() -> void:
	respawn_point = global_position
	# 缩放中心挪到色块正中，否则挤压拉伸会连带位置一起跳
	_visual.pivot_offset = _visual.size * 0.5
	_recalculate_jump_metrics()


func _physics_process(delta: float) -> void:
	if is_dying:
		return

	_update_timers(delta)
	_update_drop_through(delta)
	_apply_gravity(delta)
	_handle_jump()
	_handle_horizontal(delta)
	# move_and_slide() 之后 velocity.y 会被清成 0，着地速度得提前记下来
	var fall_speed := velocity.y
	move_and_slide()
	_handle_landing(fall_speed)
	_handle_turn_dust()

	if global_position.y > FALL_OUT_Y:
		die()


## 由「跳跃高度 + 上升/下落时间」反推初速度和重力，比对着重力数值调更直观
func _recalculate_jump_metrics() -> void:
	_jump_velocity = -2.0 * jump_height / jump_time_to_peak
	_rise_gravity = 2.0 * jump_height / pow(jump_time_to_peak, 2.0)
	_fall_gravity = 2.0 * jump_height / pow(jump_time_to_descent, 2.0)


func set_respawn_point(point: Vector2) -> void:
	respawn_point = point


## 踩到敌人或弹簧时被弹起。外力给的速度不参与可变跳跃高度。
func bounce(velocity_y: float) -> void:
	velocity.y = velocity_y
	_variable_jump = false
	# 补一次土狼时间，弹起瞬间还能补跳
	_coyote_timer = coyote_time


## 死亡：冻结物理并通知关卡，暂停/复活都由关卡安排
func die() -> void:
	if is_dying:
		return

	is_dying = true
	velocity = Vector2.ZERO
	# 关掉玩家层，敌人的判定框和金币都不会再命中
	set_collision_layer_value(2, false)
	_visual.modulate = Color(1.0, 1.0, 1.0, 0.3)
	_stop_squash()

	Audio.play("hurt")
	Effects.death(get_parent(), global_position)
	_flash(Color(1.0, 0.45, 0.4))
	shake_camera(death_shake_strength, 0.32)
	Effects.hit_stop(get_tree(), death_hit_stop_duration, death_hit_stop_scale)
	died.emit()


## 回到指定复活点并解除死亡状态
func revive_at(point: Vector2) -> void:
	global_position = point
	velocity = Vector2.ZERO
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	_drop_through_timer = 0.0
	_variable_jump = false
	_was_on_floor = false
	_clear_ignored_platform()
	_stop_squash()

	is_dying = false
	set_collision_layer_value(2, true)
	_visual.modulate = Color.WHITE
	_camera.reset_follow_state()


## 让相机抖一下，强度自适应视口尺寸（640x360 上 3~6 已经很明显）
func shake_camera(strength: float, duration := 0.25) -> void:
	_camera.shake(strength, duration)


func _handle_landing(fall_speed: float) -> void:
	var on_floor := is_on_floor()
	# 只认「刚踩到地面」且着地速度够大的那一帧，站着走路的贴地抖动不会一直冒烟
	if on_floor and not _was_on_floor and fall_speed > LAND_MIN_FALL_SPEED:
		Audio.play("land", -6.0, randf_range(0.94, 1.06))
		Effects.dust(get_parent(), global_position + Vector2(0.0, _visual.size.y * 0.5))
		_play_squash(LAND_SQUASH)
		if land_shake_strength > 0.0:
			shake_camera(land_shake_strength, 0.14)
	_was_on_floor = on_floor


func _handle_turn_dust() -> void:
	if not is_on_floor():
		return

	var facing := signf(velocity.x)
	if absf(velocity.x) < turn_dust_speed_threshold:
		_last_facing = facing
		return

	if _last_facing != 0.0 and facing != 0.0 and facing != _last_facing:
		var at := global_position + Vector2(0.0, _visual.size.y * 0.5)
		Effects.turn_dust(get_parent(), at, _last_facing)
	_last_facing = facing


## 挤压拉伸：设好比例后交给 tween 弹回原样
func _play_squash(target: Vector2) -> void:
	_stop_squash()
	_visual.scale = target
	_squash_tween = create_tween()
	_squash_tween.tween_property(_visual, "scale", Vector2.ONE, SQUASH_RECOVER_TIME)


func _stop_squash() -> void:
	if _squash_tween != null and _squash_tween.is_valid():
		_squash_tween.kill()
	_squash_tween = null
	_visual.scale = Vector2.ONE


func _flash(color: Color) -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_visual.modulate = color
	_flash_tween = create_tween()
	_flash_tween.tween_property(_visual, "modulate", Color.WHITE, flash_duration)


func _update_timers(delta: float) -> void:
	# 上升过程中不刷新土狼时间，否则会在起跳瞬间白送一次二段跳
	if is_on_floor() and velocity.y >= 0.0:
		_coyote_timer = coyote_time
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)


func _apply_gravity(delta: float) -> void:
	var gravity := _rise_gravity if velocity.y < 0.0 else _fall_gravity

	# 最高点附近减弱重力，跳跃弧线更饱满
	if not is_on_floor() and absf(velocity.y) < apex_velocity_threshold:
		gravity *= apex_gravity_multiplier

	# 提前松手就让上升段立即变重，实现可变跳跃高度。
	# 只对自己按出来的跳跃生效——踩敌人、踩弹簧这类外力给的速度不该被削掉。
	if _variable_jump and velocity.y < 0.0 and not Input.is_action_pressed("jump"):
		gravity *= jump_cut_multiplier

	velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
	if velocity.y >= 0.0:
		_variable_jump = false


func _handle_jump() -> void:
	if _jump_buffer_timer <= 0.0 or _coyote_timer <= 0.0:
		return

	# 「下 + 跳」在单向平台上改成往下穿
	if Input.is_action_pressed("move_down"):
		var platform := _one_way_platform_below()
		if platform != null:
			_start_drop_through(platform)
			return

	velocity.y = _jump_velocity
	_variable_jump = true
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	_was_on_floor = false
	Audio.play("jump", 0.0, randf_range(0.96, 1.04))
	Effects.jump_dust(get_parent(), global_position + Vector2(0.0, _visual.size.y * 0.5))
	_play_squash(JUMP_STRETCH)
	_flash(Color(1.15, 1.15, 1.15))


func _handle_horizontal(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	var on_floor := is_on_floor()

	if is_zero_approx(direction):
		var friction := ground_friction if on_floor else air_friction
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		return

	var acceleration := ground_acceleration if on_floor else air_acceleration
	velocity.x = move_toward(velocity.x, direction * max_speed, acceleration * delta)


## 找到脚下正在踩着的单向平台（碰撞法线朝上才算踩住）
func _one_way_platform_below() -> Node:
	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		if collision.get_normal().y > -0.5:
			continue
		var collider := collision.get_collider()
		if collider != null and collider.is_in_group("one_way"):
			return collider
	return null


func _start_drop_through(platform: Node) -> void:
	# Godot 4 的下穿做法：给该平台加一个碰撞例外，过一会儿再撤掉
	add_collision_exception_with(platform)
	_ignored_platform = platform
	_drop_through_timer = drop_through_time
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	Audio.play("drop", -3.0)


func _update_drop_through(delta: float) -> void:
	if _drop_through_timer <= 0.0:
		return

	_drop_through_timer = maxf(_drop_through_timer - delta, 0.0)
	if _drop_through_timer <= 0.0:
		_clear_ignored_platform()


func _clear_ignored_platform() -> void:
	if is_instance_valid(_ignored_platform):
		remove_collision_exception_with(_ignored_platform)
	_ignored_platform = null
