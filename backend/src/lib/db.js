import fs from 'node:fs';
import path from 'node:path';

import { randomUUID } from 'node:crypto';
import { DatabaseSync } from 'node:sqlite';

const file = process.env.DATABASE_FILE || './data/tatawwar.db';
fs.mkdirSync(path.dirname(file), { recursive: true });

export const db = new DatabaseSync(file);

db.pragma = (str) => db.exec('PRAGMA ' + str);
db.transaction = (fn) => {
  return (...args) => {
    db.exec('BEGIN');
    try {
      const res = fn(...args);
      db.exec('COMMIT');
      return res;
    } catch (err) {
      db.exec('ROLLBACK');
      throw err;
    }
  };
};

db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');

db.exec(`
  CREATE TABLE IF NOT EXISTS users (
    id                      TEXT PRIMARY KEY,
    name                    TEXT NOT NULL,
    email                   TEXT NOT NULL UNIQUE,
    password_hash           TEXT NOT NULL,
    level                   TEXT NOT NULL DEFAULT 'beginner',
    goal                    TEXT NOT NULL DEFAULT 'general',
    age                     INTEGER,
    weight_kg               REAL,
    height_cm               REAL,
    gender                  TEXT,
    has_completed_onboarding INTEGER NOT NULL DEFAULT 0,
    health_sync_enabled     INTEGER NOT NULL DEFAULT 0,
    created_at              TEXT NOT NULL
  );

  CREATE TABLE IF NOT EXISTS programs (
    id          TEXT NOT NULL,
    user_id     TEXT NOT NULL,
    sport       TEXT NOT NULL,
    level       TEXT NOT NULL,
    payload     TEXT NOT NULL,
    created_at  TEXT NOT NULL,
    updated_at  TEXT NOT NULL,
    PRIMARY KEY (id, user_id),
    FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
  );

  CREATE INDEX IF NOT EXISTS idx_programs_user ON programs (user_id);

  CREATE TABLE IF NOT EXISTS password_resets (
    token      TEXT PRIMARY KEY,
    user_id    TEXT NOT NULL,
    expires_at TEXT NOT NULL,
    used       INTEGER NOT NULL DEFAULT 0,
    FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
  );

  CREATE TABLE IF NOT EXISTS ai_requests (
    id                TEXT PRIMARY KEY,
    user_id           TEXT NOT NULL,
    feature           TEXT NOT NULL,
    model             TEXT NOT NULL,
    prompt_tokens     INTEGER DEFAULT 0,
    completion_tokens INTEGER DEFAULT 0,
    total_tokens      INTEGER DEFAULT 0,
    status            TEXT NOT NULL,
    error_code        TEXT,
    created_at        TEXT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
  );

  CREATE INDEX IF NOT EXISTS idx_ai_requests_user ON ai_requests (user_id);

  -- ------------------------------------------------------------------
  -- الاشتراكات (Apple In-App Purchase)
  -- ------------------------------------------------------------------
  --
  -- المفتاح الأساسي هو original_transaction_id: هو المعرّف الثابت الذي
  -- تعطيه Apple لسلسلة الاشتراك كاملة عبر كل التجديدات والترقيات. ربطه
  -- بمستخدم واحد هو ما يمنع مشاركة اشتراك واحد بين عدة حسابات.

  CREATE TABLE IF NOT EXISTS subscriptions (
    original_transaction_id TEXT PRIMARY KEY,
    user_id                 TEXT,
    product_id              TEXT NOT NULL,
    plan_id                 TEXT NOT NULL,
    status                  INTEGER NOT NULL,
    environment             TEXT NOT NULL DEFAULT 'Production',
    latest_transaction_id   TEXT,
    purchased_at            TEXT,
    expires_at              TEXT,
    grace_expires_at        TEXT,
    auto_renew_status       INTEGER NOT NULL DEFAULT 0,
    auto_renew_product_id   TEXT,
    is_trial                INTEGER NOT NULL DEFAULT 0,
    is_upgraded             INTEGER NOT NULL DEFAULT 0,
    revoked_at              TEXT,
    revocation_reason       INTEGER,
    expiration_intent       INTEGER,
    app_account_token       TEXT,
    last_payload            TEXT,
    created_at              TEXT NOT NULL,
    updated_at              TEXT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE SET NULL
  );

  CREATE INDEX IF NOT EXISTS idx_subscriptions_user ON subscriptions (user_id);
  CREATE INDEX IF NOT EXISTS idx_subscriptions_status ON subscriptions (status);

  -- سجل إشعارات App Store — يضمن ألا تُعالَج الرسالة نفسها مرتين.
  CREATE TABLE IF NOT EXISTS apple_notifications (
    notification_uuid       TEXT PRIMARY KEY,
    notification_type       TEXT,
    subtype                 TEXT,
    original_transaction_id TEXT,
    environment             TEXT,
    payload                 TEXT,
    received_at             TEXT NOT NULL
  );

  CREATE INDEX IF NOT EXISTS idx_apple_notifications_txn
    ON apple_notifications (original_transaction_id);

  -- ------------------------------------------------------------------
  -- سجل التوليد — مصدر عدّ الحصص
  -- ------------------------------------------------------------------
  --
  -- لا يجوز أن نعدّ الحصص من جدول programs، لأن ما يصل إليه يقرّره
  -- التطبيق: مشترك بحصة واحدة يستطيع أن يولّد بلا حد ما دام لا يرفع
  -- ما ولّده. لذلك نكتب الصفّ هنا **لحظة التوليد** على الخادم، ولا
  -- يُحرَّر إلا بحذف صريح.

  CREATE TABLE IF NOT EXISTS program_generations (
    id          TEXT NOT NULL,
    user_id     TEXT NOT NULL,
    sport       TEXT,
    plan_id     TEXT,
    created_at  TEXT NOT NULL,
    released_at TEXT,
    PRIMARY KEY (id, user_id),
    FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
  );

  CREATE INDEX IF NOT EXISTS idx_program_generations_live
    ON program_generations (user_id, released_at);
`);

// ---------------------------------------------------------------------
// ترحيلات الأعمدة المضافة بعد الإصدار الأول
// ---------------------------------------------------------------------
//
// `CREATE TABLE IF NOT EXISTS` لا يضيف أعمدة لقاعدة بيانات موجودة، فأي
// عمود جديد يحتاج ترحيلاً صريحاً. الترحيل هنا آمن للتكرار.

function columnNames(table) {
  try {
    return db
      .prepare(`PRAGMA table_info(${table})`)
      .all()
      .map((row) => row.name);
  } catch {
    return [];
  }
}

function addColumnIfMissing(table, column, definition) {
  if (columnNames(table).includes(column)) return false;
  db.exec(`ALTER TABLE ${table} ADD COLUMN ${column} ${definition}`);
  return true;
}

addColumnIfMissing('users', 'free_generations_used', 'INTEGER NOT NULL DEFAULT 0');

// رمز يربط عملية الشراء في StoreKit بحساب المستخدم لدينا. Apple تشترط أن
// يكون UUID صالحاً، وتعيده لنا داخل العملية الموقّعة فنتحقق من الربط.
if (addColumnIfMissing('users', 'app_account_token', 'TEXT')) {
  const rows = db.prepare('SELECT id FROM users').all();
  const update = db.prepare('UPDATE users SET app_account_token = ? WHERE id = ?');
  for (const row of rows) {
    update.run(randomUUID(), row.id);
  }
}

db.exec(
  'CREATE UNIQUE INDEX IF NOT EXISTS idx_users_app_account_token ' +
    'ON users (app_account_token) WHERE app_account_token IS NOT NULL',
);

// البرامج التي أُنشئت قبل وجود سجل التوليد تُنقل إليه مرة واحدة، وإلا
// ظهر كل مستخدم قديم وكأنه لم يستهلك أي حصة.
db.exec(`
  INSERT OR IGNORE INTO program_generations (id, user_id, sport, plan_id, created_at, released_at)
  SELECT p.id, p.user_id, p.sport, 'legacy', p.created_at, NULL
  FROM programs p
`);

/// يحوّل صف قاعدة البيانات إلى الشكل الذي يتوقعه التطبيق.
export function toPublicUser(row) {
  if (!row) return null;
  return {
    id: row.id,
    name: row.name,
    email: row.email,
    level: row.level,
    goal: row.goal,
    age: row.age,
    weightKg: row.weight_kg,
    heightCm: row.height_cm,
    gender: row.gender,
    hasCompletedOnboarding: row.has_completed_onboarding === 1,
    healthSyncEnabled: row.health_sync_enabled === 1,
    appAccountToken: row.app_account_token || null,
    freeGenerationsUsed: row.free_generations_used ?? 0,
    createdAt: row.created_at,
  };
}

/// يسجّل استهلاك ونشاط الذكاء الاصطناعي بدقة للمتابعة وإحصاءات التكلفة.
export function logAiUsage({
  userId,
  feature,
  model,
  promptTokens = 0,
  completionTokens = 0,
  totalTokens = 0,
  status = 'success',
  errorCode = null,
}) {
  try {
    const id = `air_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
    db.prepare(`
      INSERT INTO ai_requests (
        id, user_id, feature, model,
        prompt_tokens, completion_tokens, total_tokens,
        status, error_code, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      id,
      userId,
      feature,
      model,
      promptTokens,
      completionTokens,
      totalTokens,
      status,
      errorCode,
      new Date().toISOString()
    );
  } catch (err) {
    console.error('Failed to log AI usage:', err?.message || err);
  }
}
