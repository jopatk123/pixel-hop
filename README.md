# Pixel Hop

个人爱好向的 2D 平台跳跃小游戏，用 Godot 4.7 做着玩、顺便练手，**不打算对外发布**。

目前处于**垂直切片**阶段：一个能从头玩到尾的关卡已经跑通，正在打磨手感、音效和反馈层。
画面是程序生成的占位色块；音效与 BGM 已随仓库附带（由 `tools/gen_sfx.py` 生成），克隆即可听到声音。

## 操作

| 动作 | 按键 |
| --- | --- |
| 左右移动 | `←` `→` / `A` `D` |
| 跳跃 | `空格` / `↑` / `W`（按住越久跳得越高） |
| 下穿单向平台 | `↓` 或 `S` + 跳跃 |
| 暂停 | `Esc` |
| 重玩 | `R`（结算或失败后） |

按键全部走 InputMap，之后接手柄不用改代码。

## 运行

需要 [Godot 4.7](https://godotengine.org/download)。

```bash
git clone https://github.com/jopatk123/pixel-hop.git
cd pixel-hop
godot --path . --import   # 首次导入，生成 .godot/ 缓存
godot --path .            # 开玩
```

也可以直接用 Godot 编辑器打开 `project.godot`，按 F5。

视口 640×360，窗口按 2 倍放大显示。

## 关卡里有什么

- **金币** —— 拾取计数，带星芒粒子
- **巡逻敌人** —— 从上方踩死并把玩家弹起，从侧面碰到则玩家死亡
- **检查点** —— 点亮后成为新的复活点
- **弹簧** —— 踩上去弹得比普通跳跃高得多
- **移动平台** —— 往返移动并带动玩家
- **单向平台** —— 可从下方穿过，按「下 + 跳」也能主动穿下去
- **终点** —— 结算用时与金币，记录最佳成绩

## 目录结构

```
scenes/            场景文件，一个游戏对象一个 .tscn
scripts/           所有 GDScript
  player.gd          玩家：手感参数全部暴露在检查器上
  level.gd           关卡编排：计时、检查点、扣命复活、通关结算
  game_state.gd      全局状态与存档（autoload: GameState）
  audio_manager.gd   音效总管（autoload: Audio）
  effects.gd         一次性粒子特效
  game_camera.gd     带震屏的相机
assets/audio/      音效与背景音乐（wav）
tools/gen_sfx.py   程序化生成全部音效与 BGM
test_phase1.gd     无头模式冒烟测试
```

## 怎么调手感

跳跃不用对着重力数值调，改这三个就够：

- `jump_height` —— 跳多高（像素）
- `jump_time_to_peak` —— 从起跳到最高点用多久，越短越脆
- `jump_time_to_descent` —— 从最高点落回地面用多久，短于上升时间更有重量感

重力由它们反推。选中 `scenes/player.tscn` 的根节点，在检查器里改完立刻能在游戏里试。
另外还有土狼时间、跳跃缓冲、最高点滞空、可变跳跃高度等参数，都挂在一起。

### 反馈与镜头

- **玩家**（`player.gd` → 检查器「反馈」）：`death_shake_strength`、`land_shake_strength`、
  `death_hit_stop_duration` / `death_hit_stop_scale`、`flash_duration`、`turn_dust_speed_threshold`
- **敌人**（`enemy.gd` →「反馈」）：踩头顿帧与震屏 `stomp_hit_stop_*`、`stomp_shake_strength`
- **相机**（`game_camera.gd`）：`look_ahead_distance`、`look_ahead_speed`、
  `vertical_deadzone`、`vertical_follow_speed`、`default_shake_duration`

粒子种类与颜色集中在 `effects.gd` 顶部的常量字典里。

## 音效

代码里的接入点已全部接好；仓库内已有程序化生成的 wav，**缺文件时仍会静默跳过**（调试构建会打印提示）。

- 音效 → `assets/audio/sfx/`，文件名即音效名：
  `jump` `land` `coin` `stomp` `hurt` `spring` `drop` `checkpoint` `pause` `clear` `game_over`
- 背景音乐 → `assets/audio/bgm/level_01`（循环播放，音量低于 SFX 总线）

### 重新生成音频

需要改音色时，只动生成器顶部的参数，然后：

```bash
python3 tools/gen_sfx.py
godot --path . --import   # 让 Godot 重新导入 wav
```

`tools/gen_sfx.py` 仅用 Python 标准库，合成 sfxr 风格的短音效和约 8 小节的 chiptune BGM（128 BPM，整小节循环）。

也支持自行替换为 wav / ogg / mp3（例如 [sfxr.me](https://sfxr.me) 导出的素材），文件名保持一致即可。

## 测试

```bash
godot --headless --path . res://test_phase1.tscn
```

一套冒烟测试，覆盖跳跃高度与水平速度基线、金币、检查点、弹簧、移动平台、单向平台下穿、
踩敌、侧碰死亡、掉坑死亡、命数耗尽、通关结算与写盘，以及**全部 11 个音效 + BGM 是否加载**、
粒子特效、相机前瞻参数与震屏。
全过时退出码为 0，有失败项会打印具体是哪条。

## 开发进度

- [x] Phase 0 手感原型 —— 跳跃手感与基线测量
- [x] Phase 1 系统与流程 —— 金币 / 命数 / 计时 / 检查点 / 结算 / 存档
- [x] Phase 2 垂直切片 —— 程序化音效/BGM、顿帧与粒子反馈、镜头前瞻（关卡节奏仍可调）
- [ ] Phase 3 内容扩展 —— 多几关、加自己觉得好玩的机制与节奏变化
- [ ] Phase 4 打磨与自用 —— 替换占位美术与 BGM/SFX，导出 Mac 桌面版在自己机器上玩

## 许可

代码以 MIT 许可发布，见 [LICENSE](LICENSE)。
