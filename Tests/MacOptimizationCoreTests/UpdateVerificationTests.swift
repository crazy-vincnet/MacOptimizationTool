import Foundation
import Testing
@testable import MacOptimizationCore

/// 업데이터 검증 로직 테스트.
/// 이 규칙이 무너지면 임의 서버의 임의 DMG 가 자동 마운트될 수 있다.
@Suite("UpdateVerification 업데이트 검증")
struct UpdateVerificationTests {

    // MARK: - 버전 정규화

    @Test("선행 v 만 제거한다")
    func stripsOnlyLeadingV() {
        #expect(UpdateVerification.normalizedVersion("v1.5.0") == "1.5.0")
        #expect(UpdateVerification.normalizedVersion("V1.5.0") == "1.5.0")
        #expect(UpdateVerification.normalizedVersion("1.5.0") == "1.5.0")
        #expect(UpdateVerification.normalizedVersion("  v1.5.0\n") == "1.5.0")
    }

    /// 회귀 방지: `replacingOccurrences(of: "v")` 로 되돌아가면 여기서 깨진다.
    @Test("문자열 중간의 v 는 제거하지 않는다")
    func doesNotStripInnerV() {
        #expect(UpdateVerification.normalizedVersion("1.0.0-dev") == "1.0.0-dev")
        #expect(UpdateVerification.normalizedVersion("v1.0.0-preview") == "1.0.0-preview")
    }

    // MARK: - 버전 비교

    @Test("숫자 구간 단위로 버전을 비교한다")
    func numericVersionComparison() {
        #expect(UpdateVerification.isNewerVersion(latest: "v1.6.0", current: "1.5.0"))
        #expect(UpdateVerification.isNewerVersion(latest: "1.10.0", current: "1.9.0"))
        #expect(UpdateVerification.isNewerVersion(latest: "2.0.0", current: "1.99.0"))
        #expect(!UpdateVerification.isNewerVersion(latest: "1.5.0", current: "1.5.0"))
        #expect(!UpdateVerification.isNewerVersion(latest: "1.4.9", current: "1.5.0"))
    }

    // MARK: - 다운로드 URL 신뢰성

    @Test("HTTPS 허용 호스트는 신뢰한다", arguments: [
        "github.com", "objects.githubusercontent.com", "release-assets.githubusercontent.com"
    ])
    func trustedHostsOverHTTPS(host: String) {
        #expect(UpdateVerification.isTrustedDownloadURL(URL(string: "https://\(host)/x/y.dmg")!))
    }

    @Test("HTTP 는 거부한다")
    func httpIsRejected() {
        #expect(!UpdateVerification.isTrustedDownloadURL(URL(string: "http://github.com/x.dmg")!))
    }

    @Test("허용목록 밖 호스트는 거부한다", arguments: [
        "https://evil.com/x.dmg",
        "https://github.com.evil.com/x.dmg",
        "https://notgithub.com/x.dmg",
        "file:///tmp/x.dmg"
    ])
    func unknownHostsAreRejected(raw: String) {
        #expect(!UpdateVerification.isTrustedDownloadURL(URL(string: raw)!))
    }

    @Test("호스트 비교는 대소문자를 구분하지 않는다")
    func hostComparisonIsCaseInsensitive() {
        #expect(UpdateVerification.isTrustedDownloadURL(URL(string: "HTTPS://GitHub.com/x.dmg")!))
    }

    // MARK: - 다이제스트 파싱 / 대조

    @Test("정상 다이제스트를 파싱한다")
    func parsesValidDigest() {
        let hex = String(repeating: "a", count: 64)
        #expect(UpdateVerification.parseSHA256Digest("sha256:\(hex)") == hex)
        #expect(UpdateVerification.parseSHA256Digest("SHA256:\(hex.uppercased())") == hex)
    }

    @Test("형식이 잘못된 다이제스트는 거부한다")
    func rejectsMalformedDigest() {
        #expect(UpdateVerification.parseSHA256Digest(nil) == nil)
        #expect(UpdateVerification.parseSHA256Digest("") == nil)
        #expect(UpdateVerification.parseSHA256Digest("md5:\(String(repeating: "a", count: 32))") == nil)
        #expect(UpdateVerification.parseSHA256Digest("sha256:tooshort") == nil)
        #expect(UpdateVerification.parseSHA256Digest("sha256:\(String(repeating: "z", count: 64))") == nil)
    }

    @Test("다이제스트 대조는 양쪽 값이 모두 있어야 성공한다")
    func digestMatchRequiresBothValues() {
        let hex = String(repeating: "b", count: 64)
        #expect(UpdateVerification.matchesDigest(actual: hex, expected: hex.uppercased()))
        #expect(!UpdateVerification.matchesDigest(actual: hex, expected: nil))
        #expect(!UpdateVerification.matchesDigest(actual: nil, expected: hex))
        #expect(!UpdateVerification.matchesDigest(actual: nil, expected: nil))
        #expect(!UpdateVerification.matchesDigest(actual: hex, expected: String(repeating: "c", count: 64)))
    }

    // MARK: - 파일 해시

    @Test("알려진 내용의 SHA-256 이 일치한다")
    func sha256OfKnownContent() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("sha-\(UUID().uuidString).bin")
        try Data("abc".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(UpdateVerification.sha256Hex(of: url)
                == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    @Test("없는 파일의 해시는 nil")
    func sha256OfMissingFileIsNil() {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-\(UUID().uuidString).bin")
        #expect(UpdateVerification.sha256Hex(of: missing) == nil)
    }
}
