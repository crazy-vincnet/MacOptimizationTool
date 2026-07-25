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


echo "=== MacOptimizationTool 빌드 시작 ==="

# 1. 이전 빌드 결과물 정리
rm -rf MacOptimizationTool.app testApp main.swift

# 2. SwiftPM 릴리스 빌드 (MacOptimizationCore + MacOptimizationTool)
echo "-> SwiftPM 릴리스 빌드 중..."
swift build -c release --product MacOptimizationTool
BUILT_BINARY=$(swift build -c release --product MacOptimizationTool --show-bin-path)/MacOptimizationTool

# 3. macOS .app 번들 구조 생성
APP_DIR="MacOptimizationTool.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# 실행 바이너리 복사
cp "$BUILT_BINARY" "$MACOS_DIR/MacOptimizationTool"
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
    <string>1.7.3</string>
    <key>CFBundleVersion</key>
    <string>1.7.3</string>

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
# --deep 은 Apple 이 deprecated 처리한 옵션이라 사용하지 않는다.
# 번들에 중첩 코드가 없으므로 최상위 서명만으로 충분하다.
echo "-> macOS TCC 및 알림 서비스를 위한 코드 서명(ad-hoc codesign) 적용 중..."
sign_with_retry "$APP_DIR" --force --entitlements MacOptimizationTool.entitlements --sign -


echo "-> .app 패키징 및 코드 서명 완료: MacOptimizationTool.app"

# 6. 실행 (CLI 직접 빌드 검증용)
if [ "$1" != "--no-run" ]; then
    echo "=== 빌드 성공! 앱을 실행합니다 ==="
    killall MacOptimizationTool 2>/dev/null || true
    sleep 0.5
    open MacOptimizationTool.app
fi
