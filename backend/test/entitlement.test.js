import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { after, before, beforeEach, describe, it } from 'node:test';

/**
 * اختبارات محرّك الصلاحيات.
 *
 * هذه هي القواعد التي تحمي الإيراد وتحمي المستخدم معاً: من يستحق ماذا،
 * ومتى تُفتح الحصة ومتى تُغلق. تُكتب هنا كسلوك لا كتفاصيل تنفيذ.
 */

let dbDir;
let db;
let subs;
let plans;

const FUTURE = () => Date.now() + 30 * 24 * 60 * 60 * 1000;
const PAST = () => Date.now() - 24 * 60 * 60 * 1000;

const USER = 'u_test_user';

before(async () => {
  dbDir = fs.mkdtempSync(path.join(os.tmpdir(), 'coachmint-db-'));
  process.env.DATABASE_FILE = path.join(dbDir, 'test.db');

  ({ db } = await import('../src/lib/db.js'));
  subs = await import('../src/lib/subscriptions.js');
  plans = await import('../src/lib/plans.js');
});

after(() => {
  try {
    db?.close?.();
  } catch {
    /* لا يهم عند التنظيف */
  }
  fs.rmSync(dbDir, { recursive: true, force: true });
});

beforeEach(() => {
  db.exec('DELETE FROM subscriptions');
  db.exec('DELETE FROM program_generations');
  db.exec('DELETE FROM programs');
  db.exec('DELETE FROM users');
  db.prepare(
    `INSERT INTO users (id, name, email, password_hash, created_at, app_account_token)
     VALUES (?, 'اختبار', 'test@coachmint.app', 'x', ?, ?)`,
  ).run(USER, new Date().toISOString(), '11111111-1111-1111-1111-111111111111');
});

/** يبني عنصر اشتراك بشكل ما ترجعه Apple. */
function appleItem({
  productId,
  status = 1,
  expiresDate = FUTURE(),
  originalTransactionId = '2000000000001',
  revocationDate = null,
  gracePeriodExpiresDate = null,
  autoRenewStatus = 1,
  appAccountToken = null,
}) {
  return {
    originalTransactionId,
    status,
    environment: 'Sandbox',
    transaction: {
      originalTransactionId,
      transactionId: originalTransactionId,
      productId,
      expiresDate,
      purchaseDate: Date.now(),
      originalPurchaseDate: Date.now(),
      environment: 'Sandbox',
      ...(revocationDate ? { revocationDate } : {}),
      ...(appAccountToken ? { appAccountToken } : {}),
    },
    renewal: {
      autoRenewStatus,
      autoRenewProductId: productId,
      ...(gracePeriodExpiresDate ? { gracePeriodExpiresDate } : {}),
    },
  };
}

function subscribe(planId, overrides = {}) {
  const plan = plans.planById(planId);
  return subs.upsertSubscription(
    appleItem({ productId: plan.productId, ...overrides }),
    { userId: USER },
  );
}

function generate(programId, { save = true } = {}) {
  subs.recordGeneration({ userId: USER, programId, sport: 'كرة قدم', planId: null });
  subs.consumeFreeGeneration(USER);
  if (save) {
    const now = new Date().toISOString();
    db.prepare(
      `INSERT INTO programs (id, user_id, sport, level, payload, created_at, updated_at)
       VALUES (?, ?, 'كرة قدم', 'beginner', '{}', ?, ?)`,
    ).run(programId, USER, now, now);
  }
}

// ---------------------------------------------------------------------

describe('بلا اشتراك — التطبيق مقفول بالكامل', () => {
  it('لا توليد إطلاقاً لحساب جديد', () => {
    const gate = subs.canCreateProgram(USER);
    assert.equal(gate.allowed, false, 'لا توجد تجربة مجانية');
    assert.equal(gate.code, 'subscription_required');
    assert.match(gate.message, /الاشتراك مطلوب/);
  });

  it('الرسالة تقود إلى الاشتراك لا إلى حذف برنامج', () => {
    const gate = subs.canCreateProgram(USER);
    assert.doesNotMatch(gate.message, /احذف/);
    assert.doesNotMatch(gate.message, /استهلكت/);
  });

  it('لا استشارة للمدرّب الذكي', () => {
    const gate = subs.canAskCoach(USER);
    assert.equal(gate.allowed, false);
    assert.equal(gate.code, 'subscription_required');
  });

  it('الصلاحية المعلنة للتطبيق تقول صراحةً: لا حصص ولا تجربة', async () => {
    const entitlement = await subs.entitlementFor(USER);
    assert.equal(entitlement.isSubscribed, false);
    assert.equal(entitlement.planId, 'free');
    assert.equal(entitlement.programSlots, 0);
    assert.equal(entitlement.freeGenerationsLimit, 0);
    assert.equal(entitlement.canCreateProgram, false);
    assert.equal(entitlement.coachAdvice, false);
  });
});

describe('اشتراك برنامج واحد — 10$ شهرياً', () => {
  beforeEach(() => subscribe('single_monthly'));

  it('يفتح التوليد فوراً بعد الشراء', () => {
    assert.equal(subs.canCreateProgram(USER).allowed, true);
  });

  it('يسمح ببرنامج نشط واحد فقط', () => {
    generate('prog_1');
    const gate = subs.canCreateProgram(USER);
    assert.equal(gate.allowed, false);
    assert.equal(gate.code, 'program_limit_reached');
  });

  it('حذف البرنامج يحرّر الحصة فوراً', () => {
    generate('prog_1');
    subs.releaseGeneration(USER, 'prog_1');
    assert.equal(subs.canCreateProgram(USER).allowed, true);
  });

  it('يفتح استشارة المدرّب الذكي', () => {
    assert.equal(subs.canAskCoach(USER).allowed, true);
  });
});

describe('اشتراك ثلاثة برامج — 20$ شهرياً', () => {
  it('يسمح بثلاثة برامج نشطة ثم يقفل عند الرابع', () => {
    subscribe('trio_monthly');

    generate('prog_1');
    generate('prog_2');
    assert.equal(subs.canCreateProgram(USER).allowed, true);

    generate('prog_3');
    assert.equal(subs.canCreateProgram(USER).allowed, false);
  });
});

describe('اشتراك مفتوح — 100$ سنوياً', () => {
  it('لا يقفل مهما بلغ عدد البرامج', () => {
    subscribe('unlimited_yearly');
    for (let i = 0; i < 25; i++) generate(`prog_${i}`);
    assert.equal(subs.canCreateProgram(USER).allowed, true);
  });
});

describe('دورة حياة الاشتراك', () => {
  it('الاشتراك المنتهي يعيد القفل الكامل', async () => {
    subscribe('trio_monthly', { status: 2, expiresDate: PAST() });
    const entitlement = await subs.entitlementFor(USER);
    assert.equal(entitlement.isSubscribed, false);
    assert.equal(entitlement.planId, 'free');
    assert.equal(entitlement.canCreateProgram, false);
    assert.equal(subs.canCreateProgram(USER).code, 'subscription_required');
  });

  it('حالة «نشط» بتاريخ انتهاء مضى تُرفض — لا نثق بصفّ قديم', async () => {
    subscribe('trio_monthly', { status: 1, expiresDate: PAST() });
    const entitlement = await subs.entitlementFor(USER);
    assert.equal(entitlement.isSubscribed, false);
  });

  it('مهلة السماح تبقي الصلاحية مفتوحة', async () => {
    subscribe('single_monthly', {
      status: 4,
      expiresDate: PAST(),
      gracePeriodExpiresDate: FUTURE(),
    });
    const entitlement = await subs.entitlementFor(USER);
    assert.equal(entitlement.isSubscribed, true);
    assert.equal(entitlement.inGracePeriod, true);
  });

  it('الاسترداد يلغي الصلاحية فوراً حتى لو بقي تاريخ الانتهاء', async () => {
    subscribe('unlimited_yearly', {
      status: 1,
      expiresDate: FUTURE(),
      revocationDate: Date.now(),
    });
    const entitlement = await subs.entitlementFor(USER);
    assert.equal(entitlement.isSubscribed, false);
  });

  it('فشل الدفع يغلق الصلاحية ويرفع علم مشكلة الفوترة', async () => {
    subscribe('trio_monthly', { status: 3, expiresDate: PAST() });
    const entitlement = await subs.entitlementFor(USER);
    assert.equal(entitlement.isSubscribed, false);
    assert.equal(entitlement.billingIssue, true);
  });

  it('عند تداخل اشتراكين تُحتسب الخطة الأعلى', async () => {
    subscribe('single_monthly', { originalTransactionId: 'txn_low' });
    subscribe('unlimited_yearly', { originalTransactionId: 'txn_high' });

    const entitlement = await subs.entitlementFor(USER);
    assert.equal(entitlement.planId, 'unlimited_yearly');
    assert.equal(entitlement.unlimited, true);
  });

  it('منتج غير معروف لا يمنح شيئاً', async () => {
    subs.upsertSubscription(
      appleItem({ productId: 'com.someone.else.pro', originalTransactionId: 'txn_x' }),
      { userId: USER },
    );
    const entitlement = await subs.entitlementFor(USER);
    assert.equal(entitlement.isSubscribed, false);
  });
});

describe('ربط الاشتراك بالحساب', () => {
  const OTHER = 'u_other_user';

  beforeEach(() => {
    db.prepare(
      `INSERT INTO users (id, name, email, password_hash, created_at, app_account_token)
       VALUES (?, 'آخر', 'other@coachmint.app', 'x', ?, ?)`,
    ).run(OTHER, new Date().toISOString(), '22222222-2222-2222-2222-222222222222');
  });

  it('يمنع مشاركة اشتراك فعّال بين حسابين', () => {
    subscribe('trio_monthly', { originalTransactionId: 'txn_shared' });

    assert.throws(
      () => subs.bindSubscriptionToUser('txn_shared', OTHER),
      (error) => error.code === 'subscription_bound_to_other_account' && error.status === 409,
    );
  });

  it('يسمح بنقل اشتراك منتهٍ لحساب جديد', () => {
    subscribe('trio_monthly', {
      originalTransactionId: 'txn_old',
      status: 2,
      expiresDate: PAST(),
    });

    const moved = subs.bindSubscriptionToUser('txn_old', OTHER);
    assert.equal(moved.user_id, OTHER);
  });
});

describe('عدّ الحصص محصّن ضد التطبيق', () => {
  it('التوليد يحجز حصة حتى لو لم يرفع التطبيق البرنامج', () => {
    subscribe('single_monthly');

    // التطبيق يولّد ولا يزامن — لو كان العدّ من جدول البرامج لبقي صفراً.
    generate('prog_ghost', { save: false });

    assert.equal(subs.activeProgramCount(USER), 1);
    assert.equal(subs.canCreateProgram(USER).allowed, false);
  });

  it('المصالحة تفكّ الحصص المعلّقة بلا برنامج بعد المهلة', () => {
    subscribe('single_monthly');
    generate('prog_lost', { save: false });

    // نُقدّم عمر الصفّ إلى ما قبل المهلة.
    db.prepare('UPDATE program_generations SET created_at = ? WHERE id = ?').run(
      new Date(Date.now() - 3 * 60 * 60 * 1000).toISOString(),
      'prog_lost',
    );

    subs.reconcileGenerations(USER);
    assert.equal(subs.canCreateProgram(USER).allowed, true);
  });

  it('المصالحة لا تمسّ حصة لبرنامج موجود فعلاً', () => {
    subscribe('single_monthly');
    generate('prog_real');

    db.prepare('UPDATE program_generations SET created_at = ? WHERE id = ?').run(
      new Date(Date.now() - 3 * 60 * 60 * 1000).toISOString(),
      'prog_real',
    );

    subs.reconcileGenerations(USER);
    assert.equal(subs.canCreateProgram(USER).allowed, false);
  });
});
