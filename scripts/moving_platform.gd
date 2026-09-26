@tool
extends AnimatableBody2D
## 移动平台：从摆放位置出发，在 travel 给出的位移范围内匀速往返。
## 用 AnimatableBody2D（sync_to_physics），站上去的玩家会被一起带走。

@export var size := Vector2(44.0, 12.0):
	set(value):
		size = value
		_refresh()

## 相对摆放位置的位移范围
@export var travel := Vector2(60.0, 0.0)
## 移动速度（像素/秒）
@export var speed := 55.0
@export var color := Color(0.55, 0.42, 0.72):
	set(value):
		color = value
		_refresh()

var _origin := Vector2.ZERO
## 0 → 1 表示从摆放位置走到 travel 终点的进度
var _progress := 0.0
var _direction := 1.0
var _ready_done := false

@onready var _shape_node: CollisionShape2D = $CollisionShape2D
@onready var _visual: ColorRect = $Visual


func _ready() -> void:
	_ready_done = true
	_origin = position
	_refresh()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	var span := travel.length()
	if span <= 0.0:
		return

	_progress += _direction * speed * delta / span
	if _progress >= 1.0:
		_progress = 1.0
		_direction = -1.0
	elif _progress <= 0.0:
		_progress = 0.0
		_direction = 1.0

	position = _origin + travel * _progress


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
