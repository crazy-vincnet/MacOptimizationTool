#!/bin/bash

# 에러 발생 시 즉시 중단
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


echo "=== 웹사이트 직접 배포용 .dmg 설치 파일 빌드 ==="

# 1. SwiftPM 릴리스 빌드
echo "-> SwiftPM 릴리스 빌드 중..."
swift build -c release --product MacOptimizationTool
BUILT_BINARY=$(swift build -c release --product MacOptimizationTool --show-bin-path)/MacOptimizationTool

APP_DIR="MacOptimizationTool.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

cp "$BUILT_BINARY" "$MACOS_DIR/MacOptimizationTool"
chmod +x "$MACOS_DIR/MacOptimizationTool"

if [ -f "AppIcon.icns" ]; then
    cp AppIcon.icns "$RESOURCES_DIR/"
fi

cat <<EOF > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MacOptimizationTool</string>
    <key>CFBundleIdentifier</key>
    <string>com.lab98.MacOptimizationTool</string>
    <key>CFBundleName</key>
    <string>MacOptimizationTool</string>
    <key>CFBundleDisplayName</key>
    <string>MacOptimizationTool</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.6.0</string>
    <key>CFBundleVersion</key>
    <string>1.6.0</string>

    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <false/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>NSUserNotificationsUsageDescription</key>
    <string>MacOptimizationTool이 실시간 시스템 모니터링 및 메모리 최적화 상태 알림을 제공합니다.</string>
</dict>
</plist>
EOF

echo "-> Finder 확장 속성 제거 및 ad-hoc 코드 서명 적용..."
sign_with_retry "$APP_DIR" --force --deep --sign -

# 2. DMG 패키징 스테이징 폴더 생성
STAGING_DIR="dmg_staging"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

echo "-> 스테이징 폴더에 앱 및 /Applications 바로가기 링크 생성..."
cp -R "$APP_DIR" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

# 3. hdiutil을 이용한 DMG 생성
DMG_NAME="MacOptimizationTool_Setup.dmg"
rm -f "$DMG_NAME"

echo "-> macOS 네이티브 hdiutil로 고압축 .dmg 생성 중..."
hdiutil create \
  -volname "MacOptimizationTool Setup" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_NAME"

# 4. 임시 스테이징 폴더 삭제
rm -rf "$STAGING_DIR"

echo "=== 성공! 웹사이트 배포용 DMG 설치 파일 생성 완료: $DMG_NAME ==="
