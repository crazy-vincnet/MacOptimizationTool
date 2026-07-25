#!/bin/bash
set -e

echo "=== 📸 Mac Clean Optimizer 실제 스크린샷 자동 캡처 도구 ==="
echo ""

# 1. 앱 활성화
echo "-> 1/2. MacCleanOptimizer 앱을 최상단으로 활성화합니다..."
swift - <<'EOF'
import Foundation
import Cocoa

let apps = NSWorkspace.shared.runningApplications.filter { $0.localizedName == "MacCleanOptimizer" }
if let app = apps.first {
    app.activate(options: [.activateIgnoringOtherApps])
}
EOF

sleep 1

# 2. 윈도우 좌표 탐색
BOUNDS=$(swift - <<'EOF'
import Foundation
import CoreGraphics

let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
for win in windowList {
    if let ownerName = win[kCGWindowOwnerName as String] as? String, ownerName == "MacCleanOptimizer",
       let boundsDict = win[kCGWindowBounds as String] as? [String: Any],
       let x = boundsDict["X"] as? Int,
       let y = boundsDict["Y"] as? Int,
       let width = boundsDict["Width"] as? Int,
       let height = boundsDict["Height"] as? Int, width > 300 && height > 300 {
        print("\(x),\(y),\(width),\(height)")
        exit(0)
    }
}
print("100,100,1200,800")
EOF
)

echo "-> 캡처 영역 (x,y,w,h): $BOUNDS"
echo "-> 3초 후 첫 번째 화면(대시보드)을 캡처합니다..."
sleep 2
screencapture -R "$BOUNDS" docs/screenshot_dashboard.jpg
echo "✅ 첫 번째 스크린샷 캡처 완료: docs/screenshot_dashboard.jpg"
echo ""

echo "-> 2/2. 앱에서 다음 화면(앱 완전 삭제기 또는 디스크 정리)으로 이동한 후 Enter 키를 누르세요."
read -p "준비가 되면 엔터(Enter)를 누르세요: " dummy

echo "-> 2초 후 두 번째 화면을 캡처합니다..."
sleep 1.5

# 앱 재활성화
swift - <<'EOF'
import Foundation
import Cocoa

let apps = NSWorkspace.shared.runningApplications.filter { $0.localizedName == "MacCleanOptimizer" }
if let app = apps.first {
    app.activate(options: [.activateIgnoringOtherApps])
}
EOF

sleep 0.5
screencapture -R "$BOUNDS" docs/screenshot_uninstaller.jpg
echo "✅ 두 번째 스크린샷 캡처 완료: docs/screenshot_uninstaller.jpg"
echo ""

# Git 커밋 및 웹사이트 즉시 푸시
echo "-> 웹사이트(GitHub Pages)로 스크린샷 자동 업로드 중..."
git add docs/screenshot_dashboard.jpg docs/screenshot_uninstaller.jpg
git commit -m "chore: update real user-captured screenshots for website" || true
git push origin main

echo ""
echo "=== 🎉 성공! 새로운 실제 스크린샷이 웹사이트(https://crazy-vincnet.github.io/MacOptimizationTool/)에 배포되었습니다 ==="
