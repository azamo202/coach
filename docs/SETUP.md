# دليل التجهيز التفصيلي

## المتطلبات

| الأداة | الإصدار | لماذا |
|---|---|---|
| Flutter SDK | 3.22 أو أحدث | بناء التطبيق |
| Node.js | 20 أو أحدث | الباك إند |
| Android Studio | Ladybug أو أحدث | بناء أندرويد + المحاكي |
| Xcode | 15 أو أحدث (macOS فقط) | بناء iOS والنشر على App Store |
| مفتاح Anthropic | — | من <https://console.anthropic.com> |

> **بناء iOS يتطلب جهاز Mac.** لا يمكن بناء أو رفع تطبيق iOS من ويندوز.
> إن كان جهازك ويندوز: طوّر واختبر على أندرويد، واستخدم Mac (أو خدمة CI مثل
> Codemagic / GitHub Actions بـ macOS runner) لبناء نسخة iOS ورفعها.

---

## الخطوة 1 — تثبيت Flutter

**Windows:**
1. نزّل الـ SDK من <https://docs.flutter.dev/get-started/install/windows>
2. فُك الضغط في `C:\src\flutter` (تجنّب المسارات التي فيها مسافات أو حروف عربية)
3. أضف `C:\src\flutter\bin` إلى متغير البيئة `Path`
4. أعد فتح الطرفية وتحقق:

```bash
flutter doctor
```

عالج أي مشكلة يظهرها `flutter doctor` قبل المتابعة (خاصة تراخيص Android:
`flutter doctor --android-licenses`).

---

## الخطوة 2 — تجهيز المشروع

المستودع يحتوي على كود Dart كاملاً، لكن مجلدات `android` و `ios` الأصلية
تُولَّد محلياً لأنها تعتمد على إصدار Flutter المثبّت لديك.

```bash
cd coachmint
powershell -ExecutionPolicy Bypass -File setup.ps1   # ويندوز
bash setup.sh                                         # macOS / Linux
```

ماذا يفعل السكربت:

1. يتحقق من وجود Flutter
2. يشغّل `flutter create` في مجلد مؤقت ثم ينسخ `android/` و `ios/` فقط
   (كودك في `lib/` لا يُمَس)
3. يستبدل `AndroidManifest.xml` بنسخة فيها صلاحيات Health Connect والاسم العربي
4. يرفع `minSdk` إلى **26** — مطلوب لحزمتَي `health` و `flutter_secure_storage`
5. ينسخ `Runner.entitlements` ويحقن مفاتيح HealthKit في `Info.plist`
6. يشغّل `flutter pub get`

السكربت **آمن للتشغيل أكثر من مرة** — يتخطى ما هو مُنجز مسبقاً.

---

## الخطوة 3 — تشغيل الباك إند

```bash
cd backend
cp .env.example .env        # ويندوز: copy .env.example .env
npm install
npm start
```

عدّل `.env`:

```env
ANTHROPIC_API_KEY=sk-ant-api03-...
JWT_SECRET=<نص عشوائي طويل — ولّده بـ: openssl rand -hex 32>
```

تحقق أن السيرفر يعمل:

```bash
curl http://localhost:8080/health
```

---

## الخطوة 4 — تشغيل التطبيق

```bash
flutter devices
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

**عنوان الباك إند حسب البيئة:**

| البيئة | العنوان |
|---|---|
| محاكي أندرويد | `http://10.0.2.2:8080` |
| محاكي iOS | `http://localhost:8080` |
| جهاز حقيقي على نفس الشبكة | `http://192.168.x.x:8080` (IP جهازك) |
| إنتاج | `https://api.coachmin.tech` | السيرفر الفعلي مع التشفير وقاعدة البيانات |

> على جهاز أندرويد حقيقي مع سيرفر HTTP غير مشفّر ستحتاج `usesCleartextTraffic`
> في الـ manifest — لكن **لا تفعل ذلك في نسخة الإنتاج**، استخدم HTTPS.

---

## تخصيص هوية التطبيق

### معرّف الحزمة (Bundle ID / Application ID)

الافتراضي `com.coachmint.app`. لتغييره قبل أول نشر:

- **أندرويد**: `android/app/build.gradle.kts` → `applicationId`
- **iOS**: افتح `ios/Runner.xcworkspace` في Xcode → Runner → Signing & Capabilities
  → Bundle Identifier

> غيّره **قبل** أول رفع للمتجر — بعد النشر لا يمكن تغييره.

### اسم التطبيق

- **أندرويد**: `android/app/src/main/AndroidManifest.xml` → `android:label`
- **iOS**: `ios/Runner/Info.plist` → `CFBundleDisplayName`

كلاهما مضبوط على «CoachMint» من قبل السكربت.

### الأيقونة

ضع أيقونة 1024×1024 بصيغة PNG في `assets/images/icon.png` ثم:

```bash
flutter pub add --dev flutter_launcher_icons
```

أضف في `pubspec.yaml`:

```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/images/icon.png"
  adaptive_icon_background: "#0A0A0B"
  adaptive_icon_foreground: "assets/images/icon.png"
  remove_alpha_ios: true
```

ثم:

```bash
dart run flutter_launcher_icons
```

---

## حل المشاكل الشائعة

### `flutter: command not found`
لم يُضف مسار Flutter إلى `Path`. أعد فتح الطرفية بعد تعديل متغيرات البيئة.

### `Minimum supported Gradle version` أو خطأ في بناء أندرويد
```bash
cd android && ./gradlew clean && cd .. && flutter clean && flutter pub get
```

### `uses-sdk:minSdkVersion 21 cannot be smaller than version 26`
السكربت لم ينجح في تعديل `build.gradle`. عدّله يدوياً:
```kotlin
defaultConfig {
    minSdk = 26
}
```

### حزمة `health` لا ترجع بيانات على أندرويد
تطبيق **Health Connect** غير مثبّت أو لم يُمنح الصلاحيات. على أندرويد 13 فما دون
يُثبَّت من Play Store، ومن أندرويد 14 فهو مدمج في النظام. التطبيق يعرض زر التثبيت
تلقائياً عند الحاجة من صفحة «حسابي».

### HealthKit لا يعمل على iOS
1. في Xcode: Runner → Signing & Capabilities → **+ Capability** → HealthKit
2. تأكد أن `Runner.entitlements` مرتبط بالهدف
3. HealthKit **لا يعمل على iPad** ولا على المحاكي بشكل كامل — اختبر على iPhone حقيقي

### `ANTHROPIC_API_KEY` مفقود
في وضع الإنتاج المفتاح يكون في `backend/.env` فقط. الخطأ يظهر فقط في الوضع
المحلي، فمرّر `--dart-define=ANTHROPIC_API_KEY=...` أو استخدم `API_BASE_URL`.

### التطبيق يفتح بالإنجليزية أو باتجاه خاطئ
اتجاه RTL مفروض في `lib/app.dart`. إن ظهرت شاشة بالإنجليزية فهي غالباً شاشة
نظام (مثل نافذة صلاحيات الصحة) — وهذا طبيعي.
