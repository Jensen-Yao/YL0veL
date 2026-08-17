# -*- coding: utf-8 -*-
"""从主人完整录音中切多个候选片段，各克隆同一句测试文本，供试听择优。

用法（venv python）：
  D:\\Desktop\\模型管理\\venv\\Scripts\\python.exe scripts\\gen_candidates.py
输出：YL0veL/YL0veL/Y-voice/试听对比/candidate_*.mp3
"""
import base64
import json
import os
import subprocess
import sys
import urllib.request

BASE_URL = "http://127.0.0.1:11436"
FULL_WAV = r"D:\Desktop\模型管理\tmp_yvoice\master_full.wav"
OUT_DIR = r"F:\SelfSoftware\YL0veL\YL0veL\Y-voice\试听对比"
FFMPEG = r"F:\DramaClaw\runtime\ffmpeg\ffmpeg-9.0.1-essentials_build\bin\ffmpeg.exe"
WORK_DIR = r"D:\Desktop\模型管理\tmp_yvoice\candidates"

TEST_TEXT = "桃桃，我是管家 Y，今天也要记得多喝温水，早点休息哦。"

# (起始秒, 时长秒, 说明)
SEGMENTS = [
    (0.6, 12, "开头：自我介绍"),
    (10.5, 12, "中前段：日常嘱咐"),
    (20.5, 12, "中后段：关心身体"),
    (31.0, 12, "结尾：陪伴承诺"),
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
    if not os.path.exists(FULL_WAV):
        print(f"[candidates] 完整录音不存在: {FULL_WAV}", flush=True)
        sys.exit(1)
    os.makedirs(WORK_DIR, exist_ok=True)
    os.makedirs(OUT_DIR, exist_ok=True)

    for index, (start, length, desc) in enumerate(SEGMENTS, start=1):
        seg_path = os.path.join(WORK_DIR, f"seg_{index}.wav")
        subprocess.run(
            [FFMPEG, "-y", "-ss", str(start), "-t", str(length),
             "-i", FULL_WAV, "-ar", "24000", "-ac", "1", "-c:a", "pcm_s16le", seg_path],
            capture_output=True, timeout=60, check=True,
        )
        audio = synthesize(TEST_TEXT, seg_path)
        out_path = os.path.join(OUT_DIR, f"candidate_{index}.mp3")
        with open(out_path, "wb") as f:
            f.write(audio)
        print(f"[candidates] candidate_{index} ok ({desc}, {start}s 起 {length}s) ({len(audio)} bytes)", flush=True)

    # 同时保存每个片段本身，供参考
    for index, (start, length, desc) in enumerate(SEGMENTS, start=1):
        seg_path = os.path.join(WORK_DIR, f"seg_{index}.wav")
        import shutil
        shutil.copy(seg_path, os.path.join(OUT_DIR, f"片段{index}_{desc}.wav"))
    print("[candidates] done", flush=True)


if __name__ == "__main__":
    main()
