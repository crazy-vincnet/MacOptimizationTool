#!/bin/bash
set -euo pipefail

# 실제 Mac App Store 배포 자격 증명 없이는 업로드 불가능한 패키지를 만들지 않는다.
: "${APP_SIGN_IDENTITY:?APP_SIGN_IDENTITY에 Mac App Distribution/Application 서명 ID를 지정하세요}"
: "${INSTALLER_SIGN_IDENTITY:?INSTALLER_SIGN_IDENTITY에 Mac Installer Distribution 서명 ID를 지정하세요}"
: "${PROVISIONING_PROFILE:?PROVISIONING_PROFILE에 프로비저닝 프로파일 경로를 지정하세요}"

if [ ! -f "$PROVISIONING_PROFILE" ]; then
    echo "오류: 프로비저닝 프로파일을 찾을 수 없습니다: $PROVISIONING_PROFILE"
    exit 1
fi

APP_VERSION="${APP_VERSION:-2.0.0}"
BUILD_VERSION="${BUILD_VERSION:-$APP_VERSION}"
MIN_MACOS_VERSION="${MIN_MACOS_VERSION:-13.0}"

for version in "$APP_VERSION" "$BUILD_VERSION" "$MIN_MACOS_VERSION"; do
    if [[ ! "$version" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]]; then
        echo "오류: 버전 값은 숫자와 점만 사용할 수 있습니다: $version"
        exit 1
    fi
done

# FileProvider 작업 공간에서는 직접 서명하지 않고 깨끗한 임시 복사본을 서명·검증한다.
sign_app_safely() {
    local target="$1"
    shift
    local sign_root staged_app verified_app temp_base
    temp_base="${TMPDIR:-/tmp}"
    sign_root=$(mktemp -d "${temp_base%/}/MacCleanOptimizer-sign.XXXXXX")
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

echo "=== Mac App Store 패키지 빌드 (.pkg) ==="

swift build -c release --product MacOptimizationTool
BUILT_BINARY=$(swift build -c release --product MacOptimizationTool --show-bin-path)/MacOptimizationTool

APP_DIR="MacCleanOptimizer.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"

rm -rf "$APP_DIR" "$APP_DIR.signed"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BUILT_BINARY" "$MACOS_DIR/MacCleanOptimizer"
chmod +x "$MACOS_DIR/MacCleanOptimizer"
cp "$PROVISIONING_PROFILE" "$APP_DIR/Contents/embedded.provisionprofile"

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
    <string>$APP_VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_VERSION</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon.icns</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Lab98 Studio. All rights reserved.</string>
    <key>LSMinimumSystemVersion</key>
    <string>$MIN_MACOS_VERSION</string>
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

echo "-> App Sandbox entitlement 및 배포 인증서로 코드 서명 중..."
sign_app_safely "$APP_DIR" --force --options runtime --entitlements MacCleanOptimizer.entitlements --sign "$APP_SIGN_IDENTITY"

echo "-> Mac App Store 업로드용 .pkg 패키지를 생성합니다."
rm -f "MacCleanOptimizer_AppStore.pkg"
productbuild --component "$APP_DIR" /Applications --sign "$INSTALLER_SIGN_IDENTITY" "MacCleanOptimizer_AppStore.pkg"
pkgutil --check-signature "MacCleanOptimizer_AppStore.pkg"

echo "=== 생성 완료: MacCleanOptimizer_AppStore.pkg ==="
