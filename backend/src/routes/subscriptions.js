import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import { z } from 'zod';

import { requireAuth } from '../lib/auth.js';
import { AppleVerificationError, decodeJwsUnsafe, isAppleRootAvailable, verifyAppleJws }
  from '../lib/apple/jws.js';
import { handleAppleNotification } from '../lib/apple/notifications.js';
import { AppStoreApiError, isStoreApiConfigured, storeApiDiagnostics }
  from '../lib/apple/store_api.js';
import { allPlans } from '../lib/plans.js';
import { isAiConfigured, isMockAiEnabled } from './ai.js';
import { SubscriptionError, entitlementFor, syncFromApple } from '../lib/subscriptions.js';

export const subscriptionsRouter = Router();

const isProduction = process.env.NODE_ENV === 'production';

// ---------------------------------------------------------------------
// حدود الاستخدام
// ---------------------------------------------------------------------

// التحقق يفتح صلاحية مدفوعة، فحدّه ضيّق: يمنع تخمين معرّفات العمليات.
const verifyLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  limit: 30,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => req.user?.id || req.ip,
  message: {
    code: 'rate_limited',
    message: 'محاولات كثيرة للتحقق من الاشتراك. انتظر قليلاً ثم أعد المحاولة.',
  },
});

const statusLimiter = rateLimit({
  windowMs: 5 * 60 * 1000,
  limit: 60,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => req.user?.id || req.ip,
});

// ---------------------------------------------------------------------
// المخططات
// ---------------------------------------------------------------------

const verifySchema = z
  .object({
    signedTransaction: z.string().min(20).max(20000).optional(),
    transactionId: z.string().trim().min(1).max(64).optional(),
    environment: z.enum(['Sandbox', 'Production']).optional(),
  })
  .refine((value) => value.signedTransaction || value.transactionId, {
    message: 'مطلوب signedTransaction أو transactionId.',
  });

const notificationSchema = z.object({
  signedPayload: z.string().min(20).max(100000),
});

// ---------------------------------------------------------------------
// معالجة الأخطاء
// ---------------------------------------------------------------------

function sendError(res, error) {
  if (error instanceof SubscriptionError) {
    return res.status(error.status).json({ code: error.code, message: error.message });
  }

  if (error instanceof AppleVerificationError) {
    return res.status(400).json({
      code: error.code,
      message: 'تعذّر التحقق من عملية الشراء لدى Apple.',
    });
  }

  if (error instanceof AppStoreApiError) {
    console.error('[subscriptions] App Store API:', error.status, error.appleCode, error.message);
    const notFound = error.status === 404;
    return res.status(notFound ? 404 : 502).json({
      code: notFound ? 'subscription_not_found' : 'apple_api_failed',
      message: notFound
        ? 'ما لقينا هذا الاشتراك لدى Apple. تأكد أنك تستخدم نفس Apple ID الذي اشترى.'
        : 'خدمة Apple غير متاحة الآن. حاول بعد لحظات.',
    });
  }

  console.error('[subscriptions] خطأ غير متوقع:', error);
  return res.status(500).json({
    code: 'server_error',
    message: 'صار خطأ في الخدمة. حاول مرة ثانية.',
  });
}

/**
 * يستخرج معرّف العملية والبيئة من حمولة StoreKit الموقّعة.
 *
 * في الإنتاج نرفض أي حمولة لا تجتاز التحقق من التوقيع. أثناء الإعداد —
 * قبل تثبيت شهادة جذر Apple — نقبل القراءة بلا تحقق لأن القرار النهائي
 * يأتي من App Store Server API على أي حال، مع تحذير صريح في السجل.
 */
function readSignedTransaction(signed) {
  try {
    const payload = verifyAppleJws(signed);
    return {
      transactionId: String(payload.transactionId || payload.originalTransactionId || ''),
      environment: payload.environment || null,
      verified: true,
    };
  } catch (error) {
    if (!(error instanceof AppleVerificationError)) throw error;
    if (isProduction || error.code !== 'apple_root_missing') throw error;

    console.warn(
      '[subscriptions] شهادة جذر Apple غير مثبّتة — نقرأ العملية بلا تحقق محلي. ' +
        'شغّل: npm run fetch:apple-root',
    );
    const payload = decodeJwsUnsafe(signed);
    if (!payload) throw error;
    return {
      transactionId: String(payload.transactionId || payload.originalTransactionId || ''),
      environment: payload.environment || null,
      verified: false,
    };
  }
}

// ---------------------------------------------------------------------
// 1. كتالوج الخطط
// ---------------------------------------------------------------------

/// يتيح للتطبيق رسم صفحة الاشتراك حتى لو تأخّر رد StoreKit.
subscriptionsRouter.get('/plans', requireAuth, (_req, res) => {
  res.json({
    plans: allPlans().map((plan) => ({
      id: plan.id,
      productId: plan.productId,
      title: plan.title,
      subtitle: plan.subtitle,
      programSlots: plan.programSlots,
      coachAdvice: plan.coachAdvice,
      period: plan.period,
      priceUsd: plan.priceUsd,
      rank: plan.rank,
    })),
    configured: isStoreApiConfigured(),
  });
});

// ---------------------------------------------------------------------
// 2. حالة الاشتراك الحالية
// ---------------------------------------------------------------------

subscriptionsRouter.get('/me', requireAuth, statusLimiter, async (req, res) => {
  try {
    // `revalidate` يسأل Apple إن بدا الصفّ المحلي قديماً — شبكة أمان لأي
    // إشعار لم يصل.
    const entitlement = await entitlementFor(req.user.id, { revalidate: true });
    res.json({ entitlement });
  } catch (error) {
    // فشل السؤال لا يجوز أن يحجب حالة معروفة مسبقاً: نرجع للصورة المحلية.
    console.error('[subscriptions] تعذّرت إعادة التحقق:', error?.message || error);
    try {
      const entitlement = await entitlementFor(req.user.id);
      res.json({ entitlement });
    } catch (inner) {
      sendError(res, inner);
    }
  }
});

// ---------------------------------------------------------------------
// 3. تأكيد عملية شراء
// ---------------------------------------------------------------------

subscriptionsRouter.post('/apple/verify', requireAuth, verifyLimiter, async (req, res) => {
  const parsed = verifySchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({
      code: 'bad_request',
      message: 'بيانات التحقق من الشراء ناقصة.',
    });
  }

  const { signedTransaction, transactionId, environment } = parsed.data;

  try {
    let resolvedId = transactionId ? String(transactionId) : '';
    let resolvedEnv = environment || null;

    if (signedTransaction) {
      const read = readSignedTransaction(signedTransaction);
      resolvedId = read.transactionId || resolvedId;
      resolvedEnv = read.environment || resolvedEnv;
    }

    if (!resolvedId) {
      return res.status(400).json({
        code: 'bad_request',
        message: 'تعذّر قراءة معرّف عملية الشراء.',
      });
    }

    await syncFromApple(resolvedId, { userId: req.user.id, environment: resolvedEnv });
    const entitlement = await entitlementFor(req.user.id);

    res.json({ entitlement });
  } catch (error) {
    sendError(res, error);
  }
});

// ---------------------------------------------------------------------
// 4. إشعارات خادم App Store (Webhook)
// ---------------------------------------------------------------------

/**
 * مسار عام تناديه Apple مباشرة.
 *
 * لا مصادقة هنا سوى توقيع Apple نفسه — فالتحقق منه إلزامي ولا يُتجاوز
 * مهما كان إعداد الخادم. رمز 500 يجعل Apple تعيد المحاولة، ورمز 401
 * يعني «هذه ليست منك» ولا يستحق إعادة.
 */
subscriptionsRouter.post('/apple/notifications', (req, res) => {
  const parsed = notificationSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ code: 'bad_request' });
  }

  if (!isAppleRootAvailable()) {
    console.error(
      '[subscriptions] وصل إشعار من Apple وشهادة الجذر غير مثبّتة — رفضناه. ' +
        'شغّل: npm run fetch:apple-root',
    );
    // 503 يدفع Apple لإعادة الإرسال بعد إصلاح الإعداد بدل فقدان الإشعار.
    return res.status(503).json({ code: 'apple_root_missing' });
  }

  try {
    const result = handleAppleNotification(parsed.data.signedPayload);
    if (result.duplicate) {
      console.log(`[apple] إشعار مكرر تم تجاهله: ${result.type}`);
    } else {
      console.log(
        `[apple] إشعار ${result.type}${result.subtype ? '/' + result.subtype : ''} ` +
          `→ ${result.handled ? 'حُدّث' : 'سُجّل'}`,
      );
    }
    res.status(200).json({ ok: true });
  } catch (error) {
    if (error instanceof AppleVerificationError) {
      console.error('[apple] إشعار برفض توقيع:', error.message);
      return res.status(401).json({ code: 'invalid_signature' });
    }
    console.error('[apple] فشل معالجة الإشعار:', error);
    res.status(500).json({ code: 'server_error' });
  }
});

// ---------------------------------------------------------------------
// 5. تشخيص الإعداد
// ---------------------------------------------------------------------

/// يخبر المشغّل بما ينقص قبل النشر. لا يكشف أي قيمة سرّية.
///
/// يغطّي **كل** ما يلزم نسخةَ إنتاج تعمل، لا الاشتراكات وحدها: نداء واحد
/// قبل الرفع إلى App Store يجيب عن «هل هذا الخادم جاهز؟». وجاهزية الذكاء
/// الاصطناعي جزء من الجواب لأن غيابها يعطّل ما يدفع المستخدم مقابله
/// تحديداً، ولا يظهر في أي مسار آخر إلا بعد شراء فعلي.
subscriptionsRouter.get('/diagnostics', requireAuth, (_req, res) => {
  const appleReady = isStoreApiConfigured() && isAppleRootAvailable();
  const aiReady = isAiConfigured() || isMockAiEnabled();

  res.json({
    storeApi: storeApiDiagnostics(),
    appleRootCertificate: isAppleRootAvailable(),
    ai: {
      configured: isAiConfigured(),
      mockMode: isMockAiEnabled(),
      model: process.env.OPENAI_PROGRAM_MODEL || process.env.OPENAI_MODEL || null,
    },
    ready: appleReady && aiReady,
  });
});
