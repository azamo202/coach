import assert from 'node:assert/strict';
import { after, before, describe, it } from 'node:test';

import { createFakeAppleChain } from './helpers/fake_apple.mjs';

/**
 * اختبارات التحقق من توقيع Apple.
 *
 * الغاية الأهم هنا ليست إثبات أن التوقيع الصحيح يمرّ — بل إثبات أن كل
 * ما عداه **يُرفض**: التلاعب بالحمولة، سلسلة لا تنتهي لجذرنا، وغياب
 * مرساة الثقة أصلاً.
 */

let chain;
let jws;

before(async () => {
  chain = createFakeAppleChain();
  process.env.APPLE_ROOT_CA_PATH = chain.rootPath;
  jws = await import('../src/lib/apple/jws.js');
});

after(() => chain?.cleanup());

describe('verifyAppleJws', () => {
  it('يقبل توقيعاً سليماً من سلسلة تنتهي إلى الجذر الموثوق', () => {
    const signed = chain.sign({ transactionId: '2000000012345', productId: 'x' });
    const payload = jws.verifyAppleJws(signed);
    assert.equal(payload.transactionId, '2000000012345');
    assert.equal(payload.productId, 'x');
  });

  it('يرفض حمولة عُدّلت بعد التوقيع', () => {
    const signed = chain.sign({ transactionId: '111', productId: 'single' });
    const [head, , signature] = signed.split('.');
    const forged = Buffer.from(
      JSON.stringify({ transactionId: '111', productId: 'unlimited' }),
    ).toString('base64url');

    assert.throws(
      () => jws.verifyAppleJws(`${head}.${forged}.${signature}`),
      /لا يطابق الحمولة/,
    );
  });

  it('يرفض سلسلة لا تنتهي إلى الجذر الموثوق', () => {
    const stranger = createFakeAppleChain();
    try {
      assert.throws(
        () => jws.verifyAppleJws(stranger.sign({ transactionId: '999' })),
        /لا تنتهي إلى جذر Apple الموثوق/,
      );
    } finally {
      stranger.cleanup();
    }
  });

  it('يرفض الخوارزميات غير ES256 — لا مجال لـ alg:none', () => {
    const signed = chain.sign({ transactionId: '1' }, { header: { alg: 'none' } });
    assert.throws(() => jws.verifyAppleJws(signed), /خوارزمية توقيع غير مدعومة/);
  });

  it('يرفض الصيغ المشوّهة', () => {
    for (const bad of ['', 'abc', 'a.b', 'a.b.c.d', null, 42]) {
      assert.throws(() => jws.verifyAppleJws(bad), /صيغة توقيع Apple غير صحيحة/);
    }
  });

  it('decodeJwsUnsafe يقرأ بلا تحقق — ولا يُستخدم للثقة', () => {
    const signed = chain.sign({ transactionId: '777' });
    assert.equal(jws.decodeJwsUnsafe(signed).transactionId, '777');
    assert.equal(jws.decodeJwsUnsafe('not-a-jws'), null);
  });
});

describe('فشل مغلق حين تغيب مرساة الثقة', () => {
  it('يرفض التحقق إذا لم تكن شهادة الجذر مثبّتة', async () => {
    // نسخة معزولة من الوحدة بمسار جذر غير موجود.
    process.env.APPLE_ROOT_CA_PATH = './certs/__missing__.cer';
    const isolated = await import(`../src/lib/apple/jws.js?no-root=${Date.now()}`);

    assert.equal(isolated.isAppleRootAvailable(), false);
    assert.throws(
      () => isolated.verifyAppleJws(chain.sign({ transactionId: '1' })),
      (error) => error.code === 'apple_root_missing',
    );

    process.env.APPLE_ROOT_CA_PATH = chain.rootPath;
  });
});
