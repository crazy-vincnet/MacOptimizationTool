#!/bin/bash

# 에러 발생 시 즉시 중단
set -e

DEV_DIR=$(xcode-select -p)
EXTRA_ARGS=()

# Xcode 없이 Command Line Tools 만 설치된 환경에서는 SwiftPM 이 swift-testing 프레임워크를
# 자동으로 찾지 못한다. 이 경우에만 검색 경로와 rpath 를 직접 지정한다.
if [ ! -d "$DEV_DIR/Platforms/MacOSX.platform" ]; then
    TESTING_FW="$DEV_DIR/Library/Developer/Frameworks"
    TESTING_LIB="$DEV_DIR/Library/Developer/usr/lib"

    if [ -d "$TESTING_FW/Testing.framework" ]; then
        echo "-> Command Line Tools 환경 감지: swift-testing 경로를 직접 지정합니다."
        EXTRA_ARGS=(
            -Xswiftc -F -Xswiftc "$TESTING_FW"
            -Xlinker -F -Xlinker "$TESTING_FW"
            -Xlinker -rpath -Xlinker "$TESTING_FW"
            -Xlinker -rpath -Xlinker "$TESTING_LIB"
        )
    else
        echo "경고: swift-testing 프레임워크를 찾을 수 없습니다. Xcode 설치가 필요할 수 있습니다."
    fi
fi

echo "=== MacOptimizationCore 단위 테스트 실행 ==="
swift test "${EXTRA_ARGS[@]}" "$@"
