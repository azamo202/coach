#!/usr/bin/env bash
# ============================================================================
#  CoachMint — سكربت تجهيز المشروع (macOS / Linux)
#
#  يولّد مجلدات android و ios الأصلية عبر flutter create، ثم يطبّق إعدادات
#  التطبيق (الاسم العربي، صلاحيات HealthKit و Health Connect، minSdk).
#
#  الاستخدام:  bash setup.sh
# ============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCAFFOLD="$ROOT/_scaffold"
OVERLAY="$ROOT/native_overlay"

echo ""
echo "=== تجهيز مشروع CoachMint ==="
echo ""

# --- 1) التحقق من Flutter -------------------------------------------------
if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter غير مثبّت أو غير موجود في PATH."
  echo "ثبّته من https://docs.flutter.dev/get-started/install ثم أعد المحاولة."
  exit 1
fi

echo "[1/5] فحص Flutter..."
flutter --version

# --- 2) توليد المجلدات الأصلية -------------------------------------------
if [[ -d "$ROOT/android" && -d "$ROOT/ios" ]]; then
  echo "[2/5] مجلدات android و ios موجودة — تخطّي التوليد."
else
  echo "[2/5] توليد مجلدات android و ios..."
  rm -rf "$SCAFFOLD"

  flutter create --org com.coachmint --project-name coachmint \
    --platforms=android,ios --overwrite "$SCAFFOLD"

  for platform in android ios; do
    if [[ ! -d "$ROOT/$platform" ]]; then
      cp -R "$SCAFFOLD/$platform" "$ROOT/$platform"
      echo "      نُسخ $platform"
    fi
  done

  rm -rf "$SCAFFOLD"
fi

# --- 3) تطبيق إعدادات أندرويد --------------------------------------------
echo "[3/5] تطبيق إعدادات أندرويد..."

MANIFEST="$ROOT/android/app/src/main/AndroidManifest.xml"
if [[ -f "$MANIFEST" ]]; then
  cp "$OVERLAY/android/AndroidManifest.xml" "$MANIFEST"
  echo "      AndroidManifest.xml (صلاحيات Health Connect + اسم عربي)"
fi

for gradle in "$ROOT/android/app/build.gradle.kts" "$ROOT/android/app/build.gradle"; do
  if [[ -f "$gradle" ]]; then
    # رفع minSdk إلى 26 (شرط health و flutter_secure_storage)
    sed -i.bak -E 's/minSdk[[:space:]]*=[[:space:]]*flutter\.minSdkVersion/minSdk = 26/' "$gradle"
    sed -i.bak -E 's/minSdkVersion[[:space:]]+flutter\.minSdkVersion/minSdkVersion 26/' "$gradle"
    rm -f "$gradle.bak"
    echo "      minSdk = 26 في $(basename "$gradle")"
  fi
done

# --- 4) تطبيق إعدادات iOS -------------------------------------------------
echo "[4/5] تطبيق إعدادات iOS..."

mkdir -p "$ROOT/ios/Runner"
cp "$OVERLAY/ios/Runner.entitlements" "$ROOT/ios/Runner/Runner.entitlements"
echo "      Runner.entitlements (HealthKit)"

PLIST="$ROOT/ios/Runner/Info.plist"
if [[ -f "$PLIST" ]] && ! grep -q "NSHealthShareUsageDescription" "$PLIST"; then
  python3 - "$PLIST" <<'PYEOF'
import io, sys

plist_path = sys.argv[1]
text = io.open(plist_path, encoding='utf-8').read()

additions = """	<key>CFBundleDisplayName</key>
	<string>CoachMint</string>
	<key>CFBundleLocalizations</key>
	<array>
		<string>ar</string>
		<string>en</string>
	</array>
	<key>NSHealthShareUsageDescription</key>
	<string>نقرأ خطواتك وسعراتك ونشاطك الرياضي لنضبط برنامجك التدريبي على مستوى نشاطك الفعلي.</string>
	<key>NSHealthUpdateUsageDescription</key>
	<string>نسجّل جلساتك التدريبية المكتملة في تطبيق الصحة لتبقى كل بياناتك في مكان واحد.</string>
	<key>LSApplicationQueriesSchemes</key>
	<array>
		<string>https</string>
		<string>http</string>
		<string>mailto</string>
	</array>
</dict>
</plist>
"""

index = text.rfind('</dict>')
if index >= 0:
    io.open(plist_path, 'w', encoding='utf-8').write(text[:index] + additions)
    print('      Info.plist (أذونات HealthKit + الاسم العربي)')
PYEOF
else
  echo "      Info.plist محدّث مسبقاً — تخطّي."
fi

# --- 5) تنزيل الحزم -------------------------------------------------------
echo "[5/5] تنزيل الحزم..."
flutter pub get

echo ""
echo "=== تم التجهيز بنجاح ==="
echo ""
echo "التشغيل بالوضع المحلي (بدون سيرفر، للتجربة فقط):"
echo "  flutter run --dart-define=ANTHROPIC_API_KEY=sk-ant-..."
echo ""
echo "التشغيل مع الباك إند (الوضع الصحيح للإنتاج):"
echo "  flutter run --dart-define=API_BASE_URL=https://api.coachmin.tech"
echo ""
