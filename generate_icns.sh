#!/bin/bash
set -e

SOURCE_IMG="/Users/vincentjeon/.gemini/antigravity-cli/brain/6be3f470-58f5-44eb-8914-855c5be6ee8a/app_icon_concept2_1784960907213.jpg"
ICONSET="AppIcon.iconset"

rm -rf "$ICONSET" AppIcon.icns AppIcon.png
mkdir -p "$ICONSET"

echo "-> 선택된 Concept 2 아이콘 소스 변환 중..."
sips -s format png "$SOURCE_IMG" --out AppIcon.png >/dev/null

echo "-> macOS 해상도 규격별 아이콘 리사이징 중..."
sips -z 16 16     AppIcon.png --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32     AppIcon.png --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32     AppIcon.png --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64     AppIcon.png --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128   AppIcon.png --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256   AppIcon.png --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256   AppIcon.png --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512   AppIcon.png --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512   AppIcon.png --out "$ICONSET/icon_512x512.png" >/dev/null
sips -z 1024 1024 AppIcon.png --out "$ICONSET/icon_512x512@2x.png" >/dev/null

echo "-> macOS 네이티브 iconutil로 AppIcon.icns 컴파일 중..."
iconutil -c icns "$ICONSET" -o AppIcon.icns
rm -rf "$ICONSET"

echo "=== 생성 완료: AppIcon.icns ==="
