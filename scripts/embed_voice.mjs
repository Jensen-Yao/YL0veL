// 把七夕语音 mp3 以 base64 嵌入 index.template.html（__VOICE_B64__）
// 用法: node scripts/embed_voice.mjs [voiceFile] [templateFile]
//   默认: voiceFile = qixi/qixi-voice.mp3, templateFile = qixi/index.template.html
import { readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';

const root = fileURLToPath(new URL('..', import.meta.url));
const [voiceFile = 'qixi/qixi-voice.mp3', templateFile = 'qixi/index.template.html'] = process.argv.slice(2);

async function main() {
  const [audio, template] = await Promise.all([
    readFile(resolve(root, voiceFile)),
    readFile(resolve(root, templateFile), 'utf8'),
  ]);
  if (!template.includes('__VOICE_B64__') && !/data:audio\/mpeg;base64,[A-Za-z0-9+/=]+/.test(template)) {
    throw new Error('模板中未找到 __VOICE_B64__ 占位符或已有音频');
  }
  // 幂等：先移除旧音频，再注入新音频
  const cleaned = template.replace(/data:audio\/mpeg;base64,[A-Za-z0-9+/=]+/, 'data:audio/mpeg;base64,__VOICE_B64__');
  const b64 = audio.toString('base64');
  await writeFile(resolve(root, templateFile), cleaned.replaceAll('__VOICE_B64__', b64), 'utf8');
  console.log('OK: embedded', b64.length, 'base64 chars (', audio.length, 'bytes ) into', templateFile);
}

main().catch((e) => { console.error(e); process.exit(1); });
