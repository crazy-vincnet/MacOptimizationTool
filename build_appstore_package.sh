#!/bin/bash
set -e

echo "=== Mac App Store 패키지 빌드 (.pkg) ==="

# 1. Swift 소스 컴파일 (App Sandbox Entitlements 지정)
SDK_PATH=$(xcrun --show-sdk-path)
swiftc -sdk "$SDK_PATH" \
       -target arm64-apple-macosx14.0 \
       -parse-as-library \
       Sources/*.swift \
       -o MacCleanOptimizer

APP_DIR="MacCleanOptimizer.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"

mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

mv MacCleanOptimizer "$MACOS_DIR/MacCleanOptimizer"
chmod +x "$MACOS_DIR/MacCleanOptimizer"

cat <<EOF > "$APP_DIR/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MacCleanOptimizer</string>
    <key>CFBundleIdentifier</key>
    <string>com.lab98.MacCleanOptimizer</string>
    <key>CFBundleName</key>
    <string>Mac Clean Optimizer</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.3.0</string>
    <key>CFBundleVersion</key>
    <string>2</string>

    <key>CFBundleIconFile</key>
    <string>AppIcon.icns</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Lab98 Studio. All rights reserved.</string>
    <key>LSMinimumSystemVersion</key>

    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>NSUserNotificationUsageDescription</key>
    <string>Mac Clean Optimizer가 시스템 모니터링 및 최적화 상태 알림을 제공합니다.</string>
    <key>NSFullDiskAccessUsageDescription</key>
    <string>대용량 파일 스캔 및 불필요한 시스템 정리를 위해 전체 디스크 접근 권한이 필요합니다.</string>
</dict>
</plist>
EOF

if [ -f "AppIcon.icns" ]; then
    cp -f AppIcon.icns "$RESOURCES_DIR/AppIcon.icns"
fi


echo "-> Extended attributes (Finder detritus) 제거 및 App Sandbox 샌드박싱 코드 서명 적용..."
xattr -cr "$APP_DIR"
codesign --force --deep --options runtime --entitlements MacCleanOptimizer.entitlements --sign - "$APP_DIR"


echo "-> Mac App Store 업로드용 .pkg 패키지 생성을 시작합니다."
productbuild --component "$APP_DIR" /Applications "MacCleanOptimizer_AppStore.pkg"

echo "=== 생성 완료: MacCleanOptimizer_AppStore.pkg ==="
