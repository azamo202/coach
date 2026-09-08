import { db } from './db.js';
import {
  AppStoreApiError,
  AppleStatus,
  getSubscriptionStatuses,
  isStoreApiConfigured,
} from './apple/store_api.js';
import { FREE_PLAN, UNLIMITED, higherPlan, planById, planByProductId } from './plans.js';

/**
 * محرّك الصلاحيات.
 *
 * قاعدة واحدة تحكم هذا الملف كله: **الصلاحية تُشتقّ من ردّ Apple، لا من
 * ادّعاء العميل.** التطبيق يرسل معرّف عملية فقط، والخادم يسأل Apple عن
 * الحالة الحالية ثم يحفظها ويبني القرار عليها.
 *
 * وقاعدة ثانية: كل شك يُحسم بالرفض. منتج غير معروف، توقيع لا يُتحقّق منه،
 * تاريخ انتهاء مضى — كلها تعني «لا صلاحية».
 */

/** فارق زمني مسموح لاختلاف ساعات الخوادم. */
const CLOCK_SKEW_MS = 60 * 1000;

/** لا نعيد سؤال Apple عن نفس الاشتراك أكثر من مرة كل خمس دقائق. */
const REVALIDATE_AFTER_MS = 5 * 60 * 1000;

/** أقصى مهلة سماح تمنحها Apple (16 يوماً) — سقف احتياطي حين ينقص التاريخ. */
const MAX_GRACE_MS = 16 * 24 * 60 * 60 * 1000;

export class SubscriptionError extends Error {
  constructor(message, { code = 'subscription_error', status = 400 } = {}) {
    super(message);
    this.name = 'SubscriptionError';
    this.code = code;
    this.status = status;
  }
}

// ---------------------------------------------------------------------
// أدوات صغيرة
// ---------------------------------------------------------------------

function msToIso(ms) {
  if (ms === null || ms === undefined) return null;
  const n = Number(ms);
  if (!Number.isFinite(n) || n <= 0) return null;
  return new Date(n).toISOString();
}

function isoToMs(iso) {
  if (!iso) return null;
  const t = Date.parse(iso);
  return Number.isFinite(t) ? t : null;
}

/** هل صفّ الاشتراك يمنح صلاحية فعلية الآن؟ */
export function isEntitled(row, now = Date.now()) {
  if (!row) return false;
  if (row.revoked_at) return false;

  const status = Number(row.status);
  const expires = isoToMs(row.expires_at);

  if (status === AppleStatus.ACTIVE) {
    // اشتراك نشط بلا تاريخ انتهاء لا يُفترض حدوثه؛ إن حدث نرفض بدل أن نمنح
    // صلاحية أبدية عن طريق الخطأ.
    return expires !== null && expires + CLOCK_SKEW_MS > now;
  }

  if (status === AppleStatus.GRACE_PERIOD) {
    const graceEnd =
      isoToMs(row.grace_expires_at) ??
      (isoToMs(row.updated_at) ?? now) + MAX_GRACE_MS;
    return graceEnd + CLOCK_SKEW_MS > now;
  }

  // EXPIRED / BILLING_RETRY / REVOKED — لا صلاحية.
  return false;
}

/** هل الاشتراك في فترة إعادة محاولة الدفع؟ نخبر المستخدم ليصلح بطاقته. */
export function isInBillingRetry(row) {
  return Boolean(row) && Number(row.status) === AppleStatus.BILLING_RETRY;
}

// ---------------------------------------------------------------------
// قراءة وكتابة الاشتراكات
// ---------------------------------------------------------------------

const SELECT_BY_USER = db.prepare(
  'SELECT * FROM subscriptions WHERE user_id = ? ORDER BY updated_at DESC',
);

const SELECT_BY_TXN = db.prepare(
  'SELECT * FROM subscriptions WHERE original_transaction_id = ?',
);

export function subscriptionsForUser(userId) {
  return SELECT_BY_USER.all(userId);
}

export function subscriptionByTransaction(originalTransactionId) {
  return SELECT_BY_TXN.get(String(originalTransactionId));
}

/**
 * يحفظ حالة اشتراك واحدة قادمة من Apple.
 *
 * `userId` اختياري: إشعارات الخادم قد تصل قبل أن يربط التطبيق العملية
 * بحساب. في تلك الحالة نحفظ الصف بلا مالك، ويُربط لاحقاً عند أول تحقق.
 */
export function upsertSubscription(item, { userId = null } = {}) {
  const txn = item.transaction || {};
  const renewal = item.renewal || {};

  const originalTransactionId = String(
    item.originalTransactionId || txn.originalTransactionId || '',
  );
  if (!originalTransactionId) {
    throw new SubscriptionError('عملية Apple بلا معرّف أصلي.', {
      code: 'apple_bad_transaction',
      status: 502,
    });
  }

  const productId = String(txn.productId || renewal.productId || '');
  const plan = planByProductId(productId);
  if (!plan) {
    // منتج لا نعرفه: نحفظه للتدقيق لكن لا نمنح عليه شيئاً.
    console.error(`[subscriptions] منتج غير معروف من Apple: ${productId}`);
  }

  const existing = subscriptionByTransaction(originalTransactionId);
  const now = new Date().toISOString();

  const revokedAt = msToIso(txn.revocationDate);
  const status = Number(item.status);

  const record = {
    originalTransactionId,
    // لا نمحو مالكاً معروفاً بقيمة فارغة قادمة من إشعار.
    userId: userId ?? existing?.user_id ?? null,
    productId,
    planId: plan?.id || 'unknown',
    status: Number.isFinite(status) ? status : AppleStatus.EXPIRED,
    environment: String(item.environment || txn.environment || 'Production'),
    latestTransactionId: txn.transactionId ? String(txn.transactionId) : null,
    purchasedAt: msToIso(txn.originalPurchaseDate) || msToIso(txn.purchaseDate),
    expiresAt: msToIso(txn.expiresDate),
    graceExpiresAt: msToIso(renewal.gracePeriodExpiresDate),
    autoRenewStatus: Number(renewal.autoRenewStatus) === 1 ? 1 : 0,
    autoRenewProductId: renewal.autoRenewProductId
      ? String(renewal.autoRenewProductId)
      : null,
    isTrial: txn.offerType === 1 ? 1 : 0,
    isUpgraded: txn.isUpgraded === true ? 1 : 0,
    revokedAt,
    revocationReason:
      txn.revocationReason === undefined || txn.revocationReason === null
        ? null
        : Number(txn.revocationReason),
    expirationIntent:
      renewal.expirationIntent === undefined || renewal.expirationIntent === null
        ? null
        : Number(renewal.expirationIntent),
    appAccountToken: txn.appAccountToken ? String(txn.appAccountToken) : null,
    lastPayload: JSON.stringify({ transaction: txn, renewal }),
    createdAt: existing?.created_at || now,
    updatedAt: now,
  };

  db.prepare(
    `INSERT INTO subscriptions (
       original_transaction_id, user_id, product_id, plan_id, status, environment,
       latest_transaction_id, purchased_at, expires_at, grace_expires_at,
       auto_renew_status, auto_renew_product_id, is_trial, is_upgraded,
       revoked_at, revocation_reason, expiration_intent, app_account_token,
       last_payload, created_at, updated_at
     ) VALUES (
       @originalTransactionId, @userId, @productId, @planId, @status, @environment,
       @latestTransactionId, @purchasedAt, @expiresAt, @graceExpiresAt,
       @autoRenewStatus, @autoRenewProductId, @isTrial, @isUpgraded,
       @revokedAt, @revocationReason, @expirationIntent, @appAccountToken,
       @lastPayload, @createdAt, @updatedAt
     )
     ON CONFLICT (original_transaction_id) DO UPDATE SET
       user_id               = COALESCE(excluded.user_id, subscriptions.user_id),
       product_id            = excluded.product_id,
       plan_id               = excluded.plan_id,
       status                = excluded.status,
       environment           = excluded.environment,
       latest_transaction_id = excluded.latest_transaction_id,
       purchased_at          = COALESCE(excluded.purchased_at, subscriptions.purchased_at),
       expires_at            = excluded.expires_at,
       grace_expires_at      = excluded.grace_expires_at,
       auto_renew_status     = excluded.auto_renew_status,
       auto_renew_product_id = excluded.auto_renew_product_id,
       is_trial              = excluded.is_trial,
       is_upgraded           = excluded.is_upgraded,
       revoked_at            = excluded.revoked_at,
       revocation_reason     = excluded.revocation_reason,
       expiration_intent     = excluded.expiration_intent,
       app_account_token     = COALESCE(excluded.app_account_token, subscriptions.app_account_token),
       last_payload          = excluded.last_payload,
       updated_at            = excluded.updated_at`,
  ).run(record);

  return subscriptionByTransaction(originalTransactionId);
}

/**
 * يربط اشتراكاً بحساب.
 *
 * الاشتراك الواحد يخصّ حساباً واحداً. إذا كان مربوطاً بحساب آخر **ولا يزال
 * فعّالاً**، نرفض — وإلا لأمكن لعدة حسابات أن تتقاسم اشتراكاً واحداً. أما
 * إن كان الربط القديم منتهياً فنسمح بالنقل، لأن الأرجح أن نفس الشخص أنشأ
 * حساباً جديداً على نفس Apple ID.
 */
export function bindSubscriptionToUser(originalTransactionId, userId) {
  const row = subscriptionByTransaction(originalTransactionId);
  if (!row) return null;

  if (row.user_id && row.user_id !== userId) {
    if (isEntitled(row)) {
      throw new SubscriptionError(
        'هذا الاشتراك مرتبط بحساب آخر. سجّل الدخول بالحساب الذي اشترى الاشتراك، '
          + 'أو راسل الدعم لنقله.',
        { code: 'subscription_bound_to_other_account', status: 409 },
      );
    }
    console.warn(
      `[subscriptions] نقل اشتراك منتهٍ ${originalTransactionId} ` +
        `من ${row.user_id} إلى ${userId}`,
    );
  }

  db.prepare(
    'UPDATE subscriptions SET user_id = ?, updated_at = ? WHERE original_transaction_id = ?',
  ).run(userId, new Date().toISOString(), originalTransactionId);

  return subscriptionByTransaction(originalTransactionId);
}

/**
 * يسأل Apple عن حالة سلسلة اشتراك، ويحفظ كل ما يرجع.
 *
 * @returns {Promise<object[]>} صفوف الاشتراكات بعد التحديث.
 */
export async function syncFromApple(transactionId, { userId = null, environment = null } = {}) {
  if (!isStoreApiConfigured()) {
    throw new SubscriptionError(
      'خدمة الاشتراكات غير مهيّأة على الخادم. راجع إعدادات App Store.',
      { code: 'subscriptions_not_configured', status: 503 },
    );
  }

  const { items } = await getSubscriptionStatuses(transactionId, environment);
  if (items.length === 0) {
    throw new SubscriptionError('لم نجد اشتراكاً مرتبطاً بهذه العملية لدى Apple.', {
      code: 'subscription_not_found',
      status: 404,
    });
  }

  const requested = String(transactionId);
  const rows = [];

  for (const item of items) {
    const saved = upsertSubscription(item);

    // مالك الاشتراك: رمز الحساب الذي أرسلناه وقت الشراء هو الدليل الأقوى،
    // لأنه صادر عنّا وعاد موقّعاً من Apple. وإلا فالمستخدم الطالب.
    const claimed = saved.app_account_token
      ? userIdByAppAccountToken(saved.app_account_token)
      : null;
    const owner = claimed || userId;

    if (!owner || saved.user_id === owner) {
      rows.push(saved);
      continue;
    }

    try {
      rows.push(bindSubscriptionToUser(saved.original_transaction_id, owner) || saved);
    } catch (error) {
      if (!(error instanceof SubscriptionError)) throw error;
      // تعارض في العملية التي سُئلنا عنها تحديداً يجب أن يصل للمستخدم.
      // تعارض في اشتراك آخر ظهر ضمن نفس الرد (مشاركة عائلية مثلاً) نتجاوزه.
      const involvesRequested =
        saved.original_transaction_id === requested ||
        saved.latest_transaction_id === requested;
      if (involvesRequested) throw error;
      console.warn(
        `[subscriptions] تخطّينا ربط ${saved.original_transaction_id}: ${error.message}`,
      );
      rows.push(saved);
    }
  }

  return rows;
}

/// يجد صاحب رمز الحساب الذي أرسلناه إلى StoreKit وقت الشراء.
export function userIdByAppAccountToken(token) {
  if (!token) return null;
  const row = db
    .prepare('SELECT id FROM users WHERE lower(app_account_token) = lower(?)')
    .get(String(token));
  return row?.id || null;
}

// ---------------------------------------------------------------------
// حساب الصلاحية
// ---------------------------------------------------------------------

/**
 * عدد الحصص المشغولة الآن.
 *
 * يُقرأ من سجل التوليد لا من جدول البرامج: جدول البرامج يعكس ما اختار
 * التطبيق أن يرفعه، والسجل يعكس ما ولّده الخادم فعلاً.
 */
export function activeProgramCount(userId) {
  const row = db
    .prepare(
      'SELECT COUNT(*) AS n FROM program_generations WHERE user_id = ? AND released_at IS NULL',
    )
    .get(userId);
  return Number(row?.n || 0);
}

/** يحجز حصة باسم برنامج مولَّد. يُستدعى فور نجاح التوليد. */
export function recordGeneration({ userId, programId, sport, planId }) {
  db.prepare(
    `INSERT INTO program_generations (id, user_id, sport, plan_id, created_at, released_at)
     VALUES (?, ?, ?, ?, ?, NULL)
     ON CONFLICT (id, user_id) DO UPDATE SET released_at = NULL`,
  ).run(
    String(programId),
    userId,
    sport ? String(sport) : null,
    planId ? String(planId) : null,
    new Date().toISOString(),
  );
}

/** يحرّر حصة عند حذف البرنامج. */
export function releaseGeneration(userId, programId) {
  db.prepare(
    `UPDATE program_generations SET released_at = ?
     WHERE user_id = ? AND id = ? AND released_at IS NULL`,
  ).run(new Date().toISOString(), userId, String(programId));
}

/** يحرّر كل ما ليس ضمن القائمة الممرَّرة — يرافق مزامنة المكتبة كاملة. */
export function releaseGenerationsNotIn(userId, keepIds) {
  const now = new Date().toISOString();
  if (keepIds.length === 0) {
    db.prepare(
      'UPDATE program_generations SET released_at = ? WHERE user_id = ? AND released_at IS NULL',
    ).run(now, userId);
    return;
  }
  const placeholders = keepIds.map(() => '?').join(',');
  db.prepare(
    `UPDATE program_generations SET released_at = ?
     WHERE user_id = ? AND released_at IS NULL AND id NOT IN (${placeholders})`,
  ).run(now, userId, ...keepIds.map(String));
}

/** مهلة قبل اعتبار توليدة لم تصل قط إلى المكتبة توليدةً ضائعة. */
const ORPHAN_GRACE_MS = 60 * 60 * 1000;

/**
 * يحرّر الحصص المعلّقة بلا برنامج مقابل.
 *
 * التوليد ينجح ثم يسقط التطبيق أو ينقطع الاتصال قبل الرفع: تبقى الحصة
 * محجوزة إلى الأبد ويعلق المستخدم. هذه المصالحة تفكّها بعد ساعة — وهي
 * مدة أطول بكثير من رحلة التوليد، وأقصر من أن تُستغل لتجاوز الحصص
 * (الحد الساعي للتوليد يسدّ ذلك الباب أصلاً).
 */
export function reconcileGenerations(userId) {
  const cutoff = new Date(Date.now() - ORPHAN_GRACE_MS).toISOString();
  db.prepare(
    `UPDATE program_generations SET released_at = @now
     WHERE user_id = @userId AND released_at IS NULL AND created_at < @cutoff
       AND id NOT IN (SELECT id FROM programs WHERE user_id = @userId)`,
  ).run({ now: new Date().toISOString(), userId, cutoff });
}

function freeGenerationsUsed(userId) {
  const row = db
    .prepare('SELECT free_generations_used FROM users WHERE id = ?')
    .get(userId);
  return Number(row?.free_generations_used || 0);
}

/**
 * يعيد التحقق من Apple إن كان الصفّ قديماً بما يكفي ليكون مضلِّلاً.
 *
 * إشعارات Apple قد تُفقد (انقطاع شبكة، نشر، خطأ 500 عابر). هذه المزامنة
 * الكسولة هي شبكة الأمان: لا نعتمد على وصول الإشعار وحده.
 */
async function revalidateIfStale(rows) {
  if (!isStoreApiConfigured()) return rows;

  const now = Date.now();
  const stale = rows.filter((row) => {
    const updated = isoToMs(row.updated_at) ?? 0;
    if (now - updated < REVALIDATE_AFTER_MS) return false;
    const expires = isoToMs(row.expires_at);
    // يستحق السؤال: انتهى ظاهرياً، أو على وشك، أو في إعادة محاولة الدفع.
    if (expires !== null && expires - now < REVALIDATE_AFTER_MS) return true;
    return Number(row.status) === AppleStatus.BILLING_RETRY;
  });

  if (stale.length === 0) return rows;

  const refreshed = new Map();
  for (const row of stale) {
    try {
      const updated = await syncFromApple(row.original_transaction_id, {
        userId: row.user_id,
        environment: row.environment,
      });
      for (const item of updated) refreshed.set(item.original_transaction_id, item);
    } catch (error) {
      if (error instanceof AppStoreApiError || error instanceof SubscriptionError) {
        console.error(
          `[subscriptions] تعذّرت إعادة التحقق من ${row.original_transaction_id}:`,
          error.message,
        );
        continue;
      }
      throw error;
    }
  }

  return rows.map((row) => refreshed.get(row.original_transaction_id) || row);
}

/**
 * يبني صورة الصلاحية الكاملة لمستخدم — وهي الشكل الذي يستهلكه التطبيق.
 */
export async function entitlementFor(userId, { revalidate = false } = {}) {
  let rows = subscriptionsForUser(userId);
  if (revalidate && rows.length > 0) {
    rows = await revalidateIfStale(rows);
  }

  const now = Date.now();
  let activeRow = null;
  let plan = null;

  for (const row of rows) {
    if (!isEntitled(row, now)) continue;
    const rowPlan = planById(row.plan_id);
    if (!rowPlan || rowPlan.id === 'free') continue;
    if (plan === null || rowPlan.rank > plan.rank) {
      plan = rowPlan;
      activeRow = row;
    }
  }

  const effectivePlan = plan || FREE_PLAN;
  const usedFree = freeGenerationsUsed(userId);
  const activePrograms = activeProgramCount(userId);

  const billingIssue = rows.find(isInBillingRetry) || null;

  const slots = effectivePlan.programSlots;
  const hasSlot = slots === UNLIMITED || activePrograms < slots;
  const hasGenerations =
    effectivePlan.lifetimeGenerations === UNLIMITED ||
    usedFree < effectivePlan.lifetimeGenerations;

  return {
    planId: effectivePlan.id,
    productId: effectivePlan.productId,
    title: effectivePlan.title,
    isSubscribed: Boolean(plan),
    programSlots: slots,
    unlimited: slots === UNLIMITED,
    activePrograms,
    remainingSlots: slots === UNLIMITED ? null : Math.max(0, slots - activePrograms),
    coachAdvice: effectivePlan.coachAdvice,
    freeGenerationsUsed: usedFree,
    freeGenerationsLimit:
      effectivePlan.lifetimeGenerations === UNLIMITED
        ? null
        : effectivePlan.lifetimeGenerations,
    canCreateProgram: hasSlot && hasGenerations,
    status: activeRow ? Number(activeRow.status) : null,
    expiresAt: activeRow?.expires_at || null,
    autoRenew: activeRow ? activeRow.auto_renew_status === 1 : false,
    inGracePeriod: activeRow ? Number(activeRow.status) === AppleStatus.GRACE_PERIOD : false,
    isTrial: activeRow ? activeRow.is_trial === 1 : false,
    environment: activeRow?.environment || null,
    originalTransactionId: activeRow?.original_transaction_id || null,
    billingIssue: Boolean(billingIssue),
  };
}

/** نسخة متزامنة تكفي لبوابات الطلبات — لا تنادي Apple. */
export function entitlementSync(userId) {
  const rows = subscriptionsForUser(userId);
  const now = Date.now();

  let plan = null;
  for (const row of rows) {
    if (!isEntitled(row, now)) continue;
    const rowPlan = planById(row.plan_id);
    if (!rowPlan || rowPlan.id === 'free') continue;
    plan = higherPlan(plan, rowPlan);
  }

  const effectivePlan = plan || FREE_PLAN;
  return {
    plan: effectivePlan,
    isSubscribed: Boolean(plan),
    activePrograms: activeProgramCount(userId),
    freeGenerationsUsed: freeGenerationsUsed(userId),
    billingIssue: rows.some(isInBillingRetry),
  };
}

// ---------------------------------------------------------------------
// البوابات
// ---------------------------------------------------------------------

/**
 * هل يستطيع المستخدم توليد برنامج جديد الآن؟
 *
 * @returns {{allowed: boolean, code?: string, message?: string, entitlement: object}}
 */
export function canCreateProgram(userId) {
  const state = entitlementSync(userId);
  const { plan, activePrograms, freeGenerationsUsed: used } = state;

  const slotsFull =
    plan.programSlots !== UNLIMITED && activePrograms >= plan.programSlots;
  const generationsDone =
    plan.lifetimeGenerations !== UNLIMITED && used >= plan.lifetimeGenerations;

  if (!slotsFull && !generationsDone) {
    return { allowed: true, entitlement: state };
  }

  // غير مشترك: السبب ليس «امتلأت حصصك» بل «لا حصص لك أصلاً». التمييز مهم،
  // لأن الرسالتين تقودان المستخدم إلى إجراءين مختلفين تماماً.
  if (!state.isSubscribed) {
    const hadFreeTier = plan.lifetimeGenerations > 0 || plan.programSlots > 0;
    return {
      allowed: false,
      code: 'subscription_required',
      message: hadFreeTier
        ? 'استهلكت برنامجك المجاني. اشترك لتولّد برامج جديدة.'
        : 'الاشتراك مطلوب لبناء برنامجك التدريبي. اختر باقتك لتبدأ.',
      entitlement: state,
    };
  }

  return {
    allowed: false,
    code: 'program_limit_reached',
    message: `خطتك الحالية تسمح بـ${plan.programSlots} ${
      plan.programSlots === 1 ? 'برنامج نشط' : 'برامج نشطة'
    }. احذف برنامجاً أو رقّي اشتراكك.`,
    entitlement: state,
  };
}

/** هل يستطيع المستخدم سؤال المدرّب الذكي؟ */
export function canAskCoach(userId) {
  const state = entitlementSync(userId);
  if (state.plan.coachAdvice) return { allowed: true, entitlement: state };
  return {
    allowed: false,
    code: 'subscription_required',
    message: 'استشارة المدرّب الذكي متاحة للمشتركين. اشترك لتفتحها.',
    entitlement: state,
  };
}

/**
 * يسجّل استهلاك توليدة مجانية.
 *
 * يُستدعى **بعد** نجاح التوليد فقط: فشل الطلب لا يجوز أن يحرق تجربة
 * المستخدم الوحيدة.
 */
export function consumeFreeGeneration(userId) {
  const state = entitlementSync(userId);
  if (state.isSubscribed) return;
  db.prepare(
    'UPDATE users SET free_generations_used = free_generations_used + 1 WHERE id = ?',
  ).run(userId);
}

export { UNLIMITED, AppleStatus };
