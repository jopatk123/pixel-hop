extends Node2D
## 一次性粒子特效 + 顿帧：不建场景文件，需要时现场拼 CPUParticles2D 播完自毁。
## 调用方用 const Effects := preload("res://scripts/effects.gd") 直接调静态方法。

static var _dot_texture: Texture2D
static var _hit_stop_running := false

## 落地扬尘
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

## 起跳扬尘（比落地少一点）
const JUMP_DUST := {
	"color": Color(0.70, 0.74, 0.86),
	"amount": 5,
	"lifetime": 0.22,
	"spread": 45.0,
	"velocity_min": 15.0,
	"velocity_max": 45.0,
	"gravity": Vector2(0.0, 280.0),
	"scale_min": 0.6,
	"scale_max": 1.4,
	"radius": 3.0,
}

## 急停/转向扬尘
const TURN_DUST := {
	"color": Color(0.68, 0.72, 0.84),
	"amount": 6,
	"lifetime": 0.25,
	"spread": 35.0,
	"velocity_min": 20.0,
	"velocity_max": 55.0,
	"gravity": Vector2(0.0, 300.0),
	"scale_min": 0.7,
	"scale_max": 1.5,
	"radius": 3.5,
	"direction": Vector2.ZERO,
}

const SPARKLE := {
	"color": Color(1.0, 0.85, 0.35),
	"amount": 12,
	"lifetime": 0.38,
	"spread": 180.0,
	"velocity_min": 45.0,
	"velocity_max": 100.0,
	"gravity": Vector2(0.0, 100.0),
	"scale_min": 0.8,
	"scale_max": 1.8,
	"radius": 3.0,
	"explosiveness": 1.0,
}

const STOMP := {
	"color": Color(0.85, 0.45, 0.7),
	"amount": 14,
	"lifetime": 0.42,
	"spread": 85.0,
	"velocity_min": 55.0,
	"velocity_max": 120.0,
	"gravity": Vector2(0.0, 420.0),
	"scale_min": 1.0,
	"scale_max": 2.4,
	"radius": 5.0,
	"explosiveness": 1.0,
}

const DEATH := {
	"color": Color(0.95, 0.42, 0.35),
	"amount": 18,
	"lifetime": 0.58,
	"spread": 110.0,
	"velocity_min": 65.0,
	"velocity_max": 160.0,
	"gravity": Vector2(0.0, 380.0),
	"scale_min": 1.2,
	"scale_max": 2.8,
	"radius": 6.0,
	"explosiveness": 1.0,
}

const SPRING := {
	"color": Color(0.35, 0.95, 0.55),
	"amount": 10,
	"lifetime": 0.35,
	"spread": 55.0,
	"velocity_min": 80.0,
	"velocity_max": 160.0,
	"gravity": Vector2(0.0, -40.0),
	"scale_min": 0.9,
	"scale_max": 2.0,
	"radius": 4.0,
	"explosiveness": 0.95,
	"direction": Vector2.UP,
}

const CHECKPOINT := {
	"color": Color(0.2, 0.95, 0.65),
	"amount": 16,
	"lifetime": 0.45,
	"spread": 180.0,
	"velocity_min": 35.0,
	"velocity_max": 95.0,
	"gravity": Vector2(0.0, 60.0),
	"scale_min": 0.9,
	"scale_max": 2.2,
	"radius": 5.0,
	"explosiveness": 1.0,
}


static func dust(parent: Node, at: Vector2) -> void:
	_spawn(parent, at, DUST)


static func jump_dust(parent: Node, at: Vector2) -> void:
	_spawn(parent, at, JUMP_DUST)


static func turn_dust(parent: Node, at: Vector2, facing: float) -> void:
	var cfg := TURN_DUST.duplicate()
	cfg["direction"] = Vector2(-signf(facing), -0.2)
	_spawn(parent, at, cfg)


static func sparkle(parent: Node, at: Vector2) -> void:
	_spawn(parent, at, SPARKLE)


static func stomp(parent: Node, at: Vector2) -> void:
	_spawn(parent, at, STOMP)


static func death(parent: Node, at: Vector2) -> void:
	_spawn(parent, at, DEATH)


static func spring_burst(parent: Node, at: Vector2) -> void:
	_spawn(parent, at, SPRING)


static func checkpoint_burst(parent: Node, at: Vector2) -> void:
	_spawn(parent, at, CHECKPOINT)


## 短顿帧（踩敌 / 死亡）：按物理帧计数，避免全局 time_scale 与 headless 测试不同步。
static func hit_stop(tree: SceneTree, duration := 0.05, time_scale := 0.07) -> void:
	if tree == null or _hit_stop_running:
		return
	_hit_stop_running = true
	Engine.time_scale = time_scale
	var frames := maxi(2, int(duration * 60.0))
	for _i in frames:
		await tree.physics_frame
	Engine.time_scale = 1.0
	_hit_stop_running = false


static func _spawn(parent: Node, at: Vector2, config: Dictionary) -> void:
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return

	var particles := CPUParticles2D.new()
	particles.texture = _dot()
	particles.one_shot = true
	particles.emitting = false
	particles.direction = config.get("direction", Vector2.UP)
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
