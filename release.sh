#!/bin/bash
set -e

VERSION=$1
NOTES=$2

if [ -z "$VERSION" ]; then
    echo "사용법: ./release.sh <버전태그> [릴리즈노트]"
    echo "예시: ./release.sh v1.0.1 '버전 1.0.1 마이너 업데이트 및 최적화'"
    exit 1
fi

if [ -z "$NOTES" ]; then
    NOTES="Mac Clean Optimizer $VERSION 공식 릴리즈"
fi

RAW_VERSION=$(echo "$VERSION" | sed 's/^v//')

echo "=== GitHub Release 자동 게시 프로세스 시작 ($VERSION) ==="

# 1. 빌드 파일 내 버전 번호 자동 동기화
echo "-> 빌드 스크립트 버전 번호 ($RAW_VERSION) 자동 수정..."
sed -i '' "s/<string>[0-9]*\.[0-9]*\.[0-9]*<\/string>/<string>$RAW_VERSION<\/string>/g" build.sh build_dmg.sh build_appstore_package.sh

# 2. DMG 설치 파일 빌드
echo "-> 최신 $VERSION DMG 디스크 이미지 패키징 중..."
./build_dmg.sh

# 3. Git 커밋 및 태그 생성/푸시
echo "-> Git 태그 생성 및 GitHub 원격 푸시..."
git add .
git commit -m "bump: release $VERSION" || true
git tag -a "$VERSION" -m "$NOTES" || git tag -f "$VERSION"
git push origin main
git push origin "$VERSION" --force

# 4. GitHub CLI (gh) 기반 Release 게시 및 DMG 자동 첨부
echo "-> gh CLI를 통해 GitHub Release 자동 게시 중..."
gh release create "$VERSION" MacCleanOptimizer_Setup.dmg \
    --title "Mac Clean Optimizer $VERSION" \
    --notes "$NOTES"


echo "=== 🎉 성공! GitHub Release $VERSION 및 DMG 첨부가 자동 완료되었습니다 ==="
