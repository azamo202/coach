# دليل النشر على App Store و Google Play

> العميل طلب البدء بـ **App Store**، لذا قسم iOS أولاً.

---

## قبل أي نشر

- [ ] معرّف الحزمة نهائي (لا يمكن تغييره بعد أول رفع)
- [ ] الباك إند منشور على HTTPS ويعمل
- [ ] التطبيق مبني بـ `--dart-define=API_BASE_URL=https://...` وليس بمفتاح
      Anthropic داخل الحزمة
- [ ] الأيقونة 1024×1024 بدون شفافية (شرط Apple)
- [ ] صفحتا **سياسة الخصوصية** و**شروط الاستخدام** منشورتان على الإنترنت
      (روابطهما في `lib/core/config/app_config.dart` — حدّثهما)
- [ ] `flutter test` يمر بالكامل
- [ ] اختبار على جهاز حقيقي: إنشاء حساب → تحديد المستوى → توليد برنامج →
      إكمال جلسة → إعادة فتح التطبيق والتأكد من حفظ التقدّم

---

## App Store (iOS)

### 1. المتطلبات

- جهاز Mac مع Xcode 15+
- حساب **Apple Developer** بـ 99 دولاراً سنوياً
- التسجيل من <https://developer.apple.com/programs/>

### 2. الإعداد في Xcode

```bash
open ios/Runner.xcworkspace
```

1. **Runner → Signing & Capabilities**
   - فعّل *Automatically manage signing*
   - اختر الـ Team
   - اضبط Bundle Identifier (مثل `com.coachmint.app`)
2. اضغط **+ Capability** وأضف **HealthKit**
3. **General → Deployment Info**: iOS 13.0 كحد أدنى، Portrait فقط

### 3. رفع البناء

```bash
flutter build ipa --release --dart-define=API_BASE_URL=https://api.coachmint.app
```

ثم من Xcode: **Product → Archive → Distribute App → App Store Connect**،
أو استخدم:

```bash
xcrun altool --upload-app --type ios \
  -f build/ios/ipa/coachmint.ipa \
  --apiKey <KEY_ID> --apiIssuer <ISSUER_ID>
```

### 4. App Store Connect

أنشئ التطبيق على <https://appstoreconnect.apple.com> واملأ:

| الحقل | القيمة المقترحة |
|---|---|
| الاسم | CoachMint |
| الاسم الفرعي | مدربك الرياضي الذكي |
| الفئة الأساسية | Health & Fitness |
| اللغة الأساسية | العربية |
| الفئة العمرية | 12+ |

**الوصف:**

> CoachMint يبني لك برنامجاً تدريبياً خاصاً بك في أي رياضة تختارها — كرة قدم،
> سباحة، بادل، ملاكمة، أو أي رياضة تكتبها بنفسك.
>
> حدّد مستواك (مبتدئ، متوسط، أو محترف) وسيبني لك الذكاء الاصطناعي برنامجاً
> متدرجاً أسبوعياً يناسب قدراتك بالضبط: عدد المجموعات والتكرارات وزمن الراحة
> وطريقة أداء كل تمرين خطوة بخطوة.
>
> • اختيار حر لأي رياضة
> • برنامج متدرج يزداد صعوبة كل أسبوع
> • مرجع سريع لطريقة أداء كل تمرين
> • تتبّع تلقائي لنسبة إنجازك وجلساتك المكتملة
> • تابع أكثر من رياضة في نفس الوقت
> • تكامل مع تطبيق الصحة لقراءة نشاطك اليومي

**لقطات الشاشة المطلوبة:** 6.7 بوصة (1290×2796) و 6.5 بوصة (1242×2688).
التقطها من محاكي iPhone 15 Pro Max بـ `Cmd+S`.

### 5. الأسئلة الحرجة في المراجعة

**خصوصية البيانات (App Privacy):** أفصح عن:
- *Contact Info → Email* — للحساب، مرتبط بالهوية، لا يُستخدم للتتبع
- *Health & Fitness* — إن فعّلت HealthKit
- *Usage Data* — إن أضفت تحليلات لاحقاً

**HealthKit:** يجب أن توضح للمراجع سبب الاستخدام. النصوص جاهزة في
`Info.plist`. Apple ترفض التطبيقات التي تطلب HealthKit بلا سبب واضح.

**المحتوى المولّد بالذكاء الاصطناعي:** أضف في *App Review Information → Notes*:

> التطبيق يولّد برامج تدريبية عبر Anthropic Claude API. المحتوى مقيّد بـ
> system prompt يقتصر على التدريب الرياضي، والمستخدم لا يمكنه توليد محتوى حر.
> يظهر تنبيه في كل برنامج بمراجعة مختص عند وجود إصابة أو حالة صحية.

**حساب تجريبي:** وفّر بريداً وكلمة مرور جاهزين للمراجع، وإلا سيُرفض التطبيق.

**رفض شائع (Guideline 5.1.1):** يجب أن يوفّر التطبيق **حذف الحساب** من داخله
— وهذا مطبَّق في «حسابي ← حذف الحساب».

---

## Google Play (أندرويد)

### 1. المتطلبات

- حساب **Google Play Console** بـ 25 دولاراً (مرة واحدة)
- التسجيل من <https://play.google.com/console>

### 2. مفتاح التوقيع

```bash
keytool -genkey -v -keystore ~/coachmint-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias coachmint
```

> **احتفظ بهذا الملف وكلمة مروره في مكان آمن.** فقدانه يعني عدم القدرة على
> تحديث التطبيق نهائياً.

أنشئ `android/key.properties` (مستثنى من Git مسبقاً):

```properties
storePassword=<كلمة المرور>
keyPassword=<كلمة المرور>
keyAlias=coachmint
storeFile=C:/Users/<اسمك>/coachmint-release.jks
```

في `android/app/build.gradle.kts` أضف قبل `android { }`:

```kotlin
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
```

وداخل `android { }`:

```kotlin
signingConfigs {
    create("release") {
        keyAlias = keystoreProperties["keyAlias"] as String
        keyPassword = keystoreProperties["keyPassword"] as String
        storeFile = file(keystoreProperties["storeFile"] as String)
        storePassword = keystoreProperties["storePassword"] as String
    }
}
buildTypes {
    release {
        signingConfig = signingConfigs.getByName("release")
        isMinifyEnabled = true
        isShrinkResources = true
    }
}
```

### 3. البناء

```bash
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://api.coachmint.app
```

الناتج: `build/app/outputs/bundle/release/app-release.aab`

### 4. Play Console

| المطلوب | التفاصيل |
|---|---|
| لقطات شاشة | 2 على الأقل، من 320 إلى 3840 بكسل |
| صورة الغلاف | 1024×500 |
| الأيقونة | 512×512 PNG |
| الوصف المختصر | 80 حرفاً كحد أقصى |
| الوصف الكامل | 4000 حرف كحد أقصى |

**Data Safety:** أفصح عن جمع البريد والاسم وبيانات اللياقة، وأكّد التشفير
أثناء النقل ووجود خيار حذف الحساب.

**Health Connect:** يتطلب نموذج إفصاح منفصل عن سبب قراءة كل نوع بيانات.
املأه من Play Console ← *App content* ← *Health apps declaration*.

**Target API:** يجب أن يستهدف أحدث مستوى تطلبه Google (يتغير سنوياً).

---

## بعد النشر

- راقب سجلات الباك إند وفاتورة Anthropic (كل توليد يكلّف — حد الـ 20/ساعة يحمي)
- التحديثات: ارفع `version: 1.0.1+2` في `pubspec.yaml` (رقم البناء يجب أن
  يزيد في كل رفع)
- Apple تراجع التحديثات عادة خلال 24–48 ساعة، Google خلال ساعات إلى أيام
