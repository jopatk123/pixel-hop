extends Node2D
## 一次性粒子特效：不建场景文件，需要时现场拼一个 CPUParticles2D 播完自毁。
## 调用方用 const Effects := preload("res://scripts/effects.gd") 直接调静态方法。
## 参数都集中在这里，想改观感只动这一处。

## 粒子贴图只生成一次，是张中间亮边缘透明的小圆点
static var _dot_texture: Texture2D

## 落地扬尘：向上扬起再被重力拉回地面
const DUST := {
	"color": Color(0.74, 0.78, 0.88),
	"amount": 8,
	"lifetime": 0.30,
	"spread": 60.0,
	"velocity_min": 25.0,
	"velocity_max": 65.0,
	"gravity": Vector2(0.0, 320.0),
	"scale_min": 0.8,
	"scale_max": 1.8,
	"radius": 4.0,
}

## 金币星芒：金色小点四散
const SPARKLE := {
	"color": Color(1.0, 0.85, 0.35),
	"amount": 10,
	"lifetime": 0.35,
	"spread": 180.0,
	"velocity_min": 40.0,
	"velocity_max": 90.0,
	"gravity": Vector2(0.0, 120.0),
	"scale_min": 0.8,
	"scale_max": 1.6,
	"radius": 3.0,
	"explosiveness": 1.0,
}

## 踩死敌人：向两侧炸开的碎块
const STOMP := {
	"color": Color(0.85, 0.45, 0.7),
	"amount": 12,
	"lifetime": 0.40,
	"spread": 80.0,
	"velocity_min": 50.0,
	"velocity_max": 110.0,
	"gravity": Vector2(0.0, 420.0),
	"scale_min": 1.0,
	"scale_max": 2.2,
	"radius": 5.0,
	"explosiveness": 1.0,
}

## 玩家死亡：红色碎块向上炸开，比踩敌人大一圈
const DEATH := {
	"color": Color(0.95, 0.42, 0.35),
	"amount": 16,
	"lifetime": 0.55,
	"spread": 100.0,
	"velocity_min": 60.0,
	"velocity_max": 150.0,
	"gravity": Vector2(0.0, 380.0),
	"scale_min": 1.2,
	"scale_max": 2.6,
	"radius": 6.0,
	"explosiveness": 1.0,
}


static func dust(parent: Node, at: Vector2) -> void:
	_spawn(parent, at, DUST)


static func sparkle(parent: Node, at: Vector2) -> void:
	_spawn(parent, at, SPARKLE)


static func stomp(parent: Node, at: Vector2) -> void:
	_spawn(parent, at, STOMP)


static func death(parent: Node, at: Vector2) -> void:
	_spawn(parent, at, DEATH)


## 挂到 parent 下、播完自己销毁。父节点取调用方所在的场景层，粒子就不会跟着角色跑。
static func _spawn(parent: Node, at: Vector2, config: Dictionary) -> void:
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return

	var particles := CPUParticles2D.new()
	particles.texture = _dot()
	particles.one_shot = true
	particles.emitting = false
	particles.direction = Vector2.UP
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = config.get("radius", 4.0)
	particles.amount = config.get("amount", 10)
	particles.lifetime = config.get("lifetime", 0.4)
	particles.explosiveness = config.get("explosiveness", 0.9)
	particles.spread = config.get("spread", 45.0)
	particles.initial_velocity_min = config.get("velocity_min", 30.0)
	particles.initial_velocity_max = config.get("velocity_max", 80.0)
	particles.gravity = config.get("gravity", Vector2(0.0, 200.0))
	particles.scale_amount_min = config.get("scale_min", 1.0)
	particles.scale_amount_max = config.get("scale_max", 2.0)
	particles.color = config.get("color", Color.WHITE)

	parent.add_child(particles)
	particles.global_position = at
	particles.emitting = true
	particles.finished.connect(particles.queue_free)


## 8x8 的柔边圆点：没有贴图时 CPUParticles2D 只有 1px，缩放了也看不清
static func _dot() -> Texture2D:
	if _dot_texture != null:
		return _dot_texture

	var size := 8
	var center := (size - 1) * 0.5
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var distance := Vector2(x - center, y - center).length() / center
			var alpha := clampf(1.0 - distance, 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha * alpha))

	_dot_texture = ImageTexture.create_from_image(image)
	return _dot_texture
