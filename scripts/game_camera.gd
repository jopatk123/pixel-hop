extends Camera2D
## 相机挂在玩家下，只负责会衰减的震屏，不拆场景树。
##
## 不做前瞻：镜头严格跟着玩家，跑动和停手时画面都不会额外滑动。
##
## 纵向不做跟随：关卡正好一屏高，limit 已经把相机钉死在关卡竖直中线上，
## 此时任何纵向 offset 都等于让整屏跟着玩家上下平移（而且是反方向的），
## 每跳一次整屏就晃一次，看着很晕。等以后有关卡高过一屏、相机真的能上下
## 移动时，再按 limit 范围补一套纵向软区。

@export_group("震屏")
## 单次震动的默认时长（秒）
@export var default_shake_duration := 0.22
## 震屏横向、纵向的振动频率（赫兹），两个轴不同频率看起来才像抖动而不是打摆子
@export var shake_frequency := Vector2(12.0, 15.0)

var _strength := 0.0
var _decay := 0.0
var _shake_time := 0.0


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
	# 从零相位重新起振，避免刚触发就把整屏瞬移到最大偏移
	_shake_time = 0.0


## 复活时清掉残留的震动位移
func reset_state() -> void:
	offset = Vector2.ZERO
	_strength = 0.0


func _process(delta: float) -> void:
	offset = _compute_shake_offset(delta)


func _compute_shake_offset(delta: float) -> Vector2:
	if _strength <= 0.0:
		return Vector2.ZERO

	_strength = maxf(_strength - _decay * delta, 0.0)
	if _strength <= 0.0:
		return Vector2.ZERO

	# 正弦振动：帧间连续，比每帧取随机数那种白噪声柔和得多，不会一直"抖"
	_shake_time += delta
	return Vector2(
		sin(_shake_time * TAU * shake_frequency.x),
		sin(_shake_time * TAU * shake_frequency.y)
	) * _strength
