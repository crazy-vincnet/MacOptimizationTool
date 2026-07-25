#!/bin/bash

# 에러 발생 시 즉시 중단
set -e

VERSION="$1"
NOTES="$2"

NOTES_FILE="RELEASE_NOTES.md"

if [ -z "$VERSION" ]; then
    echo "사용법: ./release.sh <버전태그> [릴리즈노트]"
    echo "예시: ./release.sh v1.6.0 'MacOptimizationTool 메이저 기능 출시'"
    echo "      릴리즈노트를 생략하면 $NOTES_FILE 내용을 사용합니다."
    exit 1
fi

# 릴리즈 노트를 인자로 주지 않으면 RELEASE_NOTES.md 를 본문으로 사용한다.
if [ -z "$NOTES" ] && [ -f "$NOTES_FILE" ]; then
    NOTES=$(cat "$NOTES_FILE")
    echo "-> 릴리즈 본문으로 $NOTES_FILE 을 사용합니다."
elif [ -z "$NOTES" ]; then
    NOTES="MacOptimizationTool $VERSION 공식 릴리즈"
fi

# 태그 메시지는 한 줄로 요약한다 (본문 전체를 넣으면 태그가 지저분해진다).
TAG_MESSAGE="MacOptimizationTool $VERSION"

echo "=== GitHub Release 자동 게시 프로세스 시작 ($VERSION) ==="

# 0. 버전 번호 추출 (예: v1.3.0 -> 1.3.0)
CLEAN_VER="${VERSION#v}"

# 세 자리 시맨틱 버전 전체를 대응한다. (기존 `1\.[0-9]\.[0-9]` 는 1.10.0 / 2.x 에서 치환 실패)
if ! echo "$CLEAN_VER" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.]+)?$'; then
    echo "오류: 버전 형식이 올바르지 않습니다 ('$CLEAN_VER'). 예: v1.10.0"
    exit 1
fi

echo "-> 빌드 스크립트 버전 번호 ($CLEAN_VER) 자동 수정..."
sed -i '' -E "s|<string>[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.]+)?</string>|<string>$CLEAN_VER</string>|g" build.sh
sed -i '' -E "s|<string>[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.]+)?</string>|<string>$CLEAN_VER</string>|g" build_dmg.sh

# 1. DMG 패키징 자동 실행
echo "-> 최신 $VERSION DMG 디스크 이미지 패키징 중..."
./build_dmg.sh

# 2. Git 태그 생성 및 원격 푸시 (버전이 바뀐 스크립트만 명시적으로 스테이징)
echo "-> Git 태그 생성 및 GitHub 원격 푸시..."
git add build.sh build_dmg.sh
git commit -m "bump: release $VERSION" || true
git push origin main
git tag -a "$VERSION" -m "$TAG_MESSAGE" || true
git push origin "$VERSION"

# 3. DMG 체크섬 산출 (인앱 업데이터 무결성 검증 및 수동 대조용)
DMG_SHA256=$(shasum -a 256 MacOptimizationTool_Setup.dmg | awk '{print $1}')
echo "-> DMG SHA-256: $DMG_SHA256"

# 4. 릴리즈 본문 조립 (노트 + 체크섬 + 설치 안내)
RELEASE_BODY_FILE=$(mktemp)
cat > "$RELEASE_BODY_FILE" <<BODY
$NOTES

---

### 📦 설치

1. 아래 \`MacOptimizationTool_Setup.dmg\` 를 내려받습니다.
2. DMG 를 열고 앱을 \`/Applications\` 폴더로 드래그합니다.
3. 최초 실행 시 macOS 시스템 설정 > 개인정보 보호 및 보안 > 전체 디스크 접근 권한에서 앱을 허용해 주세요.

### 🔐 무결성 검증

내려받은 파일의 해시가 아래 값과 일치하는지 확인할 수 있습니다.

\`\`\`bash
shasum -a 256 MacOptimizationTool_Setup.dmg
\`\`\`

**MacOptimizationTool_Setup.dmg SHA-256**
\`$DMG_SHA256\`

앱 내 자동 업데이트 기능은 이 해시를 GitHub Release API 의 자산 다이제스트와 대조하여, 일치할 때만 설치 이미지를 마운트합니다.
BODY

# 5. gh CLI를 통해 GitHub Release 생성 및 DMG 자동 첨부
echo "-> gh CLI를 통해 GitHub Release 자동 게시 중..."
gh release create "$VERSION" MacOptimizationTool_Setup.dmg \
    --title "MacOptimizationTool $VERSION" \
    --notes-file "$RELEASE_BODY_FILE"

rm -f "$RELEASE_BODY_FILE"


echo "=== 🎉 성공! GitHub Release $VERSION 및 DMG 첨부가 자동 완료되었습니다 ==="
