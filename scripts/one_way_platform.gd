@tool
extends StaticBody2D
## 单向平台：从下往上可以跳穿，从上往下可以站立；
## 站在上面按「下 + 跳」会穿下去（由 player.gd 处理）。
## 节点在组 one_way 里，玩家靠这个组名认出它。

@export var size := Vector2(96.0, 10.0):
	set(value):
		size = value
		_refresh()

@export var color := Color(0.34, 0.52, 0.58):
	set(value):
		color = value
		_refresh()

var _ready_done := false

@onready var _shape_node: CollisionShape2D = $CollisionShape2D
@onready var _visual: ColorRect = $Visual


func _ready() -> void:
	_ready_done = true
	# 每次 _refresh() 都会换新的 shape 资源，这里再兜一次底
	_shape_node.one_way_collision = true
	_refresh()


func _refresh() -> void:
	# 场景加载阶段 setter 会先于 _ready 触发，此时子节点还不存在
	if not _ready_done:
		return

	var rect := RectangleShape2D.new()
	rect.size = size
	_shape_node.shape = rect

	var half := size * 0.5
	_visual.offset_left = -half.x
	_visual.offset_top = -half.y
	_visual.offset_right = half.x
	_visual.offset_bottom = half.y
	_visual.color = color
