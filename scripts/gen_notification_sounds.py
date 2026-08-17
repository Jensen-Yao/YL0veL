# -*- coding: utf-8 -*-
"""生成主人语音通知铃声（<30 秒 wav，iOS 自定义通知音要求）。

用法（用 venv python 运行）：
  D:\\Desktop\\模型管理\\venv\\Scripts\\python.exe scripts\\gen_notification_sounds.py
输出：YL0veL/YL0veL/Resources/NotificationSounds/*.wav
"""
import base64
import json
import os
import subprocess
import sys
import time
import urllib.request

BASE_URL = "http://127.0.0.1:11436"
REF_WAV = r"D:\Desktop\模型管理\tmp_yvoice\ref_20260817_030509.wav"  # 已选定的主人参考音
OUT_DIR = r"F:\SelfSoftware\YL0veL\YL0veL\Resources\NotificationSounds"
FFMPEG = r"F:\DramaClaw\runtime\ffmpeg\ffmpeg-9.0.1-essentials_build\bin\ffmpeg.exe"

# 通知铃声文案（短句，<10 秒合成；文件名即通知音名）
LINES = [
    ("y_message", "桃桃，管家 Y 有消息哦，快来看看吧。"),
    ("y_reminder", "桃桃，管家 Y 提醒你啦，要记得哦。"),
    ("y_period", "桃桃，经期要到啦，管家 Y 已经准备好啦。"),
    ("y_goodnight", "桃桃，晚安，早点休息。"),
]


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
    if not os.path.exists(REF_WAV):
        print(f"[gen-notif] 参考音不存在: {REF_WAV}", flush=True)
        sys.exit(1)
    os.makedirs(OUT_DIR, exist_ok=True)
    for key, text in LINES:
        mp3_path = os.path.join(OUT_DIR, f"{key}.mp3")
        wav_path = os.path.join(OUT_DIR, f"{key}.wav")
        if not os.path.exists(mp3_path):
            audio = synthesize(text, REF_WAV)
            with open(mp3_path, "wb") as f:
                f.write(audio)
            print(f"[gen-notif] {key}.mp3 ok ({len(audio)} bytes)", flush=True)
            time.sleep(0.3)
        if not os.path.exists(wav_path):
            subprocess.run(
                [FFMPEG, "-y", "-i", mp3_path, "-ar", "22050", "-ac", "1", "-c:a", "pcm_s16le", wav_path],
                capture_output=True, timeout=60, check=True,
            )
            size = os.path.getsize(wav_path)
            print(f"[gen-notif] {key}.wav ok ({size} bytes)", flush=True)
            if size > 30 * 22050 * 2:  # 超过 30 秒提醒
                print(f"[gen-notif] WARNING: {key}.wav 超过 30 秒，需截断", flush=True)
    print("[gen-notif] done", flush=True)


if __name__ == "__main__":
    main()
