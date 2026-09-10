# أدوات المشروع

## لقطات App Store

```bash
flutter test tool/capture_screenshots.dart
```

تُنتج **١٢ لقطة** في `build/screenshots/`:

| المجلد | المقاس | الشرط |
|---|---|---|
| `iphone-6.5/` | 1242 × 2688 | إلزامي لكل تطبيق iPhone |
| `ipad-12.9/` | 2048 × 2732 | إلزامي ما دام التطبيق يدعم iPad |

ستّ شاشات لكل جهاز: الرئيسية، برامجي، البرنامج، الجلسة، تقدّمي، الاشتراك.

الأداة تتحقق من مقاس كل صورة بعد التقاطها. مقاس غير مطابق يُسقط التوليد —
لأن App Store يرفض المقاسات الخاطئة **بعد** الرفع لا قبله.

### لماذا `flutter test` لا محاكي

المشروع يُطوَّر على ويندوز، ولا وجود لمحاكي iOS عليه. و`flutter test` هو
المشغّل الوحيد الذي يرسم شجرة ودجت بلا جهاز. الشاشات المُلتقَطة هي الشاشات
نفسها التي تُبنى في النسخة النهائية — لا رسوماً تمثّلها.

### الخطوط مطلوبة أولاً

الأداة تحتاج ملفات الخطوط في `tool/.fonts/` (المجلد مستثنى من Git).
التطبيق يجلبها من الشبكة وقت التشغيل عبر `google_fonts`، وبيئة الاختبار
بلا شبكة — فبدونها تُرسم **مربّعات فارغة** مكان كل حرف عربي وكل أيقونة.

```bash
mkdir -p tool/.fonts && cd tool/.fonts
BASE=https://github.com/google/fonts/raw/main/ofl
for w in Regular Medium SemiBold Bold; do curl -sLO "$BASE/ibmplexsansarabic/IBMPlexSansArabic-$w.ttf"; done
curl -sL -o PlusJakartaSans.ttf "$BASE/plusjakartasans/PlusJakartaSans%5Bwght%5D.ttf"
```

وخطّ الأيقونات يُنسخ من Flutter SDK:

```bash
cp "$(dirname "$(dirname "$(which flutter)")")/bin/cache/artifacts/material_fonts/materialicons-regular.otf" tool/.fonts/MaterialIcons-Regular.otf
```

### حين تُرقّى حزمة google_fonts

الأداة تملأ ذاكرة الخطوط على القرص ببصمات مأخوذة من جداول `google_fonts`
نفسها (`lib/src/google_fonts_parts/`). لو تغيّرت البصمات بعد ترقية الحزمة،
عاد الجلب الشبكي وظهرت أخطاء `Failed to load font`. حدّث خريطة
`cacheHashes` في أعلى `capture_screenshots.dart` من الحزمة الجديدة.

### ملاحظة على علامة النسبة

`AppType.number` يرسم الأرقام بـ**Plus Jakarta Sans**، والتطبيق يكتب النِّسب
بعلامة النسبة العربية `٪` (U+066A) — وهي **غير موجودة في هذا الخطّ**. على
الجهاز يسدّها خطّ النظام العربي تلقائياً، فتظهر بمحرف من عائلة أخرى بجانب
الأرقام. الأداة تسجّل الخطّ العربي احتياطاً خلفه لتطابق ما يراه المستخدم.
