import Foundation
import Testing
@testable import MacOptimizationCore

/// 앱 잔여물 매칭 규칙 테스트.
/// 오탐(다른 앱 파일을 잡는 것)이 미탐보다 훨씬 위험하다 — `/Library` 하위 오탐은
/// 관리자 권한 영구 삭제로 이어지기 때문이다.
@Suite("LeftoverMatcher 잔여물 매칭")
struct LeftoverMatcherTests {

    // MARK: - 정상 매칭

    @Test("이름 정확 일치")
    func exactNameMatches() {
        #expect(LeftoverMatcher.matches(fileName: "Notion", appName: "Notion", bundleID: nil))
        #expect(LeftoverMatcher.matches(fileName: "notion", appName: "Notion", bundleID: nil))
    }

    @Test("번들 식별자 일치")
    func bundleIdentifierMatches() {
        #expect(LeftoverMatcher.matches(fileName: "notion.id", appName: "Notion", bundleID: "notion.id"))
        #expect(LeftoverMatcher.matches(fileName: "notion.id.plist", appName: "Notion", bundleID: "notion.id"))
        #expect(LeftoverMatcher.matches(fileName: "com.vendor.app.helper", appName: "Whatever", bundleID: "com.vendor.app"))
    }

    @Test("구분자를 동반한 접두사 일치", arguments: [
        "notion-helper", "notion.helper", "notion_helper", "notion helper"
    ])
    func prefixWithDelimiterMatches(fileName: String) {
        #expect(LeftoverMatcher.matches(fileName: fileName, appName: "Notion", bundleID: nil))
    }

    @Test("토큰 단위 일치")
    func tokenMatches() {
        #expect(LeftoverMatcher.matches(fileName: "com.company.notion.plist", appName: "Notion", bundleID: nil))
    }

    @Test(".plist 접미사를 제거한 뒤 비교한다")
    func plistSuffixIsStrippedBeforeExactCompare() {
        #expect(LeftoverMatcher.matches(fileName: "Notion.plist", appName: "Notion", bundleID: nil))
    }

    // MARK: - 오탐 방지

    @Test("짧은 앱 이름은 부분 일치하지 않는다")
    func shortAppNamesDoNotMatchPartially() {
        #expect(!LeftoverMatcher.matches(fileName: "com.apple.dt.plist", appName: "dt", bundleID: nil))
        #expect(!LeftoverMatcher.matches(fileName: "abc-something", appName: "abc", bundleID: nil))
    }

    @Test("일반적인 앱 이름은 부분 일치하지 않는다", arguments: [
        "app", "helper", "system", "manager", "tool", "cleaner"
    ])
    func genericAppNamesDoNotMatchPartially(generic: String) {
        #expect(!LeftoverMatcher.matches(fileName: "com.apple.\(generic).plist", appName: generic, bundleID: nil))
    }

    @Test("무관한 파일은 일치하지 않는다")
    func unrelatedFilesDoNotMatch() {
        #expect(!LeftoverMatcher.matches(fileName: "com.apple.finder.plist", appName: "Notion", bundleID: "notion.id"))
        #expect(!LeftoverMatcher.matches(fileName: "SystemMigration.log", appName: "Notion", bundleID: nil))
    }

    /// 접두사 일치는 구분자를 요구한다. `Note` 가 `Notebook` 파일을 잡으면 안 된다.
    @Test("구분자 없는 접두사는 일치하지 않는다")
    func prefixWithoutDelimiterDoesNotMatch() {
        #expect(!LeftoverMatcher.matches(fileName: "notebook.plist", appName: "Note", bundleID: nil))
        #expect(!LeftoverMatcher.matches(fileName: "notionary", appName: "Notion", bundleID: nil))
    }

    @Test("빈 번들 식별자는 무시된다")
    func emptyBundleIDIsIgnored() {
        // 빈 문자열은 모든 이름에 contains 로 일치하므로 반드시 걸러야 한다.
        #expect(!LeftoverMatcher.matches(fileName: "com.apple.finder.plist", appName: "Notion", bundleID: ""))
    }

    @Test("짧은 파일명은 번들 식별자 포함 규칙을 통과하지 못한다")
    func shortFileNameDoesNotMatchLongBundleIDContains() {
        #expect(!LeftoverMatcher.matches(fileName: "com", appName: "Notion", bundleID: "com.vendor.notion"))
        #expect(LeftoverMatcher.matches(fileName: "com.vendor.n", appName: "Notion", bundleID: "com.vendor.notion"))
    }
}
