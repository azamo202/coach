import fs from 'node:fs';
import path from 'node:path';

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
