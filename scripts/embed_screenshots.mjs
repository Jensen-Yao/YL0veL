// 把 App 界面截图以 base64 嵌入 content-plain.html 的 __SHOT_X__ 占位符
// 用法: node scripts/embed_screenshots.mjs [contentFile]
//   默认: contentFile = qixi/content-plain.html
// 截图: qixi/assets/shot-{calendar,cycle,insights,report,butler}.jpg
import { readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';

const root = fileURLToPath(new URL('..', import.meta.url));
const [contentFile = 'qixi/content-plain.html'] = process.argv.slice(2);

const SHOTS = {
  __SHOT_CALENDAR__: 'qixi/assets/shot-calendar.jpg',
  __SHOT_CYCLE__: 'qixi/assets/shot-cycle.jpg',
  __SHOT_INSIGHTS__: 'qixi/assets/shot-insights.jpg',
  __SHOT_REPORT__: 'qixi/assets/shot-report.jpg',
  __SHOT_BUTLER__: 'qixi/assets/shot-butler.jpg',
};

async function main() {
  let content = await readFile(resolve(root, contentFile), 'utf8');
  // 幂等：按出现顺序把已嵌入的旧 data URI 还原成占位符
  const uris = [...content.matchAll(/src="data:image\/jpeg;base64,[A-Za-z0-9+/=]+"/g)];
  const placeholders = Object.keys(SHOTS);
  if (uris.length === placeholders.length) {
    uris.forEach((m, i) => {
      content = content.replace(m[0], 'src="' + placeholders[i] + '"');
    });
  }
  for (const [ph, file] of Object.entries(SHOTS)) {
    if (!content.includes(ph)) {
      console.log('skip', ph, '(already embedded?)');
      continue;
    }
    const b64 = (await readFile(resolve(root, file))).toString('base64');
    content = content.replaceAll(ph, 'data:image/jpeg;base64,' + b64);
    console.log('embedded', ph, '<-', file, '(', b64.length, 'chars )');
  }
  await writeFile(resolve(root, contentFile), content, 'utf8');
  console.log('OK ->', contentFile);
}

main().catch((e) => { console.error(e); process.exit(1); });
