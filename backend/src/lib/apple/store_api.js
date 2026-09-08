import fs from 'node:fs';
import path from 'node:path';

import jwt from 'jsonwebtoken';

import { AppleVerificationError, verifyAppleJws } from './jws.js';

/**
 * عميل App Store Server API.
 *
 * هذه هي **الجهة الوحيدة الموثوقة** لتحديد حالة الاشتراك. لا نمنح صلاحية
 * بناءً على ما يقوله التطبيق: نأخذ منه معرّف العملية فقط، ثم نسأل Apple
 * مباشرة عن الحالة الحالية ونبني القرار على ردّها.
 *
 * مرجع الحقول: Get All Subscription Statuses / Get Transaction Info.
 */

const PRODUCTION_BASE = 'https://api.storekit.itunes.apple.com';
const SANDBOX_BASE = 'https://api.storekit-sandbox.itunes.apple.com';

/** رمز خطأ Apple حين لا تُعرف العملية في هذه البيئة. */
const TRANSACTION_NOT_FOUND = 4040010;

/** حالات الاشتراك كما تُرجعها Apple. */
export const AppleStatus = {
  ACTIVE: 1,
  EXPIRED: 2,
  BILLING_RETRY: 3,
  GRACE_PERIOD: 4,
  REVOKED: 5,
};

export class AppStoreApiError extends Error {
  constructor(message, { status = 0, appleCode = null, code = 'apple_api_failed' } = {}) {
    super(message);
    this.name = 'AppStoreApiError';
    this.status = status;
    this.appleCode = appleCode;
    this.code = code;
  }
}

// ---------------------------------------------------------------------
// الإعدادات والمفتاح الخاص
// ---------------------------------------------------------------------

function config() {
  return {
    keyId: process.env.APPLE_KEY_ID || '',
    issuerId: process.env.APPLE_ISSUER_ID || '',
    bundleId: process.env.APPLE_BUNDLE_ID || '',
    privateKeyPath: process.env.APPLE_PRIVATE_KEY_PATH || '',
    privateKeyInline: process.env.APPLE_PRIVATE_KEY || '',
    defaultEnvironment: (process.env.APPLE_ENVIRONMENT || 'auto').toLowerCase(),
  };
}

let _privateKeyCache;

function privateKey() {
  if (_privateKeyCache !== undefined) return _privateKeyCache;
  const { privateKeyPath, privateKeyInline } = config();

  if (privateKeyInline.trim()) {
    // متغيّرات البيئة لا تحمل أسطراً جديدة — نقبل \n المهروبة.
    _privateKeyCache = privateKeyInline.replace(/\\n/g, '\n').trim();
    return _privateKeyCache;
  }

  if (privateKeyPath.trim()) {
    try {
      _privateKeyCache = fs.readFileSync(path.resolve(privateKeyPath), 'utf8');
      return _privateKeyCache;
    } catch (error) {
      console.error('[apple] تعذّر قراءة مفتاح App Store الخاص:', error?.message || error);
    }
  }

  _privateKeyCache = null;
  return _privateKeyCache;
}

/** هل الخادم مهيّأ للتحدّث مع Apple؟ */
export function isStoreApiConfigured() {
  const { keyId, issuerId, bundleId } = config();
  return Boolean(keyId && issuerId && bundleId && privateKey());
}

/** تشخيص الإعداد الناقص — يظهر في سجل الإقلاع وفي مسار الفحص. */
export function storeApiDiagnostics() {
  const { keyId, issuerId, bundleId } = config();
  return {
    keyId: Boolean(keyId),
    issuerId: Boolean(issuerId),
    bundleId: Boolean(bundleId),
    privateKey: Boolean(privateKey()),
  };
}

// ---------------------------------------------------------------------
// توقيع رمز الوصول
// ---------------------------------------------------------------------

let _tokenCache = { value: null, expiresAt: 0 };

function bearerToken() {
  const now = Date.now();
  if (_tokenCache.value && now < _tokenCache.expiresAt) return _tokenCache.value;

  const { keyId, issuerId, bundleId } = config();
  const key = privateKey();
  if (!key) {
    throw new AppStoreApiError('مفتاح App Store Server API غير مهيّأ.', {
      code: 'apple_not_configured',
    });
  }

  // Apple تسمح بحد أقصى 60 دقيقة. نستخدم 50 ونجدّد قبل الانتهاء بدقيقتين.
  const issuedAt = Math.floor(now / 1000);
  const expiresAt = issuedAt + 50 * 60;

  const token = jwt.sign(
    { iss: issuerId, iat: issuedAt, exp: expiresAt, aud: 'appstoreconnect-v1', bid: bundleId },
    key,
    { algorithm: 'ES256', header: { alg: 'ES256', kid: keyId, typ: 'JWT' } },
  );

  _tokenCache = { value: token, expiresAt: (expiresAt - 120) * 1000 };
  return token;
}

/** يُبطل رمز الوصول المخزَّن — يُستدعى عند تغيّر الإعدادات أو رفض Apple. */
export function resetStoreApiCaches() {
  _tokenCache = { value: null, expiresAt: 0 };
  _privateKeyCache = undefined;
}

// ---------------------------------------------------------------------
// النداء الشبكي
// ---------------------------------------------------------------------

const RETRYABLE = new Set([429, 500, 502, 503, 504]);

async function callOnce(base, endpoint) {
  const response = await fetch(base + endpoint, {
    method: 'GET',
    headers: {
      authorization: 'Bearer ' + bearerToken(),
      accept: 'application/json',
    },
    signal: AbortSignal.timeout(15000),
  });

  const text = await response.text();
  let body = {};
  if (text) {
    try {
      body = JSON.parse(text);
    } catch {
      body = {};
    }
  }

  if (!response.ok) {
    throw new AppStoreApiError(
      body?.errorMessage || 'App Store API ' + response.status,
      { status: response.status, appleCode: body?.errorCode ?? null },
    );
  }

  return body;
}

async function callWithRetry(base, endpoint, maxRetries = 2) {
  let attempt = 0;
  for (;;) {
    try {
      return await callOnce(base, endpoint);
    } catch (error) {
      const retryable =
        error instanceof AppStoreApiError
          ? RETRYABLE.has(error.status)
          : error?.name === 'TimeoutError' || error?.name === 'AbortError';

      if (!retryable || attempt >= maxRetries) throw error;
      attempt++;
      await new Promise((resolve) => setTimeout(resolve, attempt * 800));
    }
  }
}

/**
 * ينادي Apple في البيئة الصحيحة.
 *
 * البيئة قد تكون معروفة من حمولة موقّعة سابقاً. إن لم تكن، نجرّب الإنتاج
 * أولاً ثم الاختبار — وهو التسلسل الذي توصي به Apple، لأن عملية إنتاجية
 * لا توجد أبداً في بيئة الرمل والعكس صحيح.
 */
async function call(endpoint, environment) {
  const configured = config().defaultEnvironment;
  const hint = (environment || '').toLowerCase();

  let order;
  if (hint === 'sandbox') order = [SANDBOX_BASE];
  else if (hint === 'production') order = [PRODUCTION_BASE];
  else if (configured === 'sandbox') order = [SANDBOX_BASE, PRODUCTION_BASE];
  else order = [PRODUCTION_BASE, SANDBOX_BASE];

  let lastError;
  for (const base of order) {
    try {
      const body = await callWithRetry(base, endpoint);
      return { body, environment: base === SANDBOX_BASE ? 'Sandbox' : 'Production' };
    } catch (error) {
      lastError = error;
      const notFoundHere =
        error instanceof AppStoreApiError &&
        error.status === 404 &&
        error.appleCode === TRANSACTION_NOT_FOUND;
      if (!notFoundHere) throw error;
    }
  }
  throw lastError;
}

// ---------------------------------------------------------------------
// العمليات
// ---------------------------------------------------------------------

/**
 * يقرأ حالة كل اشتراكات المستخدم المرتبطة بمعرّف العملية.
 *
 * يُرجع قائمة مسطّحة بعد فك وتحقّق كل الحمولات الموقّعة.
 */
export async function getSubscriptionStatuses(transactionId, environment) {
  const { body, environment: resolvedEnv } = await call(
    '/inApps/v1/subscriptions/' + encodeURIComponent(transactionId),
    environment,
  );

  const items = [];
  for (const group of body?.data ?? []) {
    for (const entry of group?.lastTransactions ?? []) {
      let transaction = null;
      let renewal = null;
      try {
        transaction = entry.signedTransactionInfo
          ? verifyAppleJws(entry.signedTransactionInfo)
          : null;
        renewal = entry.signedRenewalInfo ? verifyAppleJws(entry.signedRenewalInfo) : null;
      } catch (error) {
        if (error instanceof AppleVerificationError) {
          // حمولة موقّعة لا تجتاز التحقق: نتجاهلها ولا نبني عليها صلاحية.
          console.error('[apple] حمولة اشتراك فشل التحقق منها:', error.message);
          continue;
        }
        throw error;
      }

      items.push({
        originalTransactionId: String(
          entry.originalTransactionId || transaction?.originalTransactionId || '',
        ),
        status: Number(entry.status),
        subscriptionGroupIdentifier: group?.subscriptionGroupIdentifier ?? null,
        transaction,
        renewal,
        environment: body?.environment || resolvedEnv,
      });
    }
  }

  return { environment: body?.environment || resolvedEnv, items };
}

/** يقرأ عملية واحدة موقّعة ومتحقّقاً منها. */
export async function getTransactionInfo(transactionId, environment) {
  const { body, environment: resolvedEnv } = await call(
    '/inApps/v1/transactions/' + encodeURIComponent(transactionId),
    environment,
  );
  const signed = body?.signedTransactionInfo;
  if (!signed) {
    throw new AppStoreApiError('رد Apple لا يحتوي على بيانات العملية.', {
      code: 'apple_bad_response',
    });
  }
  return { transaction: verifyAppleJws(signed), environment: resolvedEnv };
}

export { TRANSACTION_NOT_FOUND };
