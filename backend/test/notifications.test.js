import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { after, before, beforeEach, describe, it } from 'node:test';

import { createFakeAppleChain } from './helpers/fake_apple.mjs';

/**
 * اختبارات إشعارات خادم App Store.
 *
 * هذا هو المسار الذي يبقي الاشتراكات صحيحة بين فتحات التطبيق — التجديد
 * والإلغاء والاسترداد. وهو أيضاً المسار الوحيد المفتوح للعالم بلا مصادقة،
 * فالتحقق من التوقيع فيه ليس تحسيناً بل شرط سلامة.
 */

const USER = 'u_notify_user';
const ACCOUNT_TOKEN = '33333333-3333-4333-8333-333333333333';
const ORIGINAL_TXN = '2000000000777';

let chain;
let dbDir;
let db;
let subs;
let plans;
let notifications;

const FUTURE = () => Date.now() + 30 * 24 * 60 * 60 * 1000;
const PAST = () => Date.now() - 60 * 60 * 1000;

before(async () => {
  chain = createFakeAppleChain();
  process.env.APPLE_ROOT_CA_PATH = chain.rootPath;

  dbDir = fs.mkdtempSync(path.join(os.tmpdir(), 'coachmint-notify-'));
  process.env.DATABASE_FILE = path.join(dbDir, 'notify.db');

  ({ db } = await import('../src/lib/db.js'));
  subs = await import('../src/lib/subscriptions.js');
  plans = await import('../src/lib/plans.js');
  notifications = await import('../src/lib/apple/notifications.js');
});

after(() => {
  chain?.cleanup();
  try {
    db?.close?.();
  } catch {
    /* لا يهم عند التنظيف */
  }
  fs.rmSync(dbDir, { recursive: true, force: true });
});

beforeEach(() => {
  db.exec('DELETE FROM apple_notifications');
  db.exec('DELETE FROM subscriptions');
  db.exec('DELETE FROM program_generations');
  db.exec('DELETE FROM users');
  db.prepare(
    `INSERT INTO users (id, name, email, password_hash, created_at, app_account_token)
     VALUES (?, 'اختبار', 'notify@coachmint.app', 'x', ?, ?)`,
  ).run(USER, new Date().toISOString(), ACCOUNT_TOKEN);
});

let uuidCounter = 0;

/** يبني إشعاراً موقّعاً بنفس شكل ما ترسله Apple. */
function notification({
  notificationType,
  subtype = null,
  productId = plans.planById('trio_monthly').productId,
  status = 1,
  expiresDate = FUTURE(),
  revocationDate = null,
  autoRenewStatus = 1,
  appAccountToken = ACCOUNT_TOKEN,
  notificationUUID = `uuid-${++uuidCounter}`,
}) {
  const transaction = chain.sign({
    originalTransactionId: ORIGINAL_TXN,
    transactionId: `${ORIGINAL_TXN}-${uuidCounter}`,
    productId,
    expiresDate,
    purchaseDate: Date.now(),
    originalPurchaseDate: Date.now(),
    environment: 'Sandbox',
    ...(appAccountToken ? { appAccountToken } : {}),
    ...(revocationDate ? { revocationDate } : {}),
  });

  const renewal = chain.sign({
    originalTransactionId: ORIGINAL_TXN,
    autoRenewStatus,
    autoRenewProductId: productId,
  });

  return {
    notificationUUID,
    signedPayload: chain.sign({
      notificationType,
      subtype,
      notificationUUID,
      version: '2.0',
      signedDate: Date.now(),
      data: {
        bundleId: 'com.coachmint.coachmint',
        environment: 'Sandbox',
        status,
        signedTransactionInfo: transaction,
        signedRenewalInfo: renewal,
      },
    }),
  };
}

function send(options) {
  const built = notification(options);
  return {
    ...built,
    result: notifications.handleAppleNotification(built.signedPayload),
  };
}

// ---------------------------------------------------------------------

describe('التحقق من التوقيع', () => {
  it('يرفض إشعاراً موقّعاً بسلسلة غريبة', () => {
    const stranger = createFakeAppleChain();
    try {
      const forged = stranger.sign({
        notificationType: 'SUBSCRIBED',
        notificationUUID: 'forged',
        data: {},
      });
      assert.throws(
        () => notifications.handleAppleNotification(forged),
        /لا تنتهي إلى جذر Apple الموثوق/,
      );
      // ولم يُكتب شيء في قاعدة البيانات.
      assert.equal(db.prepare('SELECT COUNT(*) n FROM subscriptions').get().n, 0);
    } finally {
      stranger.cleanup();
    }
  });

  it('يرفض إشعاراً عُدّلت حمولته', () => {
    const { signedPayload } = notification({ notificationType: 'SUBSCRIBED' });
    const [head, , signature] = signedPayload.split('.');
    const swapped = Buffer.from(
      JSON.stringify({ notificationType: 'REFUND', data: {} }),
    ).toString('base64url');

    assert.throws(
      () => notifications.handleAppleNotification(`${head}.${swapped}.${signature}`),
      /لا يطابق الحمولة/,
    );
  });
});

describe('دورة حياة اشتراك عبر الإشعارات', () => {
  it('SUBSCRIBED ينشئ الاشتراك ويربطه بصاحب رمز الحساب', async () => {
    const { result } = send({ notificationType: 'SUBSCRIBED' });

    assert.equal(result.handled, true);
    assert.equal(result.originalTransactionId, ORIGINAL_TXN);

    const row = subs.subscriptionByTransaction(ORIGINAL_TXN);
    assert.equal(row.user_id, USER, 'رمز الحساب هو ما يربط الاشتراك بصاحبه');
    assert.equal(row.plan_id, 'trio_monthly');

    const entitlement = await subs.entitlementFor(USER);
    assert.equal(entitlement.isSubscribed, true);
    assert.equal(entitlement.planId, 'trio_monthly');
    assert.equal(entitlement.programSlots, 3);
  });

  it('DID_RENEW يمدّد تاريخ الانتهاء', async () => {
    send({ notificationType: 'SUBSCRIBED', expiresDate: Date.now() + 60_000 });

    const extended = Date.now() + 45 * 24 * 60 * 60 * 1000;
    send({ notificationType: 'DID_RENEW', expiresDate: extended });

    const entitlement = await subs.entitlementFor(USER);
    assert.equal(entitlement.isSubscribed, true);
    assert.equal(Date.parse(entitlement.expiresAt), extended);
  });

  it('DID_CHANGE_RENEWAL_PREF ينقل المستخدم إلى الباقة الجديدة', async () => {
    send({ notificationType: 'SUBSCRIBED' });
    send({
      notificationType: 'DID_CHANGE_RENEWAL_PREF',
      subtype: 'UPGRADE',
      productId: plans.planById('unlimited_yearly').productId,
    });

    const entitlement = await subs.entitlementFor(USER);
    assert.equal(entitlement.planId, 'unlimited_yearly');
    assert.equal(entitlement.unlimited, true);
  });

  it('EXPIRED يغلق الصلاحية', async () => {
    send({ notificationType: 'SUBSCRIBED' });
    send({ notificationType: 'EXPIRED', status: 2, expiresDate: PAST() });

    const entitlement = await subs.entitlementFor(USER);
    assert.equal(entitlement.isSubscribed, false);
    assert.equal(entitlement.planId, 'free');
  });

  it('DID_FAIL_TO_RENEW مع مهلة سماح يُبقي الصلاحية مفتوحة', async () => {
    send({ notificationType: 'SUBSCRIBED' });
    send({
      notificationType: 'DID_FAIL_TO_RENEW',
      subtype: 'GRACE_PERIOD',
      status: 4,
      expiresDate: Date.now() + 5 * 24 * 60 * 60 * 1000,
    });

    const entitlement = await subs.entitlementFor(USER);
    assert.equal(entitlement.isSubscribed, true);
    assert.equal(entitlement.inGracePeriod, true);
  });

  it('DID_FAIL_TO_RENEW بلا مهلة يغلق الصلاحية ويرفع علم الفوترة', async () => {
    send({ notificationType: 'SUBSCRIBED' });
    send({ notificationType: 'DID_FAIL_TO_RENEW', status: 3, expiresDate: PAST() });

    const entitlement = await subs.entitlementFor(USER);
    assert.equal(entitlement.isSubscribed, false);
    assert.equal(entitlement.billingIssue, true);
  });

  it('REFUND يلغي الصلاحية فوراً رغم بقاء تاريخ الانتهاء', async () => {
    send({ notificationType: 'SUBSCRIBED' });
    send({
      notificationType: 'REFUND',
      status: 1,
      expiresDate: FUTURE(),
      revocationDate: Date.now(),
    });

    const entitlement = await subs.entitlementFor(USER);
    assert.equal(entitlement.isSubscribed, false);
  });
});

describe('المتانة', () => {
  it('لا يُعالَج الإشعار نفسه مرتين', () => {
    const first = send({ notificationType: 'SUBSCRIBED' });
    assert.equal(first.result.handled, true);

    const again = notifications.handleAppleNotification(first.signedPayload);
    assert.equal(again.duplicate, true);
    assert.equal(again.handled, false);

    assert.equal(
      db.prepare('SELECT COUNT(*) n FROM apple_notifications').get().n,
      1,
    );
  });

  it('إشعار بلا رمز حساب معروف يُحفظ بلا مالك ولا يمنح أحداً شيئاً', async () => {
    send({ notificationType: 'SUBSCRIBED', appAccountToken: null });

    const row = subs.subscriptionByTransaction(ORIGINAL_TXN);
    assert.equal(row.user_id, null);

    const entitlement = await subs.entitlementFor(USER);
    assert.equal(entitlement.isSubscribed, false);
  });

  it('منتج غير معروف يُسجَّل ولا يمنح صلاحية', async () => {
    send({ notificationType: 'SUBSCRIBED', productId: 'com.other.app.pro' });

    const row = subs.subscriptionByTransaction(ORIGINAL_TXN);
    assert.equal(row.plan_id, 'unknown');

    const entitlement = await subs.entitlementFor(USER);
    assert.equal(entitlement.isSubscribed, false);
  });

  it('إشعار TEST يُسجَّل ولا يمسّ الاشتراكات', () => {
    send({ notificationType: 'TEST' });
    assert.equal(db.prepare('SELECT COUNT(*) n FROM subscriptions').get().n, 0);
    assert.equal(db.prepare('SELECT COUNT(*) n FROM apple_notifications').get().n, 1);
  });
});
