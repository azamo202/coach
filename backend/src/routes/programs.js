import { Router } from 'express';

import { requireAuth } from '../lib/auth.js';
import { db } from '../lib/db.js';
import {
  recordGeneration,
  reconcileGenerations,
  releaseGeneration,
  releaseGenerationsNotIn,
} from '../lib/subscriptions.js';

export const programsRouter = Router();

programsRouter.use(requireAuth);

function rowToEntry(row) {
  try {
    return JSON.parse(row.payload);
  } catch {
    return null;
  }
}

/// كل برامج المستخدم مع تقدّمه فيها.
programsRouter.get('/', (req, res) => {
  // فرصة طبيعية لفكّ أي حصة حُجزت لتوليدة لم تصل المكتبة أبداً.
  reconcileGenerations(req.user.id);

  const rows = db
    .prepare('SELECT * FROM programs WHERE user_id = ? ORDER BY created_at DESC')
    .all(req.user.id);

  const programs = rows.map(rowToEntry).filter(Boolean);
  res.json({ programs });
});

/// حفظ أو تحديث برنامج واحد (يشمل التقدّم).
programsRouter.put('/:id', (req, res) => {
  const entry = req.body;
  const program = entry?.program;

  if (!program || typeof program !== 'object') {
    return res
      .status(400)
      .json({ code: 'bad_request', message: 'صيغة البرنامج غير صحيحة.' });
  }

  const now = new Date().toISOString();
  db.prepare(
    `INSERT INTO programs (id, user_id, sport, level, payload, created_at, updated_at)
     VALUES (@id, @userId, @sport, @level, @payload, @createdAt, @updatedAt)
     ON CONFLICT (id, user_id) DO UPDATE SET
       sport = excluded.sport,
       level = excluded.level,
       payload = excluded.payload,
       updated_at = excluded.updated_at`,
  ).run({
    id: String(req.params.id),
    userId: req.user.id,
    sport: String(program.sport || ''),
    level: String(program.level || 'beginner'),
    payload: JSON.stringify(entry),
    createdAt: String(program.createdAt || now),
    updatedAt: now,
  });

  // أي برنامج موجود في المكتبة يشغل حصة، حتى لو رُفع مباشرة دون توليد.
  recordGeneration({
    userId: req.user.id,
    programId: String(req.params.id),
    sport: program.sport,
    planId: null,
  });

  res.json({ ok: true });
});

/// مزامنة المكتبة كاملة — تُستخدم عند تغيّر عدة برامج دفعة واحدة.
programsRouter.post('/sync', (req, res) => {
  const entries = Array.isArray(req.body?.programs) ? req.body.programs : [];
  const now = new Date().toISOString();

  const upsert = db.prepare(
    `INSERT INTO programs (id, user_id, sport, level, payload, created_at, updated_at)
     VALUES (@id, @userId, @sport, @level, @payload, @createdAt, @updatedAt)
     ON CONFLICT (id, user_id) DO UPDATE SET
       sport = excluded.sport,
       level = excluded.level,
       payload = excluded.payload,
       updated_at = excluded.updated_at`,
  );

  const keepIds = [];

  const run = db.transaction(() => {
    for (const entry of entries) {
      const program = entry?.program;
      if (!program?.id) continue;
      keepIds.push(String(program.id));
      upsert.run({
        id: String(program.id),
        userId: req.user.id,
        sport: String(program.sport || ''),
        level: String(program.level || 'beginner'),
        payload: JSON.stringify(entry),
        createdAt: String(program.createdAt || now),
        updatedAt: now,
      });
    }

    // نحذف ما لم يعد موجوداً على الجهاز.
    if (keepIds.length > 0) {
      const placeholders = keepIds.map(() => '?').join(',');
      db.prepare(
        `DELETE FROM programs WHERE user_id = ? AND id NOT IN (${placeholders})`,
      ).run(req.user.id, ...keepIds);
    } else {
      db.prepare('DELETE FROM programs WHERE user_id = ?').run(req.user.id);
    }
  });

  run();

  // المزامنة تعكس المكتبة كاملة، فالحصص تتبعها: ما بقي محجوز وما زال
  // يُحرَّر.
  for (const id of keepIds) {
    recordGeneration({ userId: req.user.id, programId: id, sport: null, planId: null });
  }
  releaseGenerationsNotIn(req.user.id, keepIds);

  res.json({ ok: true, count: keepIds.length });
});

programsRouter.delete('/:id', (req, res) => {
  db.prepare('DELETE FROM programs WHERE user_id = ? AND id = ?').run(
    req.user.id,
    String(req.params.id),
  );
  // حذف البرنامج يحرّر حصته فوراً — هذا هو الطريق الوحيد لتحريرها.
  releaseGeneration(req.user.id, String(req.params.id));
  res.json({ ok: true });
});
