# -*- coding: utf-8 -*-
"""用本机 CosyVoice3 TTS 服务（127.0.0.1:11436）批量生成「管家 Y」主人语音包。

流程：探活 → Y-voice 样本转 wav → 选参考音 → 逐条零样本克隆 → 输出 mp3 到 App Resources/YVoice。
用法（用 venv python 运行）：
  D:\\Desktop\\模型管理\\venv\\Scripts\\python.exe scripts\\gen_yvoice.py
"""
import base64
import json
import os
import subprocess
import sys
import time
import urllib.request

BASE_URL = "http://127.0.0.1:11436"
YVOICE_DIR = r"F:\SelfSoftware\YL0veL\YL0veL\Y-voice"
OUT_DIR = r"F:\SelfSoftware\YL0veL\YL0veL\Resources\YVoice"
LINES_FILE = r"F:\SelfSoftware\YL0veL\scripts\voice_lines.json"
FFMPEG = r"F:\DramaClaw\runtime\ffmpeg\ffmpeg-9.0.1-essentials_build\bin\ffmpeg.exe"
FFPROBE = r"F:\DramaClaw\runtime\ffmpeg\ffmpeg-9.0.1-essentials_build\bin\ffprobe.exe"
WORK_DIR = r"D:\Desktop\模型管理\tmp_yvoice"


def log(msg):
    print(f"[gen-yvoice] {msg}", flush=True)


def health_ok():
    try:
        with urllib.request.urlopen(f"{BASE_URL}/health", timeout=5) as resp:
            return resp.status == 200
    except Exception as exc:
        log(f"health check failed: {exc}")
        return False


def probe_duration(path: str) -> float:
    out = subprocess.run(
        [FFPROBE, "-v", "quiet", "-show_entries", "format=duration",
         "-of", "default=noprint_wrappers=1:nokey=1", path],
        capture_output=True, text=True, timeout=30,
    )
    try:
        return float(out.stdout.strip())
    except ValueError:
        return 0.0


def convert_to_wav(src: str, dst: str):
    subprocess.run(
        [FFMPEG, "-y", "-i", src, "-ar", "24000", "-ac", "1", "-c:a", "pcm_s16le", dst],
        capture_output=True, timeout=120, check=True,
    )


def pick_reference() -> str:
    """在 Y-voice 的 5 段样本中选时长 3~15 秒的一段（取最长，供零样本克隆）。"""
    os.makedirs(WORK_DIR, exist_ok=True)
    candidates = []
    for name in sorted(os.listdir(YVOICE_DIR)):
        if not name.lower().endswith((".m4a", ".wav", ".mp3")):
            continue
        src = os.path.join(YVOICE_DIR, name)
        wav = os.path.join(WORK_DIR, "ref_" + os.path.splitext(name)[0] + ".wav")
        convert_to_wav(src, wav)
        duration = probe_duration(wav)
        log(f"sample {name}: {duration:.1f}s -> {wav}")
        if 3.0 <= duration <= 15.0:
            candidates.append((duration, wav))
    if not candidates:
        # 兜底：取最长的一段
        all_wavs = []
        for name in sorted(os.listdir(YVOICE_DIR)):
            if name.lower().endswith((".m4a", ".wav", ".mp3")):
                wav = os.path.join(WORK_DIR, "ref_" + os.path.splitext(name)[0] + ".wav")
                all_wavs.append((probe_duration(wav), wav))
        candidates = all_wavs
    candidates.sort(key=lambda x: x[0])
    chosen = candidates[-1][1]
    log(f"reference chosen: {chosen} ({candidates[-1][0]:.1f}s)")
    return chosen


def synthesize(text: str, reference_wav: str) -> bytes:
    with open(reference_wav, "rb") as f:
        ref_b64 = base64.b64encode(f.read()).decode("ascii")
    body = json.dumps({
        "model": "index-tts-2",
        "input": text,
        "metadata": {"audio_url": f"data:audio/wav;base64,{ref_b64}"},
    }).encode("utf-8")
    req = urllib.request.Request(
        f"{BASE_URL}/v1/audio/speech",
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=300) as resp:
        return resp.read()


def main():
    if not health_ok():
        log("TTS 服务不可达，请确认 watchdog 在运行（端口 11436）")
        sys.exit(1)

    reference = pick_reference()
    with open(LINES_FILE, "r", encoding="utf-8") as f:
        lines = json.load(f)

    os.makedirs(OUT_DIR, exist_ok=True)
    failed = []
    t0 = time.time()
    for index, line in enumerate(lines):
        key = line["key"]
        text = line["text"]
        out_path = os.path.join(OUT_DIR, f"{key}.mp3")
        try:
            audio = synthesize(text, reference)
            with open(out_path, "wb") as f:
                f.write(audio)
            log(f"[{index + 1}/{len(lines)}] {key} ok ({len(audio)} bytes)")
        except Exception as exc:
            log(f"[{index + 1}/{len(lines)}] {key} FAILED: {exc}")
            failed.append(key)
        time.sleep(0.3)

    elapsed = time.time() - t0
    log(f"done in {elapsed:.0f}s; failed: {failed if failed else 'none'}")
    if failed:
        sys.exit(1)


if __name__ == "__main__":
    main()
