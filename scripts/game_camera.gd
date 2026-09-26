extends Camera2D
## 带震屏的相机：每次震动给一个随机偏移，然后按帧线性衰减回零。
## 挂在玩家身上，强度小一点即可，视口只有 640x360，晃太狠会看不清路。

var _strength := 0.0
## 每帧衰减多少，由 强度 / 时长 算出
var _decay := 0.0


## 抖一下。duration 内线性收敛，重复调用取更强的那次，不会互相打断。
func shake(strength: float, duration := 0.25) -> void:
	if strength <= 0.0:
		return
	_decay = maxf(strength, _strength) / maxf(duration, 0.001)
	_strength = maxf(_strength, strength)


func _process(delta: float) -> void:
	if _strength <= 0.0:
		return

	_strength = maxf(_strength - _decay * delta, 0.0)
	if _strength <= 0.0:
		offset = Vector2.ZERO
		return

	offset = Vector2(
		randf_range(-_strength, _strength),
		randf_range(-_strength, _strength)
	)
