# ============================================================================
#  CoachMint - Setup Script (Windows / PowerShell)
# ============================================================================

$ErrorActionPreference = 'Stop'

$root = $PSScriptRoot
$scaffold = Join-Path $root '_scaffold'
$overlay = Join-Path $root 'native_overlay'

Write-Host ''
Write-Host '=== CoachMint Setup ===' -ForegroundColor Cyan
Write-Host ''

# --- 1) Check Flutter --------------------------------------------------------
$flutter = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutter) {
    Write-Host 'Error: Flutter is not installed or not in PATH.' -ForegroundColor Red
    Write-Host 'Install Flutter from https://docs.flutter.dev/get-started/install and retry.'
    exit 1
}

Write-Host '[1/5] Checking Flutter...' -ForegroundColor Yellow
flutter --version

# --- 2) Generate native folders if missing -----------------------------------
if ((Test-Path (Join-Path $root 'android')) -and (Test-Path (Join-Path $root 'ios'))) {
    Write-Host '[2/5] Native folders (android & ios) already exist - skipping generation.' -ForegroundColor Green
} else {
    Write-Host '[2/5] Generating android and ios folders...' -ForegroundColor Yellow

    if (Test-Path $scaffold) { Remove-Item -Recurse -Force $scaffold }

    flutter create --org com.coachmint --project-name coachmint --platforms=android,ios --overwrite $scaffold

    foreach ($platform in @('android', 'ios')) {
        $src = Join-Path $scaffold $platform
        $dst = Join-Path $root $platform
        if (-not (Test-Path $dst)) {
            Copy-Item -Recurse $src $dst
            Write-Host "      Copied $platform" -ForegroundColor Green
        }
    }

    Remove-Item -Recurse -Force $scaffold
}

# --- 3) Apply Android settings -----------------------------------------------
Write-Host '[3/5] Applying Android settings...' -ForegroundColor Yellow

$manifestDst = Join-Path $root 'android\app\src\main\AndroidManifest.xml'
$manifestSrc = Join-Path $overlay 'android\AndroidManifest.xml'
if (Test-Path $manifestDst) {
    Copy-Item $manifestSrc $manifestDst -Force
    Write-Host '      Updated AndroidManifest.xml' -ForegroundColor Green
}

$gradleFiles = @(
    (Join-Path $root 'android\app\build.gradle.kts'),
    (Join-Path $root 'android\app\build.gradle')
) | Where-Object { Test-Path $_ }

foreach ($gradle in $gradleFiles) {
    $content = Get-Content $gradle -Raw
    $content = $content -replace 'minSdk\s*=\s*flutter\.minSdkVersion', 'minSdk = 26'
    $content = $content -replace 'minSdkVersion\s+flutter\.minSdkVersion', 'minSdkVersion 26'
    Set-Content $gradle $content -Encoding utf8
    Write-Host "      Set minSdk = 26 in $(Split-Path $gradle -Leaf)" -ForegroundColor Green
}

# --- 4) Apply iOS settings ---------------------------------------------------
Write-Host '[4/5] Applying iOS settings...' -ForegroundColor Yellow

$entitlementsDst = Join-Path $root 'ios\Runner\Runner.entitlements'
if (Test-Path (Join-Path $overlay 'ios\Runner.entitlements')) {
    Copy-Item (Join-Path $overlay 'ios\Runner.entitlements') $entitlementsDst -Force
    Write-Host '      Copied Runner.entitlements' -ForegroundColor Green
}

$plist = Join-Path $root 'ios\Runner\Info.plist'
if (Test-Path $plist) {
    $plistContent = Get-Content $plist -Raw

    if ($plistContent -notmatch 'NSHealthShareUsageDescription') {
        $additions = @'
	<key>CFBundleDisplayName</key>
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
'@
        $lastDict = $plistContent.LastIndexOf('</dict>')
        if ($lastDict -ge 0) {
            $plistContent = $plistContent.Substring(0, $lastDict) + $additions
            Set-Content $plist $plistContent -Encoding utf8
            Write-Host '      Updated Info.plist' -ForegroundColor Green
        }
    } else {
        Write-Host '      Info.plist is already configured.' -ForegroundColor Green
    }
}

# --- 5) Fetch Flutter packages -----------------------------------------------
Write-Host '[5/5] Running flutter pub get...' -ForegroundColor Yellow
flutter pub get

Write-Host ''
Write-Host '=== Setup Completed Successfully ===' -ForegroundColor Cyan
Write-Host ''
Write-Host 'Run in demo mode (no backend):' -ForegroundColor White
Write-Host '  flutter run --dart-define=ANTHROPIC_API_KEY=sk-ant-...' -ForegroundColor Gray
Write-Host ''
Write-Host 'Run with local backend:' -ForegroundColor White
Write-Host '  flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080' -ForegroundColor Gray
Write-Host ''
