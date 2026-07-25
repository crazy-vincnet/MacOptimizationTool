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
    <string>1.7.1</string>
    <key>CFBundleVersion</key>
    <string>1.7.1</string>

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
sign_with_retry "$APP_DIR" --force --entitlements MacOptimizationTool.entitlements --sign -

# 2. DMG 패키징 스테이징 폴더 생성
# 볼륨 이름에 버전을 넣으면 창 제목에 버전이 드러나고,
# Finder 가 이전 버전 볼륨의 창 상태를 재사용해 레이아웃이 안 보이는 문제도 피할 수 있다.
APP_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_DIR/Contents/Info.plist" 2>/dev/null || echo "")
if [ -n "$APP_VERSION" ]; then
    VOLUME_NAME="MacOptimizationTool $APP_VERSION"
else
    VOLUME_NAME="MacOptimizationTool"
fi
DMG_NAME="MacOptimizationTool_Setup.dmg"

# 스테이징 폴더와 임시 DMG 는 반드시 iCloud 동기화 폴더 밖에서 만든다.
# 동기화 폴더(Desktop/Documents) 안에서 만든 볼륨은 fileprovider 가 개입해
# Finder 의 뷰 설정 적용이 -10006 으로 실패한다.
WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/macopt-dmg.XXXXXX")
STAGING_DIR="$WORK_DIR/staging"
TEMP_DMG="$WORK_DIR/temp.dmg"
trap 'rm -rf "$WORK_DIR"' EXIT

# 배경 폴더는 레이아웃을 적용하는 동안 "보이는" 상태여야 한다.
# 숨김 폴더(.background)는 Finder 가 파일을 해석하지 못해 배경이 색상으로 폴백된다.
# 레이아웃 적용 후 chflags 로 숨긴다.
mkdir -p "$STAGING_DIR/background"

echo "-> 스테이징 폴더에 앱 및 /Applications 바로가기 링크 생성..."
cp -R "$APP_DIR" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

# 3. 설치 창 배경 이미지 생성 (1x + 2x 를 한 TIFF 로 묶어 Retina 대응)
echo "-> 설치 창 배경 이미지 생성 중..."
BG_DIR="$STAGING_DIR/background"
swift scripts/make_dmg_background.swift "$BG_DIR/bg.png" 1
swift scripts/make_dmg_background.swift "$BG_DIR/bg@2x.png" 2

# Finder 는 배경 이미지를 논리 포인트 크기로 표시한다. 2x PNG 에 DPI 144 를 심어 두면
# 같은 파일로 Retina 선명도를 얻을 수 있다. (다중 표현 TIFF 는 Finder 가 뷰 설정 자체를
# 무시하는 경우가 있어 사용하지 않는다.)
sips -s dpiHeight 144 -s dpiWidth 144 "$BG_DIR/bg@2x.png" --out "$BG_DIR/background.png" >/dev/null 2>&1 \
    || mv "$BG_DIR/bg@2x.png" "$BG_DIR/background.png"
rm -f "$BG_DIR/bg.png" "$BG_DIR/bg@2x.png"
BACKGROUND_FILE="background.png"

# 4. 볼륨 아이콘 지정 (앱 아이콘 재사용)
if [ -f "AppIcon.icns" ]; then
    cp AppIcon.icns "$STAGING_DIR/.VolumeIcon.icns"
fi

# 5. 쓰기 가능한 DMG 생성 후 마운트
rm -f "$TEMP_DMG" "$DMG_NAME"

echo "-> 임시 읽기/쓰기 DMG 생성 중..."
hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -fs HFS+ \
  -format UDRW \
  "$TEMP_DMG" >/dev/null

MOUNT_DIR="/Volumes/$VOLUME_NAME"
hdiutil detach "$MOUNT_DIR" >/dev/null 2>&1 || true
hdiutil attach "$TEMP_DMG" -readwrite -noverify -noautoopen >/dev/null
# Finder 가 새 볼륨을 인식하고 창 상태를 준비할 시간을 준다.
sleep 4

# 6. Finder 로 창 레이아웃 지정
# Finder 자동화 권한이 없으면 실패할 수 있으므로, 실패해도 DMG 생성은 계속한다.
echo "-> Finder 창 레이아웃(배경, 아이콘 위치, 창 크기) 적용 중..."
# 볼륨을 막 마운트한 직후에는 Finder 의 뷰 설정 적용이 간헐적으로 실패한다.
# 실패해도 DMG 생성 자체는 계속하되, 몇 차례 재시도한다.
LAYOUT_LOG=$(mktemp)
LAYOUT_OK=0
for attempt in 1 2 3; do
    if osascript scripts/dmg_layout.applescript "$VOLUME_NAME" "$APP_DIR" "$BACKGROUND_FILE" >"$LAYOUT_LOG" 2>&1; then
        LAYOUT_OK=1
        echo "   창 레이아웃 적용 완료. (시도 $attempt 회)"
        break
    fi
    sleep 2
done

if [ "$LAYOUT_OK" -eq 0 ]; then
    echo "   경고: 창 레이아웃을 적용하지 못했습니다. 레이아웃 없이 DMG 생성을 계속합니다."
    echo "   원인: $(cat "$LAYOUT_LOG")"
    echo "   Finder 자동화 권한이 필요할 수 있습니다:"
    echo "   시스템 설정 > 개인정보 보호 및 보안 > 자동화 에서 터미널의 Finder 제어를 허용하세요."
fi
rm -f "$LAYOUT_LOG"

# 볼륨 아이콘 활성화 플래그
if [ -f "$MOUNT_DIR/.VolumeIcon.icns" ] && command -v SetFile >/dev/null 2>&1; then
    SetFile -a C "$MOUNT_DIR" 2>/dev/null || true
fi

chmod -Rf go-w "$MOUNT_DIR" 2>/dev/null || true

# Finder 가 .DS_Store 를 실제로 기록할 때까지 기다린 뒤 동기화한다.
# 이 과정을 생략하면 창 레이아웃이 최종 DMG 에 반영되지 않는다.
for i in 1 2 3 4 5 6 7 8 9 10; do
    if [ -f "$MOUNT_DIR/.DS_Store" ]; then break; fi
    sleep 1
done
sleep 2
sync

# 레이아웃이 저장된 뒤 배경 폴더를 숨긴다.
chflags hidden "$MOUNT_DIR/background" 2>/dev/null || true

if [ -f "$MOUNT_DIR/.DS_Store" ]; then
    echo "   레이아웃 저장 확인: .DS_Store ($(stat -f%z "$MOUNT_DIR/.DS_Store") bytes)"
else
    echo "   경고: .DS_Store 가 생성되지 않아 레이아웃이 저장되지 않았을 수 있습니다."
fi

# 창을 닫아 Finder 가 볼륨을 붙잡고 있지 않도록 한다.
osascript -e 'tell application "Finder" to close (every window whose name is "'"$VOLUME_NAME"'")' >/dev/null 2>&1 || true
sleep 1

# 7. 마운트 해제 후 압축 DMG 로 변환
echo "-> DMG 마운트 해제 및 고압축 변환 중..."
hdiutil detach "$MOUNT_DIR" >/dev/null || {
    sleep 3
    hdiutil detach "$MOUNT_DIR" -force >/dev/null
}

hdiutil convert "$TEMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_NAME" >/dev/null

# 8. 임시 작업 디렉터리 정리 (trap 으로도 정리되지만 명시적으로 한 번 더)
rm -rf "$WORK_DIR"

echo "=== 성공! 웹사이트 배포용 DMG 설치 파일 생성 완료: $DMG_NAME ==="
