#!/bin/bash

# 에러 발생 시 즉시 중단
set -e

echo "=== MacOptimizationTool 빌드 시작 ==="

# 1. 이전 빌드 결과물 정리
rm -rf MacOptimizationTool.app MacOptimizationTool testApp main.swift

# 2. Sources 디렉토리 내의 모든 Swift 소스 파일 탐색
SWIFT_FILES=$(find Sources -name "*.swift")

echo "-> Sources 디렉토리 내 Swift 소스 파일 컴파일 중..."
swiftc -O \
       -parse-as-library \
       $SWIFT_FILES \
       -o MacOptimizationTool

# 3. macOS .app 번들 구조 생성
APP_DIR="MacOptimizationTool.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# 실행 바이너리 이동
mv MacOptimizationTool "$MACOS_DIR/MacOptimizationTool"
chmod +x "$MACOS_DIR/MacOptimizationTool"

# 앱 아이콘 복사 (존재하는 경우)
if [ -f "AppIcon.icns" ]; then
    cp AppIcon.icns "$RESOURCES_DIR/"
fi

# 4. Info.plist 동적 생성
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
    <string>1.4.0</string>
    <key>CFBundleVersion</key>
    <string>1.4.0</string>
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

echo "-> 컴파일 완료! macOS .app 번들 구조 생성 중..."

# 5. Ad-hoc 코드 서명 (codesign)
echo "-> macOS TCC 및 알림 서비스를 위한 코드 서명(ad-hoc codesign) 적용 중..."
codesign --force --deep --sign - "$APP_DIR"

echo "-> .app 패키징 및 코드 서명 완료: MacOptimizationTool.app"

# 6. 실행 (CLI 직접 빌드 검증용)
if [ "$1" != "--no-run" ]; then
    echo "=== 빌드 성공! 앱을 실행합니다 ==="
    killall MacOptimizationTool 2>/dev/null || true
    sleep 0.5
    open MacOptimizationTool.app
fi
