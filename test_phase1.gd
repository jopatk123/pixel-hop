extends Node
## 临时冒烟测试：跑通 Phase 1 的金币 / 敌人 / 检查点 / 死亡 / 通关流程，
## 同时回归 Phase 0 的跳跃手感基线。验证完即可删除。

const JUMP_HEIGHT_BASELINE := 67.2
const SHORT_JUMP_BASELINE := 29.9
const MAX_SPEED_BASELINE := 200.0

var _level: Node2D
var _player: CharacterBody2D
var _failures: Array[String] = []


func _ready() -> void:
	_start_watchdog()
	_level = load("res://scenes/level_01.tscn").instantiate()
	add_child(_level)
	await _wait_physics(2)
	_player = _level.get_node("Player")

	await _test_audio()
	await _test_landing_feedback()
	await _test_camera_shake()
	await _test_jump_heights()
	await _test_horizontal_speed()
	await _test_coin()
	await _test_checkpoint()
	await _test_spring()
	await _test_moving_platform()
	await _test_one_way()
	await _test_stomp()
	await _test_side_death()
	await _test_fall_out_death()
	await _test_game_over()
	await _test_goal()

	_finish()


# ---------------------------------------------------------------- 测试用例

func _test_audio() -> void:
	for sound in ["jump", "land", "coin", "stomp", "hurt", "spring",
			"drop", "checkpoint", "pause", "clear", "game_over"]:
		_expect("音效文件已加载：%s" % sound, Audio.has_stream("res://assets/audio/sfx/", sound))
		Audio.play(sound)
	_expect("背景音乐 level_01 已加载", Audio.has_stream("res://assets/audio/bgm/", "level_01"))
	Audio.play_bgm("level_01")
	Audio.stop_bgm(0.0)

	_expect("音效播放池已就绪", Audio.get_child_count() >= 9, str(Audio.get_child_count()))


func _test_landing_feedback() -> void:
	var dust_before := _count_particles(_level)
	_place_player(Vector2(60, 220))
	for i in 60:
		await get_tree().physics_frame
		if _player.is_on_floor():
			break
	await _wait_physics(2)

	var dust_after := _count_particles(_level)
	_expect("落地溅起尘土粒子", dust_after > dust_before, "%d -> %d" % [dust_before, dust_after])

	# 挤压是 tween 的，等它跑完应该回到原尺寸
	await _wait_physics(30)
	var visual: ColorRect = _player.get_node("Visual")
	_expect("落地挤压会恢复原尺寸", visual.scale.is_equal_approx(Vector2.ONE), str(visual.scale))


func _test_camera_shake() -> void:
	var camera: Camera2D = _player.get_node("Camera2D")
	camera.call("shake", 6.0, 0.2)

	# offset 在 _process 里按帧随机写，取一小段里的最大偏移
	var max_offset := 0.0
	for i in 8:
		await get_tree().process_frame
		max_offset = maxf(max_offset, camera.offset.length())
	_expect("震屏产生了偏移", max_offset > 0.0, "%.2f" % max_offset)

	await get_tree().create_timer(0.5).timeout
	_expect("震屏强度会衰减回零", camera.call("get_shake_strength") < 0.05,
			str(camera.call("get_shake_strength")))

	var look_ahead: float = camera.get("look_ahead_distance")
	_expect("相机前瞻参数已暴露", look_ahead > 0.0, str(look_ahead))


func _test_jump_heights() -> void:
	await _wait_physics(30)
	var ground_y := _player.global_position.y

	Input.action_press("jump")
	var peak := ground_y
	for i in 90:
		await get_tree().physics_frame
		peak = minf(peak, _player.global_position.y)
		if i > 5 and _player.velocity.y >= 0.0:
			break
	Input.action_release("jump")
	_check("完整跳跃高度", ground_y - peak, JUMP_HEIGHT_BASELINE, 3.0)

	await _wait_physics(60)
	var ground_y2 := _player.global_position.y
	Input.action_press("jump")
	await _wait_physics(2)
	Input.action_release("jump")
	var peak2 := ground_y2
	for i in 90:
		await get_tree().physics_frame
		peak2 = minf(peak2, _player.global_position.y)
		if _player.velocity.y >= 0.0:
			break
	_check("两帧短按跳跃高度", ground_y2 - peak2, SHORT_JUMP_BASELINE, 3.0)
	await _wait_physics(60)


func _test_horizontal_speed() -> void:
	# 换到空中一段没有金币和敌人的地方测，避免顺路捡到东西
	_place_player(Vector2(600, 200))
	await _wait_physics(2)
	Input.action_press("move_right")
	await _wait_physics(20)
	var speed := _player.velocity.x
	Input.action_release("move_right")
	_check("水平速度上限", speed, MAX_SPEED_BASELINE, 1.0)
	await _wait_physics(20)


func _test_coin() -> void:
	var before := GameState.coins
	_place_player(Vector2(150, 272))
	await _wait_physics(4)
	_expect_equal("拾取金币后计数 +1", GameState.coins, before + 1)


func _test_checkpoint() -> void:
	_place_player(Vector2(900, 270))
	await _wait_physics(4)
	var checkpoint: Area2D = _level.get_node("Checkpoints/CheckpointA")
	_expect("检查点被点亮", checkpoint.is_active)
	_expect("复活点搬到检查点", _player.respawn_point.is_equal_approx(Vector2(900, 268)),
			str(_player.respawn_point))


func _test_spring() -> void:
	var spring: Area2D = _level.get_node("Gimmicks/Spring")
	_place_player(spring.global_position + Vector2(0, -32))

	var launched := false
	for i in 30:
		await get_tree().physics_frame
		if _player.velocity.y < -300.0:
			launched = true
			break
	_expect("踩到弹簧被高高弹起", launched, str(_player.velocity.y))
	await _wait_physics(60)


func _test_moving_platform() -> void:
	var platform: AnimatableBody2D = _level.get_node("Gimmicks/MovingPlatform")
	_place_player(platform.global_position + Vector2(0, -14))
	var start_x := platform.global_position.x

	# 平台会在两端折返，只比首尾位移可能刚好抵消，所以取过程中的最大位移
	var max_travel := 0.0
	var max_drift := 0.0
	for i in 40:
		await get_tree().physics_frame
		max_travel = maxf(max_travel, absf(platform.global_position.x - start_x))
		max_drift = maxf(max_drift, absf(_player.global_position.x - platform.global_position.x))

	_expect("移动平台确实在移动", max_travel > 10.0, "最大位移 %.1f" % max_travel)
	_expect("玩家被平台带着走", max_drift < 8.0, "最大偏移 %.1f" % max_drift)
	_expect("玩家没从平台上掉下去", not _player.is_dying)


func _test_one_way() -> void:
	var one_way: StaticBody2D = _level.get_node("Gimmicks/OneWay")
	_place_player(one_way.global_position + Vector2(0, -14))
	await _wait_physics(20)

	var resting_y := _player.global_position.y
	_expect("能站在单向平台上", absf(resting_y - 225.0) < 3.0, "y=%.1f" % resting_y)

	Input.action_press("move_down")
	Input.action_press("jump")
	await _wait_physics(2)
	Input.action_release("jump")
	await _wait_physics(20)
	Input.action_release("move_down")

	_expect("按「下 + 跳」能穿下去", _player.global_position.y > resting_y + 20.0,
			"y=%.1f" % _player.global_position.y)


func _test_stomp() -> void:
	var enemy := _level.get_node("Enemies/EnemyA")
	enemy.global_position = Vector2(240, 281)
	enemy.velocity = Vector2.ZERO

	var lives_before := GameState.lives
	_place_player(Vector2(240, 250), Vector2(0, 120))
	var bounced := false
	for i in 20:
		await get_tree().physics_frame
		if _player.velocity.y < 0.0:
			bounced = true
			break
	_expect("踩头后玩家被弹起", bounced)
	_expect_equal("踩头不扣命", GameState.lives, lives_before)
	await _wait_physics(60)


func _test_side_death() -> void:
	var enemy := _level.get_node("Enemies/EnemyB")
	enemy.global_position = Vector2(500, 281)

	var lives_before := GameState.lives
	_place_player(Vector2(500, 281))
	await _wait_physics(4)
	_expect("侧面接触立即死亡", _player.is_dying)

	await _wait_physics(50)
	_expect_equal("死亡扣一条命", GameState.lives, lives_before - 1)
	_expect("复活回检查点", _player.global_position.distance_to(Vector2(900, 268)) < 40.0,
			str(_player.global_position))
	await _wait_physics(40)


func _test_fall_out_death() -> void:
	var lives_before := GameState.lives
	_place_player(Vector2(320, 500))
	await _wait_physics(4)
	_expect("掉出关卡外算死亡", _player.is_dying)

	await _wait_physics(50)
	_expect_equal("掉坑扣一条命", GameState.lives, lives_before - 1)
	await _wait_physics(40)


func _test_game_over() -> void:
	while GameState.lives > 0:
		_place_player(Vector2(320, 500))
		await _wait_physics(4)
		await _wait_physics(50)

	await _wait_physics(4)
	_expect_equal("命数归零", GameState.lives, 0)
	_expect("命数耗尽后弹出失败遮罩", _level.get_node("HUD/GameOverPanel").visible)
	_expect("失败时游戏被暂停", get_tree().paused)


func _test_goal() -> void:
	# 失败流程已经把关卡置为结束状态，换一份干净的关卡测通关
	get_tree().paused = false
	_level.queue_free()
	await _wait_physics(3)

	_level = load("res://scenes/level_01.tscn").instantiate()
	add_child(_level)
	await _wait_physics(3)
	_player = _level.get_node("Player")

	# 先随便捡一个金币，确认通关面板会带上金币数
	_place_player(Vector2(150, 272))
	await _wait_physics(4)

	# 清掉已有成绩，确认这次通关真的写了一次盘
	GameState.best_time = 0.0
	_place_player(Vector2(1420, 252))
	await _wait_physics(4)
	_expect("到达终点弹出通关遮罩", _level.get_node("HUD/ClearPanel").visible)
	_expect("通关后记录了最佳成绩", GameState.best_time > 0.0, str(GameState.best_time))
	_expect("存档文件已写盘", FileAccess.file_exists(GameState.SAVE_PATH))


# ---------------------------------------------------------------- 工具

func _place_player(point: Vector2, velocity := Vector2.ZERO) -> void:
	_player.revive_at(point)
	_player.velocity = velocity


func _wait_physics(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


## 特效粒子都挂在关卡根节点下，数一遍就知道有没有溅出来
func _count_particles(node: Node) -> int:
	var count := 0
	for child in node.get_children():
		if child is CPUParticles2D:
			count += 1
	return count


func _start_watchdog() -> void:
	await get_tree().create_timer(60.0, true).timeout
	print("冒烟测试超时")
	get_tree().quit(2)


func _check(label: String, actual: float, expected: float, tolerance: float) -> void:
	_expect("%s（实测 %.1f，基线 %.1f）" % [label, actual, expected],
			absf(actual - expected) <= tolerance, "%.1f" % actual)


func _expect_equal(label: String, actual: int, expected: int) -> void:
	_expect(label, actual == expected, "实测 %d，期望 %d" % [actual, expected])


func _expect(label: String, ok: bool, detail := "") -> void:
	if ok:
		print("  [OK] ", label)
		return
	_failures.append("%s %s" % [label, detail])
	print("  [FAIL] ", label, " ", detail)


func _finish() -> void:
	# 测试不该在玩家目录里留下存档
	DirAccess.remove_absolute(GameState.SAVE_PATH)

	if _failures.is_empty():
		print("Phase 1 冒烟测试通过")
		get_tree().quit(0)
		return
	print("Phase 1 冒烟测试失败：")
	for failure in _failures:
		print("  - ", failure)
	get_tree().quit(1)
