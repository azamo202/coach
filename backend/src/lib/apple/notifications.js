import { db } from '../db.js';
import { bindSubscriptionToUser, upsertSubscription, userIdByAppAccountToken }
  from '../subscriptions.js';
import { AppleStatus } from './store_api.js';
import { AppleVerificationError, verifyAppleJws } from './jws.js';

/**
 * معالج App Store Server Notifications V2.
 *
 * هذا المسار هو ما يجعل الاشتراكات صحيحة **بين** فتحات التطبيق: التجديد،
 * الإلغاء، فشل الدفع، الاسترداد، والترقية كلها تصل هنا فور حدوثها بدل أن
 * ننتظر المستخدم ليفتح التطبيق.
 *
 * المسار عام بلا مصادقة، فالتحقق من التوقيع ليس اختيارياً: أي حمولة لا
 * تجتاز سلسلة شهادات Apple تُرفض قبل أن تلمس قاعدة البيانات.
 */

/** أنواع لا تخصّ الاشتراكات — نسجّلها ونمضي. */
const IGNORED_TYPES = new Set(['CONSUMPTION_REQUEST', 'TEST']);

/**
 * يستنتج حالة الاشتراك حين لا ترسلها Apple صراحةً.
 *
 * الحقل `data.status` موجود في إشعارات الاشتراكات المتجددة، لكنه يغيب في
 * بعض الأنواع. الاستنتاج هنا محافظ: ما لا نفهمه يُعامل كمنتهٍ.
 */
function deriveStatus(notificationType, subtype, transaction) {
  switch (notificationType) {
    case 'SUBSCRIBED':
    case 'DID_RENEW':
    case 'OFFER_REDEEMED':
    case 'RENEWAL_EXTENDED':
    case 'DID_CHANGE_RENEWAL_PREF':
    case 'DID_CHANGE_RENEWAL_STATUS':
    case 'PRICE_INCREASE':
      return AppleStatus.ACTIVE;

    case 'DID_FAIL_TO_RENEW':
      return subtype === 'GRACE_PERIOD'
        ? AppleStatus.GRACE_PERIOD
        : AppleStatus.BILLING_RETRY;

    case 'GRACE_PERIOD_EXPIRED':
      return AppleStatus.BILLING_RETRY;

    case 'EXPIRED':
      return AppleStatus.EXPIRED;

    case 'REFUND':
    case 'REVOKE':
      return AppleStatus.REVOKED;

    default: {
      // نوع لا نعرفه: نحكم بتاريخ الانتهاء نفسه بدل التخمين.
      const expires = Number(transaction?.expiresDate || 0);
      return expires > Date.now() ? AppleStatus.ACTIVE : AppleStatus.EXPIRED;
    }
  }
}

function alreadyProcessed(uuid) {
  if (!uuid) return false;
  const row = db
    .prepare('SELECT notification_uuid FROM apple_notifications WHERE notification_uuid = ?')
    .get(uuid);
  return Boolean(row);
}

function recordNotification({ uuid, type, subtype, originalTransactionId, environment, payload }) {
  db.prepare(
    `INSERT INTO apple_notifications (
       notification_uuid, notification_type, subtype,
       original_transaction_id, environment, payload, received_at
     ) VALUES (?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT (notification_uuid) DO NOTHING`,
  ).run(
    uuid,
    type || null,
    subtype || null,
    originalTransactionId || null,
    environment || null,
    JSON.stringify(payload).slice(0, 20000),
    new Date().toISOString(),
  );
}

/**
 * يعالج إشعاراً واحداً من Apple.
 *
 * @param {string} signedPayload حمولة الإشعار الموقّعة.
 * @returns {{handled: boolean, duplicate?: boolean, type: string, subtype: string|null}}
 * @throws {AppleVerificationError} إذا فشل التحقق من التوقيع.
 */
export function handleAppleNotification(signedPayload) {
  const payload = verifyAppleJws(signedPayload);

  const type = String(payload.notificationType || '');
  const subtype = payload.subtype ? String(payload.subtype) : null;
  const uuid = String(payload.notificationUUID || '');
  const data = payload.data || {};

  if (uuid && alreadyProcessed(uuid)) {
    return { handled: false, duplicate: true, type, subtype };
  }

  let transaction = null;
  let renewal = null;

  if (data.signedTransactionInfo) {
    transaction = verifyAppleJws(data.signedTransactionInfo);
  }
  if (data.signedRenewalInfo) {
    try {
      renewal = verifyAppleJws(data.signedRenewalInfo);
    } catch (error) {
      if (!(error instanceof AppleVerificationError)) throw error;
      // بيانات التجديد إضافية — غيابها لا يمنع تسجيل حالة العملية نفسها.
      console.error('[apple] فشل التحقق من بيانات التجديد:', error.message);
    }
  }

  const originalTransactionId = transaction?.originalTransactionId
    ? String(transaction.originalTransactionId)
    : null;

  recordNotification({
    uuid,
    type,
    subtype,
    originalTransactionId,
    environment: data.environment || null,
    payload: { notificationType: type, subtype, data: { ...data, signedTransactionInfo: undefined, signedRenewalInfo: undefined }, transaction, renewal },
  });

  if (IGNORED_TYPES.has(type) || !transaction) {
    return { handled: false, type, subtype };
  }

  const status = Number.isFinite(Number(data.status))
    ? Number(data.status)
    : deriveStatus(type, subtype, transaction);

  const saved = upsertSubscription({
    originalTransactionId,
    status,
    environment: data.environment || transaction.environment,
    transaction,
    renewal,
  });

  // إشعار قد يصل قبل أن يؤكّد التطبيق الشراء (أو بعد استعادة نسخة احتياطية)،
  // فيبقى الاشتراك بلا مالك ولا ينتفع به أحد. رمز الحساب الذي أرسلناه وقت
  // الشراء يعود هنا موقّعاً من Apple، فنربط به مباشرة.
  if (!saved.user_id && saved.app_account_token) {
    const owner = userIdByAppAccountToken(saved.app_account_token);
    if (owner) {
      try {
        bindSubscriptionToUser(originalTransactionId, owner);
      } catch (error) {
        console.warn(`[apple] تعذّر ربط ${originalTransactionId}: ${error.message}`);
      }
    }
  }

  return { handled: true, type, subtype, originalTransactionId, status };
}
