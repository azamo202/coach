import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import net from 'node:net';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { after, before, describe, it } from 'node:test';

/**
 * اختبار طرفي للبوابات عبر HTTP حقيقي.
 *
 * الاختبارات الأخرى تفحص المنطق مباشرة. هذا يفحص ما يراه التطبيق فعلاً:
 * رموز الحالة، وأشكال الردود، وأن البوابة تعمل بعد مرورها بكل الوسائط —
 * لا في استدعاء دالة معزول.
 */

const HERE = path.dirname(fileURLToPath(import.meta.url));
const SERVER = path.join(HERE, '..', 'src', 'server.js');

let child;
let baseUrl;
let dbDir;
let token;

/** يحجز منفذاً حراً ثم يطلقه — يتجنّب تصادم المنافذ في التشغيل المتوازي. */
function freePort() {
  return new Promise((resolve, reject) => {
    const server = net.createServer();
    server.once('error', reject);
    server.listen(0, '127.0.0.1', () => {
      const { port } = server.address();
      server.close(() => resolve(port));
    });
  });
}

async function waitForHealth(url, timeoutMs = 20000) {
  const deadline = Date.now() + timeoutMs;
  for (;;) {
    try {
      const response = await fetch(`${url}/health`);
      if (response.ok) return;
    } catch {
      /* الخادم لم يقلع بعد */
    }
    if (Date.now() > deadline) throw new Error('الخادم لم يستجب في الوقت المحدد.');
    await new Promise((resolve) => setTimeout(resolve, 200));
  }
}

async function api(method, endpoint, body, { auth = true } = {}) {
  const response = await fetch(baseUrl + endpoint, {
    method,
    headers: {
      'content-type': 'application/json',
      ...(auth && token ? { authorization: `Bearer ${token}` } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await response.text();
  let json = {};
  if (text) {
    try {
      json = JSON.parse(text);
    } catch {
      json = { raw: text };
    }
  }
  return { status: response.status, body: json };
}

before(async () => {
  dbDir = fs.mkdtempSync(path.join(os.tmpdir(), 'coachmint-api-'));
  const port = await freePort();
  baseUrl = `http://127.0.0.1:${port}`;

  child = spawn(process.execPath, [SERVER], {
    env: {
      ...process.env,
      PORT: String(port),
      DATABASE_FILE: path.join(dbDir, 'api.db'),
      JWT_SECRET: 'test-secret-for-api-gates',
      // وضع وهمي: لا نداءات مدفوعة نحو OpenAI أثناء الاختبار.
      MOCK_AI: 'true',
      OPENAI_API_KEY: '',
      // بلا إعداد Apple: كل مستخدم على الخطة المجانية — وهو المسار الذي
      // نريد إثبات إغلاقه.
      APPLE_KEY_ID: '',
      APPLE_ISSUER_ID: '',
      APPLE_PRIVATE_KEY: '',
      APPLE_PRIVATE_KEY_PATH: '',
      NODE_ENV: 'test',
    },
    stdio: ['ignore', 'pipe', 'pipe'],
  });

  child.stderr.on('data', (chunk) => {
    const line = chunk.toString().trim();
    if (line) console.error('[server]', line);
  });

  await waitForHealth(baseUrl);

  const registered = await api(
    'POST',
    '/auth/register',
    { name: 'مستخدم اختبار', email: `t${Date.now()}@coachmint.app`, password: 'password123' },
    { auth: false },
  );
  assert.equal(registered.status, 201, JSON.stringify(registered.body));
  token = registered.body.token;
});

after(async () => {
  child?.kill();
  await new Promise((resolve) => setTimeout(resolve, 300));
  fs.rmSync(dbDir, { recursive: true, force: true });
});

// ---------------------------------------------------------------------

describe('حساب جديد', () => {
  it('يحصل على رمز حساب صالح لـApple', async () => {
    const { status, body } = await api('GET', '/auth/me');
    assert.equal(status, 200);
    assert.match(
      body.user.appAccountToken,
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/,
      'Apple ترفض appAccountToken الذي ليس UUID',
    );
  });

  it('يبدأ مقفولاً بالكامل — لا حصص ولا تجربة', async () => {
    const { status, body } = await api('GET', '/subscriptions/me');
    assert.equal(status, 200);
    assert.equal(body.entitlement.planId, 'free');
    assert.equal(body.entitlement.isSubscribed, false);
    assert.equal(body.entitlement.canCreateProgram, false);
    assert.equal(body.entitlement.programSlots, 0);
    assert.equal(body.entitlement.freeGenerationsLimit, 0);
  });
});

describe('بوابة التوليد', () => {
  it('يرفض أول توليد لحساب جديد برمز 402 لا 401', async () => {
    const { status, body } = await api('POST', '/ai/program', {
      sport: 'كرة قدم',
      level: 'beginner',
      goal: 'general',
    });

    // 402 مقصود: 401/403 يجعلان التطبيق يُخرج المستخدم من حسابه بدل
    // أن يعرض صفحة الاشتراك.
    assert.equal(status, 402, JSON.stringify(body));
    assert.equal(body.code, 'subscription_required');
    assert.equal(body.entitlement.isSubscribed, false);
    assert.equal(body.entitlement.programSlots, 0);
  });

  it('لا يستهلك حصة ولا يسجّل توليدة عند الرفض', async () => {
    const { body } = await api('GET', '/subscriptions/me');
    assert.equal(body.entitlement.activePrograms, 0);
    assert.equal(body.entitlement.freeGenerationsUsed, 0);
  });

  it('الرفض يقع قبل أي نداء للذكاء الاصطناعي', async () => {
    // لو مرّ الطلب إلى المولّد لظهر في سجل الاستهلاك.
    const { body } = await api('GET', '/programs');
    assert.equal(body.programs.length, 0);
  });
});

describe('بوابة المدرّب الذكي', () => {
  it('مغلقة على غير المشتركين', async () => {
    const { status, body } = await api('POST', '/ai/coach-advice', {
      question: 'كيف أصحح وضعية الظهر؟',
    });
    assert.equal(status, 402, JSON.stringify(body));
    assert.equal(body.code, 'subscription_required');
  });
});

describe('مسارات الاشتراك', () => {
  it('كتالوج الخطط يعرض الخطط الأربع بمعرّفات منتجاتها', async () => {
    const { status, body } = await api('GET', '/subscriptions/plans');
    assert.equal(status, 200);
    assert.equal(body.plans.length, 4);

    const paid = body.plans.filter((plan) => plan.productId);
    assert.deepEqual(
      paid.map((plan) => plan.id),
      ['single_monthly', 'trio_monthly', 'unlimited_yearly'],
    );
    assert.deepEqual(paid.map((plan) => plan.programSlots), [1, 3, -1]);
    assert.deepEqual(paid.map((plan) => plan.priceUsd), [10, 20, 100]);
  });

  it('التحقق بلا بيانات يُرفض', async () => {
    const { status, body } = await api('POST', '/subscriptions/apple/verify', {});
    assert.equal(status, 400);
    assert.equal(body.code, 'bad_request');
  });

  it('التحقق بعملية ملفّقة لا يمنح صلاحية', async () => {
    const { status } = await api('POST', '/subscriptions/apple/verify', {
      transactionId: '2000000999999999',
    });
    // الخادم غير مهيّأ لـApple هنا، فيرفض بدل أن يفترض حسن النية.
    assert.equal(status, 503);

    const me = await api('GET', '/subscriptions/me');
    assert.equal(me.body.entitlement.isSubscribed, false);
  });

  it('التشخيص يبلّغ عن الإعداد الناقص دون كشف الأسرار', async () => {
    const { status, body } = await api('GET', '/subscriptions/diagnostics');
    assert.equal(status, 200);
    assert.equal(body.ready, false);
    assert.equal(body.storeApi.keyId, false);
    assert.equal(typeof body.appleRootCertificate, 'boolean');
    assert.equal(JSON.stringify(body).includes('BEGIN'), false);
  });
});

describe('إشعارات App Store', () => {
  it('ترفض حمولة غير موقّعة من Apple', async () => {
    const forged = Buffer.from(JSON.stringify({ alg: 'none' })).toString('base64url');
    const payload = Buffer.from(
      JSON.stringify({ notificationType: 'DID_RENEW', notificationUUID: 'x' }),
    ).toString('base64url');

    const { status } = await api(
      'POST',
      '/subscriptions/apple/notifications',
      { signedPayload: `${forged}.${payload}.AAAA` },
      { auth: false },
    );

    // 401 = ليست من Apple. 503 = شهادة الجذر غير مثبّتة. كلاهما رفض.
    assert.ok([401, 503].includes(status), `رمز غير متوقع: ${status}`);
  });

  it('لا تقبل الحمولات المشوّهة', async () => {
    const { status } = await api(
      'POST',
      '/subscriptions/apple/notifications',
      { signedPayload: 'not-a-jws' },
      { auth: false },
    );
    assert.ok([400, 401, 503].includes(status), `رمز غير متوقع: ${status}`);
  });
});

describe('المكتبة بلا اشتراك', () => {
  const programId = 'prog_00000000-0000-4000-8000-000000000001';

  it('رفع برنامج مباشرةً يشغل حصة لكنه لا يفتح التوليد', async () => {
    const saved = await api('PUT', `/programs/${programId}`, {
      program: {
        id: programId,
        sport: 'كرة قدم',
        level: 'beginner',
        createdAt: new Date().toISOString(),
      },
      progress: {},
    });
    assert.equal(saved.status, 200);

    const list = await api('GET', '/programs');
    assert.equal(list.body.programs.length, 1);

    const { body } = await api('GET', '/subscriptions/me');
    assert.equal(body.entitlement.activePrograms, 1);
    // الحصة مشغولة، لكن سبب المنع يبقى غياب الاشتراك لا امتلاء الحصص.
    assert.equal(body.entitlement.canCreateProgram, false);
  });

  it('الحذف يحرّر الحصة ولا يفتح التوليد', async () => {
    const deleted = await api('DELETE', `/programs/${programId}`);
    assert.equal(deleted.status, 200);

    const { body } = await api('GET', '/subscriptions/me');
    assert.equal(body.entitlement.activePrograms, 0, 'الحصة تحرّرت');
    assert.equal(body.entitlement.canCreateProgram, false);

    const retry = await api('POST', '/ai/program', {
      sport: 'جري',
      level: 'beginner',
      goal: 'general',
    });
    assert.equal(retry.status, 402);
    assert.equal(retry.body.code, 'subscription_required');
  });
});
