# الباك إند — الواجهات والنشر

Node.js 20 + Express + SQLite. مسؤول عن ثلاثة أشياء:

1. **الحسابات** — تسجيل، دخول، ملف شخصي، حذف (bcrypt + JWT)
2. **قاعدة البيانات** — حفظ البرامج والتقدّم ومزامنتها بين الأجهزة
3. **وسيط Anthropic** — يبقى مفتاح الـ API على السيرفر ولا يُشحن مع التطبيق

---

## لماذا لا يتصل التطبيق بـ Anthropic مباشرة

أي مفتاح تضعه داخل حزمة التطبيق **يمكن استخراجه** بفك الـ APK أو الـ IPA.
النتيجة: فاتورة مفتوحة على حسابك، واحتمال رفض من Apple. لذلك المسار الصحيح:

```
التطبيق → الباك إند (يحمل المفتاح) → Anthropic
```

الوضع المباشر موجود في الكود للتطوير المحلي فقط، ويُفعَّل حين لا يُمرَّر
`API_BASE_URL`.

---

## الواجهات (API)

القاعدة: `https://api.coachmint.app`
المصادقة: `Authorization: Bearer <token>`

### الحسابات

| الطريقة | المسار | المصادقة | الوصف |
|---|---|---|---|
| `POST` | `/auth/register` | — | إنشاء حساب |
| `POST` | `/auth/login` | — | تسجيل الدخول |
| `GET` | `/auth/me` | ✔ | بيانات المستخدم الحالي |
| `PUT` | `/auth/me` | ✔ | تحديث المستوى والهدف والقياسات |
| `DELETE` | `/auth/me` | ✔ | حذف الحساب وكل بياناته |
| `POST` | `/auth/forgot-password` | — | طلب رابط إعادة تعيين |
| `POST` | `/auth/reset-password` | — | تعيين كلمة مرور جديدة بالتوكن |

**مثال — إنشاء حساب:**

```bash
curl -X POST https://api.coachmint.app/auth/register \
  -H 'content-type: application/json' \
  -d '{"name":"أحمد","email":"a@example.com","password":"Passw0rd1"}'
```

```json
{
  "token": "eyJhbGciOi...",
  "user": {
    "id": "u_...",
    "name": "أحمد",
    "email": "a@example.com",
    "level": "beginner",
    "goal": "general",
    "hasCompletedOnboarding": false,
    "healthSyncEnabled": false,
    "createdAt": "2026-08-30T14:00:00.000Z"
  }
}
```

### البرامج

| الطريقة | المسار | الوصف |
|---|---|---|
| `GET` | `/programs` | كل برامج المستخدم مع تقدّمه |
| `PUT` | `/programs/:id` | حفظ أو تحديث برنامج واحد |
| `POST` | `/programs/sync` | مزامنة المكتبة كاملة (يحذف ما لم يعد على الجهاز) |
| `DELETE` | `/programs/:id` | حذف برنامج |

### توليد البرنامج

```
POST /ai/program        (يتطلب مصادقة · 20 طلباً/ساعة لكل مستخدم)
```

**الطلب:**

```json
{
  "sport": "كرة السلة",
  "level": "intermediate",
  "goal": "skill",
  "weeks": 6,
  "sessionsPerWeek": 4,
  "profileBrief": "العمر: 24 سنة. الوزن: 78 كجم.",
  "healthBrief": "متوسط الخطوات اليومية: 7400",
  "notes": "ألم خفيف في الكتف الأيسر",
  "equipmentAvailable": "دمبلز، حبل مقاومة"
}
```

`sport` و `level` مطلوبان، والباقي اختياري.

**الرد:** `{ "program": { ... }, "meta": { "model", "level", "weeks" } }`

### الصحة

```
GET /health   →  { "ok": true, "service": "coachmint-api", "time": "..." }
```

---

## شكل الأخطاء

كل الأخطاء ترجع نفس البنية، والرسالة عربية جاهزة للعرض مباشرة:

```json
{ "code": "email_taken", "message": "هذا البريد مسجّل من قبل..." }
```

| الرمز | الحالة | المعنى |
|---|---|---|
| `bad_request` | 400 | بيانات غير صالحة |
| `invalid_credentials` | 401 | بريد أو كلمة مرور خاطئة |
| `unauthorized` | 401 | توكن مفقود أو منتهٍ |
| `email_taken` | 409 | البريد مسجّل مسبقاً |
| `rate_limited` | 429 | تجاوز حد التوليد |
| `ai_bad_format` | 502 | رد غير صالح من النموذج |
| `ai_failed` | 502 | فشل الاتصال بـ Anthropic |

---

## قاعدة البيانات

ثلاثة جداول في SQLite:

- **`users`** — الحسابات والمستوى والهدف والقياسات
- **`programs`** — البرنامج كاملاً + التقدّم في حقل JSON، مفتاح مركّب `(id, user_id)`
- **`password_resets`** — توكنات إعادة التعيين مع صلاحية ساعة واحدة

`ON DELETE CASCADE` مفعّل: حذف الحساب يحذف كل برامجه — مطلوب لسياسات المتاجر.

**النسخ الاحتياطي:**

```bash
sqlite3 data/coachmint.db ".backup 'backup-$(date +%F).db'"
```

**الترقية إلى PostgreSQL** عند النمو: استبدل `src/lib/db.js` بـ `pg`. بقية
الكود لا يتغير لأن الاستعلامات معزولة في هذا الملف والمسارات.

---

## الأمان المطبَّق

- كلمات المرور بـ **bcrypt** (12 جولة) — لا تُخزَّن أبداً كنص
- **JWT** بصلاحية 30 يوماً، والتوكن يُحفظ في التطبيق داخل
  Keychain (iOS) / EncryptedSharedPreferences (Android)
- **helmet** لرؤوس الحماية
- **حد الطلبات**: 300 طلب/15 دقيقة عام، و20 توليداً/ساعة لكل مستخدم
- **zod** للتحقق من كل مدخل قبل لمس قاعدة البيانات
- رسالة موحّدة عند فشل الدخول حتى لا نكشف البُرد المسجّلة
- `/auth/forgot-password` يرجع نجاحاً دائماً لنفس السبب

---

## النشر

### قبل النشر

- [ ] `JWT_SECRET` قيمة عشوائية طويلة (`openssl rand -hex 32`)
- [ ] `ANTHROPIC_API_KEY` من متغيرات البيئة، لا داخل الكود
- [ ] `CORS_ORIGINS` محدّد بنطاقاتك فقط
- [ ] HTTPS مفعّل (شرط App Transport Security على iOS)
- [ ] نسخ احتياطي دوري لقاعدة البيانات

### الخيار الأسهل — Railway أو Render

1. ارفع مجلد `backend/` إلى مستودع Git
2. اربطه بالمنصة، واضبط: `ANTHROPIC_API_KEY` و `JWT_SECRET` و `CORS_ORIGINS`
3. أمر التشغيل: `npm start`
4. اربط قرصاً دائماً (persistent volume) على `/data` واضبط
   `DATABASE_FILE=/data/coachmint.db` — بدونه ستفقد البيانات عند كل إعادة نشر

### خادم خاص (VPS)

```bash
npm install -g pm2
pm2 start src/server.js --name coachmint-api
pm2 startup && pm2 save
```

ثم ضع Nginx أمامه كـ reverse proxy مع شهادة Let's Encrypt.

### إرسال بريد إعادة التعيين

المسار `/auth/forgot-password` يولّد التوكن ويطبعه في السجل حالياً. للإنتاج
أضف مزوّد بريد (Resend أو Amazon SES) في `src/routes/auth.js` عند علامة
`TODO`، وأرسل الرابط:

```
https://coachmint.app/reset?token=<token>
```
