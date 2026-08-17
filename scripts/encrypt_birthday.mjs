// 加密生日页面内容，生成最终 index.html
// 用法: node scripts/encrypt_birthday.mjs <password> [contentFile] [templateFile]
//   默认: contentFile = birthday/content-plain.html, templateFile = birthday/index.template.html
// 输出: birthday/index.html (已注入密文)
import { webcrypto } from 'node:crypto';
import { readFile, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const crypto = webcrypto;

const [password = 'taotao', contentFile = 'birthday/content-plain.html', templateFile = 'birthday/index.template.html'] = process.argv.slice(2);

const root = fileURLToPath(new URL('..', import.meta.url));

async function main() {
  const contentPath = resolve(root, contentFile);
  const templatePath = resolve(root, templateFile);
  const outPath = resolve(root, 'birthday/index.html');

  const [plainText, template] = await Promise.all([
    readFile(contentPath, 'utf8'),
    readFile(templatePath, 'utf8'),
  ]);

  const enc = new TextEncoder();
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const iterations = 600000;

  const keyMaterial = await crypto.subtle.importKey('raw', enc.encode(password), 'PBKDF2', false, ['deriveKey']);
  const key = await crypto.subtle.deriveKey(
    { name: 'PBKDF2', salt, iterations, hash: 'SHA-256' },
    keyMaterial,
    { name: 'AES-GCM', length: 256 },
    false,
    ['encrypt']
  );
  const ct = await crypto.subtle.encrypt(
    { name: 'AES-GCM', iv },
    key,
    enc.encode(plainText)
  );

  const b64 = (buf) => Buffer.from(buf).toString('base64');
  const payload = JSON.stringify({
    salt: b64(salt),
    iv: b64(iv),
    ct: b64(ct),
    iterations,
  });

  if (!template.includes('__ENCRYPTED__')) {
    throw new Error('模板中未找到 __ENCRYPTED__ 占位符: ' + templatePath);
  }
  const outHtml = template.replaceAll('__ENCRYPTED__', payload);
  await writeFile(outPath, outHtml, 'utf8');
  console.log('OK ->', outPath);
  console.log('password:', password, '| iterations:', iterations, '| ct bytes:', ct.byteLength);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
