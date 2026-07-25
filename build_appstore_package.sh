#!/bin/bash
set -e

# iCloud 동기화 폴더에서는 fileprovider 데몬이 com.apple.FinderInfo 를 비동기로 다시 붙이기 때문에
# 한 번 지우고 바로 서명하면 실패할 수 있다. 지우고 서명하는 과정을 몇 번 재시도한다.
sign_with_retry() {
    local target="$1"
    shift
    local attempt
    for attempt in 1 2 3 4 5; do
        xattr -d com.apple.FinderInfo "$target" 2>/dev/null || true
        xattr -cr "$target"
        if codesign "$@" "$target" 2>/dev/null; then
            return 0
        fi
        sleep 0.5
    done
    echo "오류: 코드 서명에 실패했습니다 ($target)"
    return 1
}


echo "=== Mac App Store 패키지 빌드 (.pkg) ==="

# 1. SwiftPM 릴리스 빌드 (arm64)
swift build -c release --arch arm64 --product MacOptimizationTool
BUILT_BINARY=$(swift build -c release --arch arm64 --product MacOptimizationTool --show-bin-path)/MacOptimizationTool

APP_DIR="MacCleanOptimizer.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"

mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

cp "$BUILT_BINARY" "$MACOS_DIR/MacCleanOptimizer"
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
    <string>1.6.0</string>
    <key>CFBundleVersion</key>
    <string>1.6.0</string>

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
echo "   주의: 샌드박스 구성에서는 /Library 스캔, 관리자 권한 삭제, 프로세스 감시 기능이 동작하지 않는다."
# --deep 은 deprecated. 중첩 코드가 없으므로 최상위 서명만 적용한다.
sign_with_retry "$APP_DIR" --force --options runtime --entitlements MacCleanOptimizer.entitlements --sign -


echo "-> Mac App Store 업로드용 .pkg 패키지 생성을 시작합니다."
productbuild --component "$APP_DIR" /Applications "MacCleanOptimizer_AppStore.pkg"

echo "=== 생성 완료: MacCleanOptimizer_AppStore.pkg ==="
