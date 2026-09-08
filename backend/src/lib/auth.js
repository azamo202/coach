import { randomUUID } from 'node:crypto';

import jwt from 'jsonwebtoken';

import { db, toPublicUser } from './db.js';

const SECRET = process.env.JWT_SECRET || 'dev-secret-change-me';
const EXPIRES_IN = process.env.JWT_EXPIRES_IN || '30d';

export function signToken(userId) {
  return jwt.sign({ sub: userId }, SECRET, { expiresIn: EXPIRES_IN });
}

/// وسيط يتحقق من التوكن ويحمّل المستخدم في req.user.
export function requireAuth(req, res, next) {
  const header = req.get('authorization') || '';
  const token = header.startsWith('Bearer ') ? header.slice(7).trim() : '';

  if (!token) {
    return res.status(401).json({ code: 'unauthorized', message: 'مطلوب تسجيل الدخول.' });
  }

  let payload;
  try {
    payload = jwt.verify(token, SECRET);
  } catch {
    return res.status(401).json({ code: 'unauthorized', message: 'انتهت جلستك. سجّل دخولك من جديد.' });
  }

  const row = db.prepare('SELECT * FROM users WHERE id = ?').get(payload.sub);
  if (!row) {
    return res.status(401).json({ code: 'unauthorized', message: 'الحساب غير موجود.' });
  }

  // شبكة أمان: أي حساب أُنشئ قبل وجود رمز الحساب يحصل عليه هنا، فلا
  // تصل شاشة الاشتراك أبداً إلى مستخدم بلا رمز.
  if (!row.app_account_token) {
    const token = randomUUID();
    db.prepare('UPDATE users SET app_account_token = ? WHERE id = ?').run(token, row.id);
    row.app_account_token = token;
  }

  req.userRow = row;
  req.user = toPublicUser(row);
  next();
}
