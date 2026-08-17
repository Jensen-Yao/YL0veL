// 生成主人声线的七夕祝福语音（CosyVoice 零样本克隆 candidate_1）
// 用法: node scripts/gen_birthday_voice.mjs [outputFile]
//   默认输出: birthday/birthday-voice.mp3
import { readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';

const root = fileURLToPath(new URL('..', import.meta.url));
const REF = resolve(root, 'YL0veL/Y-voice/master_prompt.wav');
const OUT = process.argv[2] ? resolve(process.argv[2]) : resolve(root, 'birthday/birthday-voice.mp3');

const TEXT = [
  '桃桃，七夕快乐。',
  '我是你的主人，今天让管家Y把你带到这里，是想亲口对你说一句话：这一年，辛苦啦，我的女孩。',
  '以后每一个我不在身边的晚上，管家Y都会替我陪着你，提醒你早睡，给你念晚安，在你肚子疼的时候，第一时间告诉我。',
  '星河很长，我们慢慢走。',
  '桃桃，我爱你。',
].join('');

async function main() {
  const refBuf = await readFile(REF);
  const refB64 = refBuf.toString('base64');

  const body = {
    model: 'index-tts-2',
    input: TEXT,
    metadata: { audio_url: 'data:audio/wav;base64,' + refB64 },
  };

  console.log('requesting TTS, text length:', TEXT.length);
  const t0 = Date.now();
  let resp;
  for (let attempt = 1; attempt <= 6; attempt++) {
    try {
      resp = await fetch('http://127.0.0.1:11436/v1/audio/speech', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      });
      break;
    } catch (e) {
      console.log(`attempt ${attempt} failed (${e.message}), waiting 20s...`);
      if (attempt === 6) throw e;
      await new Promise((r) => setTimeout(r, 20000));
    }
  }
  if (!resp.ok) {
    const errText = await resp.text();
    throw new Error('TTS HTTP ' + resp.status + ': ' + errText.slice(0, 400));
  }
  const audio = Buffer.from(await resp.arrayBuffer());
  await writeFile(OUT, audio);
  console.log('OK ->', OUT, '| bytes:', audio.length, '| took:', ((Date.now() - t0) / 1000).toFixed(1) + 's');
}

main().catch((e) => { console.error(e); process.exit(1); });
