#!/usr/bin/env node
/**
 * 用 jsfxr（sfxr 的 JS 移植）生成 Pixel Hop 的音效，覆盖 assets/audio/sfx/*.wav。
 * 依赖同级仓库 ../jsfxr，用法：node tools/gen_sfx_jsfxr.js
 *
 * 各音效的时长与峰值对齐替换前的 gen_sfx.py 版本，保证游戏里的响度平衡不变。
 * 背景音乐不在本脚本范围内，仍由 tools/gen_sfx.py 生成。
 */

const fs = require("fs");
const path = require("path");

const jsfxr = require(path.join(__dirname, "..", "..", "jsfxr", "sfxr.js"));
const { Params, SoundEffect } = jsfxr;

const SFX_DIR = path.join(__dirname, "..", "assets", "audio", "sfx");
const SAMPLE_RATE = 44100;

// jsfxr 的波形枚举
const WAVE = { SQUARE: 0, SAWTOOTH: 1, SINE: 2, NOISE: 3 };

// 频率换算：hz = 3528 * (base^2 + 0.001)
// 包络时长换算：秒 = (attack^2 + sustain^2 + decay^2) * 100000 / 44100
// sustain 必须 > 0，否则 sfxr 的包络计算会出现 0/0
//
// ramp 的幅度要克制：sfxr 每样本做 period *= (1 - ramp^3 * 0.01)，是连乘而不是线性插值，
// 量级稍大就会在几十毫秒内把周期顶到上下限——上限 100000 变成次声波、下限 8 变成直流，
// 剩下的时长就只剩静音。想让整段扫频落在可听范围内，|ramp| 一般控制在 0.15 ~ 0.3。
const PRESETS = {
  // 起跳：正弦向上扫频（626 Hz → 约 2 kHz）
  jump: { wave: WAVE.SINE, base: 0.42, ramp: 0.30, sustain: 0.04, decay: 0.2062, peak: 0.350 },
  // 落地：低频噪声闷响
  land: {
    wave: WAVE.NOISE, base: 0.20, ramp: -0.22, punch: 0.35, sustain: 0.01, decay: 0.1754,
    lpf: 0.5, lpfRes: 0.2, peak: 0.272,
  },
  // 金币：方波 + 单次向上琶音
  coin: {
    wave: WAVE.SQUARE, duty: 0.25, base: 0.55, ramp: 0.28, sustain: 0.02, decay: 0.2477,
    arpSpeed: 0.55, arpMod: 0.35, peak: 0.220,
  },
  // 踩敌：比落地更重更低的噪声
  stomp: {
    wave: WAVE.NOISE, base: 0.18, ramp: -0.45, punch: 0.55, sustain: 0.02, decay: 0.2292,
    lpf: 0.45, lpfRes: 0.3, peak: 0.419,
  },
  // 受伤：噪声下滑，带一点高通提亮
  hurt: {
    wave: WAVE.NOISE, base: 0.30, ramp: -0.28, hpf: 0.15, sustain: 0.04, decay: 0.3089,
    peak: 0.380,
  },
  // 弹簧：方波大幅上扫 + 琶音，呼应弹起的手感（224 Hz → 约 830 Hz）
  spring: {
    wave: WAVE.SQUARE, duty: 0.35, base: 0.25, ramp: 0.22, sustain: 0.08, decay: 0.3422,
    arpSpeed: 0.6, arpMod: 0.4, peak: 0.300,
  },
  // 落下：正弦短下滑（515 Hz → 约 260 Hz）
  drop: { wave: WAVE.SINE, base: 0.38, ramp: -0.26, sustain: 0.01, decay: 0.1990, peak: 0.260 },
  // 存档点：方波向上琶音，比金币更长更亮
  checkpoint: {
    wave: WAVE.SQUARE, duty: 0.4, base: 0.35, ramp: 0.15, sustain: 0.10, decay: 0.3799,
    arpSpeed: 0.5, arpMod: 0.5, peak: 0.280,
  },
  // 暂停：短促的方波点按音
  pause: {
    wave: WAVE.SQUARE, duty: 0.5, base: 0.43, ramp: -0.15, hpf: 0.1, sustain: 0.02,
    decay: 0.1868, peak: 0.200,
  },
  // 通关：长音 + 琶音，做成简单的上行小号角
  clear: {
    wave: WAVE.SQUARE, duty: 0.45, base: 0.385, ramp: 0.08, sustain: 0.16, decay: 0.4658,
    arpSpeed: 0.45, arpMod: 0.55, peak: 0.260,
  },
  // 游戏结束：锯齿下滑，低沉收尾（443 Hz → 约 110 Hz）
  game_over: {
    wave: WAVE.SAWTOOTH, duty: 1, base: 0.353, ramp: -0.17, sustain: 0.14, decay: 0.5168,
    lpf: 0.7, lpfRes: 0.2, peak: 0.320,
  },
};


function buildParams(preset) {
  const p = new Params();
  p.wave_type = preset.wave;
  p.p_base_freq = preset.base;
  p.p_freq_ramp = preset.ramp || 0;
  p.p_freq_limit = 0;

  p.p_env_attack = preset.attack || 0;
  p.p_env_sustain = preset.sustain;
  p.p_env_punch = preset.punch || 0;
  p.p_env_decay = preset.decay;

  p.p_arp_speed = preset.arpSpeed || 0;
  p.p_arp_mod = preset.arpMod || 0;
  p.p_vib_strength = preset.vibStrength || 0;
  p.p_vib_speed = preset.vibSpeed || 0;

  p.p_duty = preset.duty || 0;
  p.p_lpf_freq = preset.lpf === undefined ? 1 : preset.lpf;
  p.p_lpf_resonance = preset.lpfRes || 0;
  p.p_hpf_freq = preset.hpf || 0;

  p.sound_vol = 0.5;
  p.sample_rate = SAMPLE_RATE;
  p.sample_size = 16;
  return p;
}


/** 渲染成浮点样本，并把峰值归一到 preset.peak（保持各音效之间的响度关系） */
function render(preset) {
  const samples = new SoundEffect(buildParams(preset)).getRawBuffer().normalized;

  let peak = 0;
  for (const s of samples) {
    const a = Math.abs(s);
    if (a > peak) peak = a;
  }
  const gain = peak > 0 ? preset.peak / peak : 0;

  const out = new Float64Array(samples.length);
  for (let i = 0; i < samples.length; i++) out[i] = samples[i] * gain;
  return out;
}


function writeWav(file, samples) {
  const data = Buffer.alloc(samples.length * 2);
  for (let i = 0; i < samples.length; i++) {
    const s = Math.max(-1, Math.min(1, samples[i]));
    data.writeInt16LE(Math.round(s * 32767), i * 2);
  }

  const header = Buffer.alloc(44);
  header.write("RIFF", 0);
  header.writeUInt32LE(36 + data.length, 4);
  header.write("WAVE", 8);
  header.write("fmt ", 12);
  header.writeUInt32LE(16, 16);
  header.writeUInt16LE(1, 20); // PCM
  header.writeUInt16LE(1, 22); // 单声道
  header.writeUInt32LE(SAMPLE_RATE, 24);
  header.writeUInt32LE(SAMPLE_RATE * 2, 28);
  header.writeUInt16LE(2, 32);
  header.writeUInt16LE(16, 34);
  header.write("data", 36);
  header.writeUInt32LE(data.length, 40);

  fs.writeFileSync(file, Buffer.concat([header, data]));
}


function main() {
  fs.mkdirSync(SFX_DIR, { recursive: true });

  for (const [name, preset] of Object.entries(PRESETS)) {
    const samples = render(preset);
    const file = path.join(SFX_DIR, `${name}.wav`);
    writeWav(file, samples);

    let peak = 0;
    for (const s of samples) {
      const a = Math.abs(s);
      if (a > peak) peak = a;
    }
    const duration = (samples.length / SAMPLE_RATE).toFixed(3);
    console.log(
      `${name.padEnd(12)} ${duration}s  peak=${peak.toFixed(3)}  ` +
      `(目标 ${preset.peak.toFixed(3)})  ${samples.length} 样本`
    );
  }
}


main();