#!/usr/bin/env node
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

/**
 * ينزّل شهادة Apple Root CA - G3 ويثبّتها في `certs/`.
 *
 * هذه الشهادة هي مرساة الثقة التي نتحقق بها من كل توقيع يصل من Apple:
 * عمليات StoreKit وإشعارات خادم App Store. بدونها يرفض الخادم الإشعارات
 * بدل أن يثق بها — وهو السلوك الصحيح، لكنه يعني أن التجديدات لن تُسجَّل.
 *
 * التشغيل:  npm run fetch:apple-root
 */

const URL = 'https://www.apple.com/certificateauthority/AppleRootCA-G3.cer';
const OUT = process.env.APPLE_ROOT_CA_PATH || './certs/AppleRootCA-G3.cer';

async function main() {
  const target = path.resolve(OUT);
  console.log(`تنزيل شهادة جذر Apple من:\n  ${URL}`);

  const response = await fetch(URL, { signal: AbortSignal.timeout(30000) });
  if (!response.ok) {
    throw new Error(`فشل التنزيل: HTTP ${response.status}`);
  }

  const bytes = Buffer.from(await response.arrayBuffer());
  if (bytes.length === 0) {
    throw new Error('الملف المنزَّل فارغ.');
  }

  // لا نكتب شيئاً قبل أن نتأكد أنه شهادة X.509 صالحة وموقّعة ذاتياً.
  let cert;
  try {
    cert = new crypto.X509Certificate(bytes);
  } catch {
    throw new Error('الملف المنزَّل ليس شهادة X.509 صالحة.');
  }

  if (!cert.verify(cert.publicKey)) {
    throw new Error('الشهادة ليست موقّعة ذاتياً — ليست جذراً.');
  }
  if (!/Apple/i.test(cert.subject)) {
    throw new Error(`جهة الشهادة غير متوقعة:\n${cert.subject}`);
  }

  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, bytes);

  const fingerprint = cert.fingerprint256;
  console.log('\nتم التثبيت ✓');
  console.log(`  المسار:   ${target}`);
  console.log(`  الجهة:    ${cert.subject.replace(/\n/g, ' | ')}`);
  console.log(`  صالحة حتى: ${cert.validTo}`);
  console.log(`  البصمة:   ${fingerprint}`);
  console.log('\nقارن البصمة بما تنشره Apple على صفحة سلطة الشهادات قبل النشر.');
}

main().catch((error) => {
  console.error(`\nفشل: ${error.message}`);
  console.error(
    '\nيمكنك التنزيل يدوياً من https://www.apple.com/certificateauthority/ ' +
      `ثم حفظ الملف في ${path.resolve(OUT)}`,
  );
  process.exit(1);
});
