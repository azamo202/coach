import crypto from 'node:crypto';

import bcrypt from 'bcryptjs';
import { Router } from 'express';
import { z } from 'zod';

import { requireAuth, signToken } from '../lib/auth.js';
import { db, toPublicUser } from '../lib/db.js';

export const authRouter = Router();

const registerSchema = z.object({
  name: z.string().trim().min(2).max(40),
  email: z.string().trim().toLowerCase().email(),
  password: z.string().min(8).max(128),
});

const loginSchema = z.object({
  email: z.string().trim().toLowerCase().email(),
  password: z.string().min(1),
});

const profileSchema = z.object({
  name: z.string().trim().min(2).max(40).optional(),
  level: z.enum(['beginner', 'intermediate', 'advanced']).optional(),
  goal: z
    .enum(['general', 'strength', 'endurance', 'weightLoss', 'muscle', 'skill', 'speed'])
    .optional(),
  age: z.number().int().min(10).max(90).nullable().optional(),
  weightKg: z.number().min(30).max(250).nullable().optional(),
  heightCm: z.number().min(100).max(230).nullable().optional(),
  gender: z.string().trim().max(20).nullable().optional(),
  hasCompletedOnboarding: z.boolean().optional(),
  healthSyncEnabled: z.boolean().optional(),
});

function badRequest(res, message) {
  return res.status(400).json({ code: 'bad_request', message });
}

authRouter.post('/register', (req, res) => {
  const parsed = registerSchema.safeParse(req.body);
  if (!parsed.success) {
    return badRequest(res, 'تأكد من صحة الاسم والبريد وكلمة المرور (8 أحرف على الأقل).');
  }
  const { name, email, password } = parsed.data;

  const existing = db.prepare('SELECT id FROM users WHERE email = ?').get(email);
  if (existing) {
    return res.status(409).json({
      code: 'email_taken',
      message: 'هذا البريد مسجّل من قبل. سجّل دخولك بدل إنشاء حساب جديد.',
    });
  }

  const id = `u_${crypto.randomUUID()}`;
  const createdAt = new Date().toISOString();

  // رمز الحساب يُولَّد مع الحساب: StoreKit يحتاجه عند أول شراء، ولا يجوز
  // أن يكون توليده مشروطاً بمرور المستخدم على شاشة الاشتراك.
  db.prepare(
    `INSERT INTO users (id, name, email, password_hash, created_at, app_account_token)
     VALUES (?, ?, ?, ?, ?, ?)`,
  ).run(id, name, email, bcrypt.hashSync(password, 12), createdAt, crypto.randomUUID());

  const row = db.prepare('SELECT * FROM users WHERE id = ?').get(id);
  res.status(201).json({ token: signToken(id), user: toPublicUser(row) });
});

authRouter.post('/login', (req, res) => {
  const parsed = loginSchema.safeParse(req.body);
  if (!parsed.success) return badRequest(res, 'تأكد من صحة البيانات المدخلة.');

  const { email, password } = parsed.data;
  const row = db.prepare('SELECT * FROM users WHERE email = ?').get(email);

  if (!row || !bcrypt.compareSync(password, row.password_hash)) {
    return res.status(401).json({
      code: 'invalid_credentials',
      message: 'البريد الإلكتروني أو كلمة المرور غير صحيحة.',
    });
  }

  res.json({ token: signToken(row.id), user: toPublicUser(row) });
});

authRouter.get('/me', requireAuth, (req, res) => {
  res.json({ user: req.user });
});

authRouter.put('/me', requireAuth, (req, res) => {
  const parsed = profileSchema.safeParse(req.body);
  if (!parsed.success) return badRequest(res, 'بيانات غير صالحة.');

  const current = req.userRow;
  const next = parsed.data;

  db.prepare(
    `UPDATE users SET
       name = ?, level = ?, goal = ?, age = ?, weight_kg = ?, height_cm = ?,
       gender = ?, has_completed_onboarding = ?, health_sync_enabled = ?
     WHERE id = ?`,
  ).run(
    next.name ?? current.name,
    next.level ?? current.level,
    next.goal ?? current.goal,
    next.age === undefined ? current.age : next.age,
    next.weightKg === undefined ? current.weight_kg : next.weightKg,
    next.heightCm === undefined ? current.height_cm : next.heightCm,
    next.gender === undefined ? current.gender : next.gender,
    next.hasCompletedOnboarding === undefined
      ? current.has_completed_onboarding
      : Number(next.hasCompletedOnboarding),
    next.healthSyncEnabled === undefined
      ? current.health_sync_enabled
      : Number(next.healthSyncEnabled),
    current.id,
  );

  const row = db.prepare('SELECT * FROM users WHERE id = ?').get(current.id);
  res.json({ user: toPublicUser(row) });
});

authRouter.delete('/me', requireAuth, (req, res) => {
  db.prepare('DELETE FROM users WHERE id = ?').run(req.user.id);
  res.json({ ok: true });
});

authRouter.post('/forgot-password', (req, res) => {
  const email = String(req.body?.email || '').trim().toLowerCase();
  const row = db.prepare('SELECT id FROM users WHERE email = ?').get(email);

  // نرد بنجاح دائماً حتى لا نكشف البُرد المسجّلة.
  if (row) {
    const token = crypto.randomBytes(32).toString('hex');
    const expiresAt = new Date(Date.now() + 60 * 60 * 1000).toISOString();
    db.prepare(
      'INSERT INTO password_resets (token, user_id, expires_at) VALUES (?, ?, ?)',
    ).run(token, row.id, expiresAt);

    // TODO: أرسل الرابط بالبريد عبر مزوّد مثل Resend أو SES.
    // رابط الإعادة: https://tatawwar.app/reset?token=<token>
    console.log(`[password-reset] ${email} -> token ${token}`);
  }

  res.json({ ok: true });
});

authRouter.post('/reset-password', (req, res) => {
  const token = String(req.body?.token || '').trim();
  const password = String(req.body?.password || '');

  if (password.length < 8) {
    return badRequest(res, 'كلمة المرور 8 أحرف على الأقل.');
  }

  const row = db
    .prepare('SELECT * FROM password_resets WHERE token = ? AND used = 0')
    .get(token);

  if (!row || new Date(row.expires_at) < new Date()) {
    return res.status(400).json({
      code: 'invalid_token',
      message: 'رابط إعادة التعيين منتهي أو غير صالح.',
    });
  }

  db.prepare('UPDATE users SET password_hash = ? WHERE id = ?').run(
    bcrypt.hashSync(password, 12),
    row.user_id,
  );
  db.prepare('UPDATE password_resets SET used = 1 WHERE token = ?').run(token);

  res.json({ ok: true });
});
