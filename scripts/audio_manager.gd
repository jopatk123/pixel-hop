extends Node
## 音效总管（autoload 名 Audio）：游戏里所有声音都从这里播。
## 文件按约定命名丢进 assets/audio/sfx/ 和 assets/audio/bgm/ 就能响，
## 找不到文件只是静默跳过，不会报错——方便先埋接入点、后补素材。

## 音效目录，文件名即 play() 传入的名字，支持 wav / ogg / mp3
const SFX_DIR := "res://assets/audio/sfx/"
## 背景音乐目录
const BGM_DIR := "res://assets/audio/bgm/"
## 同时能播放的音效条数，超出就按顺序顶掉最早的那个
const POOL_SIZE := 8
## 找不到文件时先试的扩展名，按顺序取第一个存在的
const EXTENSIONS := ["wav", "ogg", "mp3"]

const BGM_BUS := "BGM"
const SFX_BUS := "SFX"

var _pool: Array[AudioStreamPlayer] = []
var _next_player := 0
var _bgm_player: AudioStreamPlayer
var _cache := {}
var _reported := {}


func _ready() -> void:
	# 暂停时菜单音效、背景音乐仍要正常播放
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()

	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = SFX_BUS
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_pool.append(player)

	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = BGM_BUS
	_bgm_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_bgm_player)


## 播一个音效。缺文件时静默返回。
func play(sound: String, volume_db := 0.0, pitch_scale := 1.0) -> void:
	var stream := _load_stream(SFX_DIR, sound)
	if stream == null:
		return

	var player := _take_player()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()


## 切背景音乐，fade > 0 时淡入。同一首正在播就什么都不做。
func play_bgm(track: String, fade := 0.6) -> void:
	var stream := _load_stream(BGM_DIR, track)
	if stream == null:
		return
	if _bgm_player.stream == stream and _bgm_player.playing:
		return

	_enable_loop(stream)
	_bgm_player.stream = stream
	_bgm_player.volume_db = -30.0 if fade > 0.0 else 0.0
	_bgm_player.play()

	if fade > 0.0:
		var tween := create_tween()
		tween.tween_property(_bgm_player, "volume_db", 0.0, fade)


func stop_bgm(fade := 0.6) -> void:
	if not _bgm_player.playing:
		return

	if fade <= 0.0:
		_bgm_player.stop()
		return

	var tween := create_tween()
	tween.tween_property(_bgm_player, "volume_db", -30.0, fade)
	await tween.finished
	_bgm_player.stop()
	_bgm_player.volume_db = 0.0


## 运行时建 BGM / SFX 两条总线，省得再维护一份 default_bus_layout.tres
func _setup_buses() -> void:
	for bus_name in [BGM_BUS, SFX_BUS]:
		if AudioServer.get_bus_index(bus_name) != -1:
			continue
		var index := AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, "Master")


## 优先用空闲的播放器，全都在响就轮着顶掉最旧的一个
func _take_player() -> AudioStreamPlayer:
	for player in _pool:
		if not player.playing:
			return player

	var player := _pool[_next_player]
	_next_player = (_next_player + 1) % _pool.size()
	return player


## 弹性的加载：找不到就返回 null，并且缓存下来避免每帧都去查文件系统
func _load_stream(dir_path: String, sound: String) -> AudioStream:
	var key := dir_path + sound
	if _cache.has(key):
		return _cache[key]

	for extension in EXTENSIONS:
		var path := "%s%s.%s" % [dir_path, sound, extension]
		if ResourceLoader.exists(path):
			var stream: AudioStream = load(path)
			_cache[key] = stream
			return stream

	_cache[key] = null
	_report_missing(key)
	return null


## 调试构建下把缺哪些文件说清楚，免得写完接入点忘了丢素材
func _report_missing(key: String) -> void:
	if not OS.is_debug_build() or _reported.has(key):
		return
	_reported[key] = true
	print("缺少音频文件：%s.[wav / ogg / mp3]（丢进该目录即可自动生效）" % key)


## 背景音乐一律循环播放，省得每首曲子都去改导入设置
func _enable_loop(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif stream is AudioStreamOggVorbis:
		stream.loop = true
	elif stream is AudioStreamMP3:
		stream.loop = true
