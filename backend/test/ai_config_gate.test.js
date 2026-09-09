import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import net from 'node:net';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { after, before, describe, it } from 'node:test';

/**
 * حارس إعداد الذكاء الاصطناعي.
 *
 * الخادم يملك مولّد قوالب (`mock_program.js`) للتطوير بلا مفتاح مدفوع.
 * الخطر أن يعمل هذا المولّد في الإنتاج بالخطأ: المشترك يدفع مقابل
 * «برنامج يبنيه الذكاء الاصطناعي» فيستلم قالباً ثابتاً، وتُحرق حصة من
 * خطته، ولا يظهر أي خطأ في أي سجل. ومراجع App Store يسأل المدرّب الذكي
 * ثلاثة أسئلة مختلفة فيستلم الجواب نفسه حرفياً.
 *
 * فالقاعدة: القوالب تعمل بطلب صريح (`MOCK_AI=true`) وخارج الإنتاج فقط.
 * وأي نقص في المفتاح يظهر كعطل صريح 503، لا كخدمة مزيّفة.
 */

const HERE = path.dirname(fileURLToPath(import.meta.url));
const SERVER = path.join(HERE, '..', 'src', 'server.js');

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

/**
 * يقلع خادماً بمتغيّرات بيئة محدّدة، ويمنح حسابه صلاحية توليد.
 *
 * الصلاحية تُكتب في قاعدة البيانات مباشرة: بوابة الاشتراك تسبق بوابة
 * الذكاء الاصطناعي، ولو تركنا الحساب مجانياً لرجع 402 دائماً ولم نصل
 * أبداً إلى ما نريد اختباره.
 */
async function bootServer(env) {
  const dbDir = fs.mkdtempSync(path.join(os.tmpdir(), 'coachmint-aicfg-'));
  const dbFile = path.join(dbDir, 'api.db');
  const port = await freePort();
  const baseUrl = `http://127.0.0.1:${port}`;

  const child = spawn(process.execPath, [SERVER], {
    env: {
      ...process.env,
      PORT: String(port),
      DATABASE_FILE: dbFile,
      JWT_SECRET: 'test-secret-for-ai-config-gate',
      APPLE_KEY_ID: '',
      APPLE_ISSUER_ID: '',
      APPLE_PRIVATE_KEY: '',
      APPLE_PRIVATE_KEY_PATH: '',
      ...env,
    },
    stdio: ['ignore', 'pipe', 'pipe'],
  });

  const logs = [];
  child.stderr.on('data', (chunk) => logs.push(chunk.toString()));
  child.stdout.on('data', (chunk) => logs.push(chunk.toString()));

  await waitForHealth(baseUrl);

  const registered = await fetch(`${baseUrl}/auth/register`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      name: 'مستخدم اختبار',
      email: `cfg${Date.now()}${Math.random().toString(36).slice(2, 7)}@coachmint.app`,
      password: 'password123',
    }),
  }).then((r) => r.json());

  const token = registered.token;
  const userId = registered.user.id;

  // نمنح اشتراكاً بلا حدود بالكتابة في القاعدة، تماماً كما لو تحقّقنا من
  // Apple — فبوابة الاشتراك ليست موضوع هذا الاختبار.
  const { DatabaseSync } = await import('node:sqlite');
  const db = new DatabaseSync(dbFile);
  const now = new Date().toISOString();
  const inTwoMonths = new Date(Date.now() + 60 * 24 * 3600 * 1000).toISOString();
  const APPLE_STATUS_ACTIVE = 1;
  db.prepare(
    `INSERT INTO subscriptions (
       original_transaction_id, latest_transaction_id, user_id, app_account_token,
       product_id, plan_id, status, purchased_at, expires_at,
       auto_renew_status, is_trial, environment, created_at, updated_at
     ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
  ).run(
    `otx_${Date.now()}`,
    `tx_${Date.now()}`,
    userId,
    registered.user.appAccountToken,
    'com.coachmint.sub.unlimited.yearly',
    'unlimited_yearly',
    APPLE_STATUS_ACTIVE,
    now,
    inTwoMonths,
    1,
    0,
    'Sandbox',
    now,
    now,
  );
  db.close();

  async function api(method, endpoint, body) {
    const response = await fetch(baseUrl + endpoint, {
      method,
      headers: {
        'content-type': 'application/json',
        authorization: `Bearer ${token}`,
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

  return {
    api,
    logs,
    async stop() {
      child.kill();
      await new Promise((resolve) => setTimeout(resolve, 300));
      fs.rmSync(dbDir, { recursive: true, force: true });
    },
  };
}

const programRequest = {
  sport: 'كرة قدم',
  level: 'beginner',
  goal: 'general',
  weeks: 4,
  sessionsPerWeek: 3,
};

// ---------------------------------------------------------------------

describe('مفتاح ناقص بلا MOCK_AI — عطل صريح لا قالب صامت', () => {
  let server;

  before(async () => {
    server = await bootServer({ OPENAI_API_KEY: '', NODE_ENV: 'test' });
  });

  after(async () => server?.stop());

  it('التوليد يرجع 503 ai_unavailable لا برنامجاً', async () => {
    const { status, body } = await server.api('POST', '/ai/program', programRequest);
    assert.equal(status, 503, JSON.stringify(body));
    assert.equal(body.code, 'ai_unavailable');
    assert.equal(body.program, undefined, 'ما كان يجوز أن يصل قالب للمشترك');
  });

  it('لا يحرق حصة من خطة المشترك', async () => {
    const { body } = await server.api('GET', '/subscriptions/me');
    assert.equal(body.entitlement.activePrograms, 0);
  });

  it('استشارة المدرّب ترجع 503 لا جواباً معلّباً', async () => {
    const { status, body } = await server.api('POST', '/ai/coach-advice', {
      question: 'كيف أصحّح وضع الظهر في السكوات؟',
    });
    assert.equal(status, 503, JSON.stringify(body));
    assert.equal(body.code, 'ai_unavailable');
    assert.equal(body.advice, undefined);
  });

  it('مسار التشخيص يعلن عدم الجاهزية قبل الرفع', async () => {
    // هذا هو النداء الذي يُفترض أن يسبق كل رفع إلى App Store: لو قال
    // ready:false فالخادم ليس جاهزاً، ولا معنى لرفع نسخة تخاطبه.
    const { status, body } = await server.api('GET', '/subscriptions/diagnostics');
    assert.equal(status, 200);
    assert.equal(body.ai.configured, false);
    assert.equal(body.ai.mockMode, false);
    assert.equal(body.ready, false, 'مفتاح ناقص يعني خادماً غير جاهز');
  });
});

describe('مفتاح ناقص مع MOCK_AI=true في الإنتاج — الإنتاج يغلب', () => {
  let server;

  before(async () => {
    server = await bootServer({
      OPENAI_API_KEY: '',
      MOCK_AI: 'true',
      NODE_ENV: 'production',
    });
  });

  after(async () => server?.stop());

  it('لا يشتغل مولّد القوالب حتى لو طُلب صراحةً', async () => {
    const { status, body } = await server.api('POST', '/ai/program', programRequest);
    assert.equal(status, 503, JSON.stringify(body));
    assert.equal(body.code, 'ai_unavailable');
  });
});

describe('MOCK_AI=true خارج الإنتاج — يعمل كما هو مقصود', () => {
  let server;

  before(async () => {
    server = await bootServer({
      OPENAI_API_KEY: '',
      MOCK_AI: 'true',
      NODE_ENV: 'test',
    });
  });

  after(async () => server?.stop());

  it('يولّد برنامج قوالب للتطوير', async () => {
    const { status, body } = await server.api('POST', '/ai/program', programRequest);
    assert.equal(status, 200, JSON.stringify(body));
    assert.ok(body.program, 'وضع التطوير يجب أن يبقى صالحاً للعمل');
    assert.ok(body.program.weeks.length > 0);
    assert.match(body.meta.model, /mock/i, 'يجب أن يعلن عن نفسه كقالب');
  });
});
