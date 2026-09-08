import 'dotenv/config';

import path from 'node:path';
import { fileURLToPath } from 'node:url';

import cors from 'cors';
import express from 'express';
import rateLimit from 'express-rate-limit';
import helmet from 'helmet';

import { isAppleRootAvailable } from './lib/apple/jws.js';
import { isStoreApiConfigured, storeApiDiagnostics } from './lib/apple/store_api.js';
import { aiRouter } from './routes/ai.js';
import { authRouter } from './routes/auth.js';
import { programsRouter } from './routes/programs.js';
import { subscriptionsRouter } from './routes/subscriptions.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const publicDir = path.join(__dirname, '..', 'public');

const app = express();
const PORT = Number(process.env.PORT || 8080);

app.set('trust proxy', 1);
app.use(
  helmet({
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        styleSrc: ["'self'", "'unsafe-inline'", 'https://fonts.googleapis.com'],
        fontSrc: ["'self'", 'https://fonts.gstatic.com'],
        scriptSrc: ["'self'", "'unsafe-inline'"],
        imgSrc: ["'self'", 'data:', 'https:'],
      },
    },
  }),
);
app.use(express.json({ limit: '2mb' }));
app.use(express.static(publicDir));

const origins = (process.env.CORS_ORIGINS || '')
  .split(',')
  .map((o) => o.trim())
  .filter(Boolean);

app.use(cors({ origin: origins.length > 0 ? origins : true }));

// حد عام لكل الطلبات لحماية الخدمة.
//
// إشعارات App Store مستثناة: Apple ترسلها من نطاق عناوينها الخاص وقد
// تنفجر دفعة واحدة عند التجديد الجماعي، فخنقها يعني فقدان تحديثات دفع.
app.use(
  rateLimit({
    windowMs: 15 * 60 * 1000,
    limit: 300,
    standardHeaders: true,
    legacyHeaders: false,
    skip: (req) => req.originalUrl.split('?')[0] === '/subscriptions/apple/notifications',
  }),
);

app.get('/health', (_req, res) => {
  res.json({ ok: true, service: 'coachmint-api', time: new Date().toISOString() });
});

app.get('/', (_req, res) => {
  res.sendFile(path.join(publicDir, 'index.html'));
});

app.get('/privacy', (_req, res) => {
  res.sendFile(path.join(publicDir, 'privacy.html'));
});

app.get('/terms', (_req, res) => {
  res.sendFile(path.join(publicDir, 'terms.html'));
});

app.use('/auth', authRouter);
app.use('/programs', programsRouter);
app.use('/ai', aiRouter);
app.use('/subscriptions', subscriptionsRouter);

app.use((_req, res) => {
  res.status(404).json({ code: 'not_found', message: 'المسار غير موجود.' });
});

// معالج الأخطاء الأخير — لا نكشف تفاصيل داخلية للعميل.
app.use((error, _req, res, _next) => {
  console.error('Unhandled error:', error);
  res.status(500).json({
    code: 'server_error',
    message: 'صار خطأ في الخدمة. حاول مرة ثانية.',
  });
});

/// يطبع ما ينقص إعداد الاشتراكات عند الإقلاع بدل اكتشافه من شكوى مستخدم.
function reportSubscriptionReadiness() {
  const diagnostics = storeApiDiagnostics();
  const missing = Object.entries(diagnostics)
    .filter(([, present]) => !present)
    .map(([key]) => key);

  if (!isStoreApiConfigured()) {
    console.warn(
      `[startup] الاشتراكات معطّلة — ينقص إعداد App Store: ${missing.join(', ')}`,
    );
  }
  if (!isAppleRootAvailable()) {
    console.warn(
      '[startup] شهادة Apple Root CA - G3 غير مثبّتة. إشعارات App Store سترفض. ' +
        'شغّل: npm run fetch:apple-root',
    );
  }
  if (isStoreApiConfigured() && isAppleRootAvailable()) {
    console.log('[startup] الاشتراكات جاهزة ✓');
  }
}

app.listen(PORT, () => {
  console.log(`coachmint-api listening on http://localhost:${PORT}`);
  reportSubscriptionReadiness();
});
