import 'dotenv/config';

import cors from 'cors';
import express from 'express';
import rateLimit from 'express-rate-limit';
import helmet from 'helmet';

import { aiRouter } from './routes/ai.js';
import { authRouter } from './routes/auth.js';
import { programsRouter } from './routes/programs.js';

const app = express();
const PORT = Number(process.env.PORT || 8080);

app.set('trust proxy', 1);
app.use(helmet());
app.use(express.json({ limit: '2mb' }));

const origins = (process.env.CORS_ORIGINS || '')
  .split(',')
  .map((o) => o.trim())
  .filter(Boolean);

app.use(cors({ origin: origins.length > 0 ? origins : true }));

// حد عام لكل الطلبات لحماية الخدمة.
app.use(
  rateLimit({
    windowMs: 15 * 60 * 1000,
    limit: 300,
    standardHeaders: true,
    legacyHeaders: false,
  }),
);

app.get('/health', (_req, res) => {
  res.json({ ok: true, service: 'coachmint-api', time: new Date().toISOString() });
});

app.use('/auth', authRouter);
app.use('/programs', programsRouter);
app.use('/ai', aiRouter);

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

app.listen(PORT, () => {
  console.log(`coachmint-api listening on http://localhost:${PORT}`);
});
