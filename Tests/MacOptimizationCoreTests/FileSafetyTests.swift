import Foundation
import Testing
@testable import MacOptimizationCore

/// 삭제 안전 규칙 회귀 테스트.
/// 여기서 통과해야 할 것: 시스템 경로는 절대 삭제 대상이 되지 않고,
/// 앱 잔여물은 `/Library` 의 허용 하위 트리에서만 삭제 대상이 된다.
@Suite("FileSafety 삭제 안전 규칙")
struct FileSafetyTests {

    private var home: String {
        FileManager.default.homeDirectoryForCurrentUser.standardized.path
    }

    // MARK: - 정확 일치 보호

    @Test("시스템 루트는 정확 일치로 보호된다", arguments: [
        "/", "/System", "/Library", "/usr", "/bin", "/etc", "/var", "/Applications", "/Users"
    ])
    func systemRootsAreProtectedExactly(path: String) {
        #expect(FileSafety.isProtectedExact(path))
    }

    @Test("홈과 홈 최상위 폴더는 보호된다")
    func homeAndTopLevelUserFoldersAreProtected() {
        #expect(FileSafety.isProtectedExact(home))
        for sub in ["Library", "Desktop", "Documents", "Downloads", "Movies", "Music", "Pictures"] {
            #expect(FileSafety.isProtectedExact(home + "/" + sub), "\(sub) 는 보호되어야 한다")
        }
    }

    @Test("보호 판정은 대소문자를 구분하지 않는다")
    func protectionIsCaseInsensitive() {
        #expect(FileSafety.isProtectedExact("/SYSTEM"))
        #expect(FileSafety.isProtectedExact("/LiBrArY"))
    }

    @Test("경로는 표준화 후 비교된다")
    func pathsAreNormalizedBeforeComparison() {
        #expect(FileSafety.isProtectedExact("/System/"))
        #expect(FileSafety.isProtectedExact("/Library/../Library"))
        #expect(FileSafety.isProtectedExact("/usr/./"))
    }

    @Test("일반 사용자 파일은 정확 일치 보호 대상이 아니다")
    func ordinaryUserFileIsNotProtectedExactly() {
        #expect(!FileSafety.isProtectedExact(home + "/Downloads/report.pdf"))
    }

    // MARK: - 트리 보호

    @Test("시스템 트리는 하위까지 보호된다", arguments: [
        "/System/Library/Fonts", "/usr/local/bin/tool", "/private/var/db/x", "/etc/hosts"
    ])
    func systemTreesAreProtectedRecursively(path: String) {
        #expect(FileSafety.isProtectedTree(path))
    }

    @Test("사용자 파일은 트리 보호 대상이 아니다")
    func userFilesAreNotTreeProtected() {
        #expect(!FileSafety.isProtectedTree(home + "/Downloads/big.zip"))
        #expect(!FileSafety.isProtectedTree(home + "/Projects/app/build"))
    }

    /// 트리 보호는 접두사 단순 비교가 아니라 경로 경계를 지켜야 한다.
    @Test("트리 보호는 경로 경계를 지킨다")
    func treeProtectionRespectsPathBoundaries() {
        #expect(!FileSafety.isProtectedTree(home + "/usrdata/file.txt"))
        #expect(!FileSafety.isProtectedTree(home + "/systemic/file.txt"))
    }

    // MARK: - 잔여물 삭제 허용 규칙

    @Test("허용된 /Library 하위 잔여물은 삭제 가능", arguments: [
        "/Library/Application Support/SomeApp",
        "/Library/Caches/com.vendor.app",
        "/Library/Logs/SomeApp.log",
        "/Library/Preferences/com.vendor.app.plist",
        "/Library/LaunchAgents/com.vendor.app.plist",
        "/Library/LaunchDaemons/com.vendor.app.plist",
        "/Library/Containers/com.vendor.app",
        "/Library/PrivilegedHelperTools/com.vendor.helper"
    ])
    func librarySubtreeLeftoversAreDeletable(path: String) {
        #expect(FileSafety.isDeletableLeftover(path))
    }

    /// 허용 트리의 루트 자체는 절대 삭제 대상이 되면 안 된다.
    @Test("허용 트리의 루트 자체는 삭제 불가", arguments: [
        "/Library/Application Support", "/Library/Caches", "/Library/LaunchDaemons",
        "/Library/Preferences", "/Library/Containers"
    ])
    func librarySubtreeRootsAreNotDeletable(path: String) {
        #expect(!FileSafety.isDeletableLeftover(path))
    }

    @Test("허용목록 밖 /Library 하위는 삭제 불가", arguments: [
        "/Library/Extensions/driver.kext",
        "/Library/Keychains/System.keychain",
        "/Library/Frameworks/Some.framework",
        "/Library/Security/x"
    ])
    func nonWhitelistedLibrarySubtreesAreNotDeletable(path: String) {
        #expect(!FileSafety.isDeletableLeftover(path))
    }

    @Test("시스템 경로는 잔여물로도 삭제 불가", arguments: [
        "/", "/System", "/System/Library/CoreServices", "/usr/bin/env", "/bin/sh", "/etc"
    ])
    func systemPathsAreNeverDeletableLeftovers(path: String) {
        #expect(!FileSafety.isDeletableLeftover(path))
    }

    @Test("사용자 라이브러리 잔여물은 삭제 가능하되 라이브러리 루트는 불가")
    func userLibraryLeftoversAreDeletable() {
        #expect(FileSafety.isDeletableLeftover(home + "/Library/Caches/com.vendor.app"))
        #expect(FileSafety.isDeletableLeftover(home + "/Library/Application Support/SomeApp"))
        #expect(!FileSafety.isDeletableLeftover(home + "/Library"))
    }

    // MARK: - 셸 / AppleScript 이스케이프

    @Test("셸 인용은 작은따옴표를 무력화한다")
    func shellQuotingNeutralizesSingleQuotes() {
        #expect(FileSafety.shellQuotedForTesting("/tmp/it's a file") == "'/tmp/it'\\''s a file'")
    }

    @Test("AppleScript 리터럴은 큰따옴표와 백슬래시를 모두 이스케이프한다")
    func appleScriptLiteralEscapesQuotesAndBackslashes() {
        #expect(FileSafety.appleScriptLiteralForTesting(#"rm -rf '/tmp/a"b\c'"#) == #""rm -rf '/tmp/a\"b\\c'""#)
    }

    /// 백슬래시를 나중에 치환하면 `\"` 가 깨진다. 치환 순서 회귀 방지.
    @Test("백슬래시가 큰따옴표보다 먼저 이스케이프된다")
    func appleScriptLiteralEscapesBackslashFirst() {
        #expect(FileSafety.appleScriptLiteralForTesting(#"a\b"#) == #""a\\b""#)
        #expect(FileSafety.appleScriptLiteralForTesting(#"a"b"#) == #""a\"b""#)
    }

    /// 인젝션 시나리오: 파일명에 `"` 가 들어가도 AppleScript 문자열을 탈출할 수 없어야 한다.
    @Test("악성 파일명이 AppleScript 문자열을 탈출하지 못한다")
    func maliciousFileNameCannotEscapeAppleScriptString() {
        let evil = #"/tmp/x"; do shell script "rm -rf /"; --"#
        let command = "rm -rf " + FileSafety.shellQuotedForTesting(evil)
        let literal = FileSafety.appleScriptLiteralForTesting(command)

        let inner = Array(literal.dropFirst().dropLast())
        for (index, ch) in inner.enumerated() where ch == "\"" {
            #expect(index > 0 && inner[index - 1] == "\\", "이스케이프되지 않은 큰따옴표가 남아 있다")
        }
    }

    @Test("제어 문자가 포함된 경로는 거부된다")
    func controlCharacterPathsAreRejected() {
        #expect(!FileSafety.isShellSafePathForTesting("/tmp/a\nb"))
        #expect(!FileSafety.isShellSafePathForTesting("/tmp/a\u{0}b"))
        #expect(!FileSafety.isShellSafePathForTesting(""))
        #expect(FileSafety.isShellSafePathForTesting("/tmp/normal file.txt"))
    }

    // MARK: - 실제 삭제 동작

    @Test("보호 경로는 휴지통 이동도 거부한다")
    func moveToTrashRefusesProtectedPath() {
        #expect(!FileSafety.moveToTrash(URL(fileURLWithPath: "/System"), treeProtection: true))
        #expect(!FileSafety.moveToTrash(URL(fileURLWithPath: "/")))
    }

    @Test("일괄 삭제는 보호 경로와 없는 파일을 건너뛴다")
    func deleteBatchIgnoresProtectedAndMissingItems() {
        let result = FileSafety.deleteBatch(items: [
            (url: URL(fileURLWithPath: "/System"), size: 100),
            (url: URL(fileURLWithPath: "/Library/Extensions"), size: 100),
            (url: URL(fileURLWithPath: "/tmp/definitely-missing-\(UUID().uuidString)"), size: 100)
        ])
        #expect(result.isSuccess)
        #expect(result.cleanedSize == 0)
    }

    @Test("임시 파일은 실제로 휴지통으로 이동된다")
    func moveToTrashRemovesTemporaryFile() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("trash-test-\(UUID().uuidString).txt")
        try Data("temp".utf8).write(to: url)

        #expect(FileSafety.moveToTrash(url))
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    // MARK: - 해시

    @Test("작은 파일도 전체/부분 해시를 산출한다")
    func hashesAreProducedForSmallFiles() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("hash-test-\(UUID().uuidString).bin")
        try Data("hello mac optimization tool".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(FileSafety.fullFileHash(for: url)?.count == 64)
        #expect(FileSafety.partialFileHash(for: url)?.count == 64)
    }

    @Test("내용이 다르면 해시도 다르다")
    func hashOfDifferentContentDiffers() throws {
        let dir = FileManager.default.temporaryDirectory
        let a = dir.appendingPathComponent("hash-a-\(UUID().uuidString).bin")
        let b = dir.appendingPathComponent("hash-b-\(UUID().uuidString).bin")
        try Data(repeating: 0x41, count: 40_000).write(to: a)
        try Data(repeating: 0x42, count: 40_000).write(to: b)
        defer {
            try? FileManager.default.removeItem(at: a)
            try? FileManager.default.removeItem(at: b)
        }

        #expect(FileSafety.fullFileHash(for: a) != FileSafety.fullFileHash(for: b))
        #expect(FileSafety.partialFileHash(for: a) != FileSafety.partialFileHash(for: b))
    }

    @Test("빈 파일과 없는 파일의 해시는 nil")
    func hashOfEmptyOrMissingFileIsNil() throws {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-\(UUID().uuidString).bin")
        #expect(FileSafety.fullFileHash(for: missing) == nil)

        let empty = FileManager.default.temporaryDirectory
            .appendingPathComponent("empty-\(UUID().uuidString).bin")
        try Data().write(to: empty)
        defer { try? FileManager.default.removeItem(at: empty) }
        #expect(FileSafety.fullFileHash(for: empty) == nil)
    }
}
