#!/bin/bash

# 에러 발생 시 즉시 중단
set -e

VERSION="$1"
NOTES="$2"

if [ -z "$VERSION" ]; then
    echo "사용법: ./release.sh <버전태그> [릴리즈노트]"
    echo "예시: ./release.sh v1.3.0 'MacOptimizationTool 메이저 기능 출시'"
    exit 1
fi

if [ -z "$NOTES" ]; then
    NOTES="MacOptimizationTool $VERSION 공식 릴리즈"
fi

echo "=== GitHub Release 자동 게시 프로세스 시작 ($VERSION) ==="

# 0. 버전 번호 추출 (예: v1.3.0 -> 1.3.0)
CLEAN_VER="${VERSION#v}"

echo "-> 빌드 스크립트 버전 번호 ($CLEAN_VER) 자동 수정..."
sed -i '' "s/<string>1\.[0-9]\.[0-9]<\/string>/<string>$CLEAN_VER<\/string>/g" build.sh
sed -i '' "s/<string>1\.[0-9]\.[0-9]<\/string>/<string>$CLEAN_VER<\/string>/g" build_dmg.sh

# 1. DMG 패키징 자동 실행
echo "-> 최신 $VERSION DMG 디스크 이미지 패키징 중..."
./build_dmg.sh

# 2. Git 태그 생성 및 원격 푸시
echo "-> Git 태그 생성 및 GitHub 원격 푸시..."
git add .
git commit -m "bump: release $VERSION" || true
git push origin main
git tag -a "$VERSION" -m "$NOTES" || true
git push origin "$VERSION"

# 3. gh CLI를 통해 GitHub Release 생성 및 DMG 자동 첨부
echo "-> gh CLI를 통해 GitHub Release 자동 게시 중..."
gh release create "$VERSION" MacOptimizationTool_Setup.dmg \
    --title "MacOptimizationTool $VERSION" \
    --notes "$NOTES"


echo "=== 🎉 성공! GitHub Release $VERSION 및 DMG 첨부가 자동 완료되었습니다 ==="
