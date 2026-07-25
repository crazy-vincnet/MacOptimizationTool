#!/bin/bash
set -e

echo "=== 웹사이트 직접 배포용 .dmg 설치 파일 빌드 ==="

# 1. 앱 컴파일 및 코드 서명 실행
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
    <string>com.cleanoptimizer.MacCleanOptimizer</string>
    <key>CFBundleName</key>
    <string>Mac Clean Optimizer</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon.icns</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Lab98 Studio. All rights reserved.</string>
    <key>SUFeedURL</key>
    <string>https://lab98.studio/mac-clean-optimizer/appcast.xml</string>
    <key>SUPublicEDKey</key>
    <string>YOUR_SPARKLE_PUBLIC_EDDSA_KEY</string>
    <key>LSMinimumSystemVersion</key>


    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSUserNotificationUsageDescription</key>
    <string>Mac Clean Optimizer가 실시간 시스템 모니터링 및 메모리 최적화 상태 알림을 제공합니다.</string>
    <key>NSFullDiskAccessUsageDescription</key>
    <string>대용량 파일 탐색 및 불필요한 시스템 정리를 위해 전체 디스크 접근 권한이 필요합니다.</string>
</dict>
</plist>
EOF

if [ -f "AppIcon.icns" ]; then
    cp -f AppIcon.icns "$RESOURCES_DIR/AppIcon.icns"
fi


echo "-> Finder 확장 속성 제거 및 ad-hoc 코드 서명 적용..."
xattr -cr "$APP_DIR"
codesign --force --deep --sign - "$APP_DIR"

DMG_NAME="MacCleanOptimizer_Setup.dmg"
STAGING_DIR="dmg_staging"

# 2. 임시 스테이징 디렉토리 생성 및 드래그 앤 드롭 설치 구조 생성
rm -rf "$STAGING_DIR" "$DMG_NAME"
mkdir -p "$STAGING_DIR"

echo "-> 스테이징 폴더에 앱 및 /Applications 바로가기 링크 생성..."
cp -R "$APP_DIR" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

# 3. hdiutil 기반 .dmg 디스크 이미지 패키징
echo "-> macOS 네이티브 hdiutil로 고압축 .dmg 생성 중..."
hdiutil create \
  -volname "Mac Clean Optimizer Setup" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_NAME"

# 4. 정리
rm -rf "$STAGING_DIR"

echo "=== 성공! 웹사이트 배포용 DMG 설치 파일 생성 완료: $DMG_NAME ==="
