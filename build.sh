#!/bin/bash

# 에러 발생 시 스크립트 중단
set -e

echo "=== Mac Clean Optimizer 빌드 시작 ==="

# 1. 이전 빌드 산출물 제거
rm -rf MacCleanOptimizer.app MacCleanOptimizer testApp main.swift

# 2. 컴파일 대상 확인 및 바이너리 빌드
echo "-> Sources 디렉토리 내 Swift 소스 파일 컴파일 중..."
SDK_PATH=$(xcrun --show-sdk-path)
swiftc -sdk "$SDK_PATH" \
       -target arm64-apple-macosx14.0 \
       -parse-as-library \
       Sources/*.swift \
       -o MacCleanOptimizer

echo "-> 컴파일 완료! macOS .app 번들 구조 생성 중..."

# 3. .app 번들 폴더 구조 생성
APP_DIR="MacCleanOptimizer.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"

mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# 4. 컴파일된 바이너리를 번들 내부로 이동 및 권한 부여
mv MacCleanOptimizer "$MACOS_DIR/MacCleanOptimizer"
chmod +x "$MACOS_DIR/MacCleanOptimizer"

# 5. Info.plist 메타데이터 파일 작성
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
    <string>MacCleanOptimizer</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "-> .app 패키징 완료: MacCleanOptimizer.app"
echo "=== 빌드 성공! 앱을 실행합니다 ==="

# 6. 앱 실행
killall MacCleanOptimizer 2>/dev/null || true
sleep 0.5
open MacCleanOptimizer.app
