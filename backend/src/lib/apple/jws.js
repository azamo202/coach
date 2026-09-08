import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

/**
 * التحقق من تواقيع Apple (JWS / x5c).
 *
 * كل ما يصل من StoreKit ومن App Store Server Notifications يأتي على هيئة
 * JWS موقّع من Apple. التحقق يمرّ بثلاث مراحل لا يجوز إسقاط أي منها:
 *
 *   1. سلسلة الشهادات في ترويسة `x5c` تنتهي إلى جذر Apple الموثوق لدينا.
 *   2. كل شهادة في السلسلة موقّعة فعلاً من التي تليها، وصالحة زمنياً.
 *   3. توقيع الـJWS نفسه صحيح بمفتاح الشهادة الطرفية (ES256 بصيغة P1363).
 *
 * الملف يفشل **مغلقاً**: إذا لم يوجد جذر Apple لا نتحقق ولا نثق، ولا نمرّر
 * الحمولة. هذا مهم تحديداً في مسار الـwebhook لأنه مسار عام بلا مصادقة.
 */

const ROOT_PATH = process.env.APPLE_ROOT_CA_PATH || './certs/AppleRootCA-G3.cer';

/** شهادة جذر Apple — تُحمَّل مرة واحدة وتُخزَّن. */
let _rootCache;

export class AppleVerificationError extends Error {
  constructor(message, code = 'apple_jws_invalid') {
    super(message);
    this.name = 'AppleVerificationError';
    this.code = code;
  }
}

/**
 * يحمّل جذر Apple Root CA - G3 من القرص (DER أو PEM).
 * يُرجع `null` إن لم يكن موجوداً — والمستدعي هو من يقرر كيف يفشل.
 */
export function loadAppleRoot() {
  if (_rootCache !== undefined) return _rootCache;

  const file = path.resolve(ROOT_PATH);
  try {
    const raw = fs.readFileSync(file);
    _rootCache = new crypto.X509Certificate(raw);
  } catch (error) {
    if (error?.code !== 'ENOENT') {
      console.error(`[apple] تعذّر قراءة شهادة الجذر من ${file}:`, error?.message || error);
    }
    _rootCache = null;
  }
  return _rootCache;
}

export function isAppleRootAvailable() {
  return loadAppleRoot() !== null;
}

/** يفكّ ترميز مقطع base64url إلى نص UTF-8. */
function b64urlToString(segment) {
  return Buffer.from(segment, 'base64url').toString('utf8');
}

/** يقرأ حمولة JWS **بدون** تحقق. للتشخيص والسجلات فقط — لا للثقة. */
export function decodeJwsUnsafe(jws) {
  if (typeof jws !== 'string') return null;
  const parts = jws.split('.');
  if (parts.length !== 3) return null;
  try {
    return JSON.parse(b64urlToString(parts[1]));
  } catch {
    return null;
  }
}

function certValidNow(cert, now) {
  const from = cert.validFromDate ?? new Date(cert.validFrom);
  const to = cert.validToDate ?? new Date(cert.validTo);
  return now >= from.getTime() && now <= to.getTime();
}

/**
 * يتحقق من سلسلة `x5c` وينتهي بها إلى جذر Apple.
 * يُرجع الشهادة الطرفية (leaf) عند النجاح، ويرمي خطأً عند أي خلل.
 */
function verifyCertificateChain(x5c, now) {
  if (!Array.isArray(x5c) || x5c.length < 2) {
    throw new AppleVerificationError('ترويسة x5c ناقصة في توقيع Apple.');
  }

  const root = loadAppleRoot();
  if (!root) {
    throw new AppleVerificationError(
      'شهادة Apple Root CA - G3 غير مثبّتة على الخادم. شغّل: npm run fetch:apple-root',
      'apple_root_missing',
    );
  }

  let chain;
  try {
    chain = x5c.map((b64) => new crypto.X509Certificate(Buffer.from(b64, 'base64')));
  } catch {
    throw new AppleVerificationError('سلسلة شهادات Apple غير قابلة للقراءة.');
  }

  // آخر عنصر في السلسلة يجب أن يكون جذر Apple نفسه — مقارنة بايت ببايت.
  const presentedRoot = chain[chain.length - 1];
  if (!presentedRoot.raw.equals(root.raw)) {
    throw new AppleVerificationError('سلسلة التوقيع لا تنتهي إلى جذر Apple الموثوق.');
  }

  for (const cert of chain) {
    if (!certValidNow(cert, now)) {
      throw new AppleVerificationError('إحدى شهادات Apple منتهية أو غير سارية بعد.');
    }
  }

  // كل شهادة موقّعة من التي تليها، والجذر موقّع ذاتياً.
  for (let i = 0; i < chain.length - 1; i++) {
    const child = chain[i];
    const issuer = chain[i + 1];
    if (!child.checkIssued(issuer) || !child.verify(issuer.publicKey)) {
      throw new AppleVerificationError('سلسلة شهادات Apple غير متّصلة.');
    }
  }
  if (!root.verify(root.publicKey)) {
    throw new AppleVerificationError('جذر Apple المثبّت غير صالح.');
  }

  return chain[0];
}

/**
 * يتحقق من JWS موقّع من Apple ويُرجع حمولته.
 *
 * @param {string} jws التوقيع الكامل بصيغة `header.payload.signature`.
 * @returns {object} الحمولة بعد التحقق الكامل.
 */
export function verifyAppleJws(jws) {
  if (typeof jws !== 'string' || jws.split('.').length !== 3) {
    throw new AppleVerificationError('صيغة توقيع Apple غير صحيحة.');
  }

  const [headerB64, payloadB64, signatureB64] = jws.split('.');

  let header;
  try {
    header = JSON.parse(b64urlToString(headerB64));
  } catch {
    throw new AppleVerificationError('ترويسة توقيع Apple غير قابلة للقراءة.');
  }

  if (header.alg !== 'ES256') {
    throw new AppleVerificationError(`خوارزمية توقيع غير مدعومة: ${header.alg}`);
  }

  const leaf = verifyCertificateChain(header.x5c, Date.now());

  // JWS يستخدم توقيعاً خاماً R||S، لا DER — لذلك ieee-p1363.
  const ok = crypto
    .createVerify('SHA256')
    .update(`${headerB64}.${payloadB64}`)
    .verify(
      { key: leaf.publicKey, dsaEncoding: 'ieee-p1363' },
      Buffer.from(signatureB64, 'base64url'),
    );

  if (!ok) {
    throw new AppleVerificationError('توقيع Apple لا يطابق الحمولة.');
  }

  try {
    return JSON.parse(b64urlToString(payloadB64));
  } catch {
    throw new AppleVerificationError('حمولة توقيع Apple غير قابلة للقراءة.');
  }
}
