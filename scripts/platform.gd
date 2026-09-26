@tool
extends StaticBody2D
## 灰盒平台：在检查器里改 size 会同时更新碰撞体和占位色块。

@export var size := Vector2(96.0, 16.0):
	set(value):
		size = value
		_refresh()

@export var color := Color(0.35, 0.38, 0.45):
	set(value):
		color = value
		_refresh()

var _ready_done := false

@onready var _shape_node: CollisionShape2D = $CollisionShape2D
@onready var _visual: ColorRect = $Visual


func _ready() -> void:
	_ready_done = true
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
