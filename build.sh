#!/bin/bash
set -e

# Desktop/iCloud FileProvider가 Finder 확장 속성을 다시 붙이는 작업 공간에서는 직접 서명이
# 비결정적으로 실패한다. TMPDIR의 깨끗한 복사본을 서명·검증한 뒤 성공한 번들만 교체한다.
sign_app_safely() {
    local target="$1"
    shift
    local sign_root staged_app verified_app temp_base
    temp_base="${TMPDIR:-/tmp}"
    sign_root=$(mktemp -d "${temp_base%/}/MacOptimizationTool-sign.XXXXXX")
    staged_app="$sign_root/$(basename "$target")"
    verified_app="${target}.signed"

    rm -rf "$verified_app"
    if ! COPYFILE_DISABLE=1 cp -R "$target" "$staged_app"; then
        rm -rf "$sign_root"
        return 1
    fi
    xattr -cr "$staged_app"

    if ! codesign "$@" "$staged_app"; then
        rm -rf "$sign_root"
        return 1
    fi
    if ! codesign --verify --strict --verbose=2 "$staged_app"; then
        rm -rf "$sign_root"
        return 1
    fi

    if ! COPYFILE_DISABLE=1 cp -R "$staged_app" "$verified_app"; then
        rm -rf "$sign_root" "$verified_app"
        return 1
    fi
    if ! codesign --verify --strict --verbose=2 "$verified_app"; then
        rm -rf "$sign_root" "$verified_app"
        return 1
    fi

    rm -rf "$target"
    mv "$verified_app" "$target"
    rm -rf "$sign_root"
}

echo "=== MacOptimizationTool 빌드 시작 ==="

# 1. 이전 빌드 결과물 정리
rm -rf MacOptimizationTool.app MacOptimizationTool.app.signed testApp main.swift

# 2. SwiftPM 릴리스 빌드 (MacOptimizationCore + MacOptimizationTool)
echo "-> SwiftPM 릴리스 빌드 중..."
swift build -c release --product MacOptimizationTool
BUILT_BINARY=$(swift build -c release --product MacOptimizationTool --show-bin-path)/MacOptimizationTool

# 3. macOS .app 번들 구조 생성
APP_DIR="MacOptimizationTool.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BUILT_BINARY" "$MACOS_DIR/MacOptimizationTool"
chmod +x "$MACOS_DIR/MacOptimizationTool"

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
    <string>2.0.0</string>
    <key>CFBundleVersion</key>
    <string>2.0.0</string>
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

echo "-> macOS TCC 및 알림 서비스를 위한 코드 서명(ad-hoc codesign) 적용 중..."
sign_app_safely "$APP_DIR" --force --entitlements MacOptimizationTool.entitlements --sign -

echo "-> .app 패키징 및 코드 서명 완료: MacOptimizationTool.app"

# 6. 실행 (CLI 직접 빌드 검증용)
if [ "${1:-}" != "--no-run" ]; then
    echo "=== 빌드 성공! 앱을 실행합니다 ==="
    killall MacOptimizationTool 2>/dev/null || true
    sleep 0.5
    open MacOptimizationTool.app
fi
