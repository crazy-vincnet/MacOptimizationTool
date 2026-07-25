import Foundation
import CryptoKit

/// 인앱 업데이터의 순수 검증 로직.
/// UI·네트워크와 분리해 두어 단위 테스트로 회귀를 막는다.
public enum UpdateVerification {

    /// 업데이트 자산을 내려받도록 허용된 호스트.
    public static let allowedDownloadHosts: Set<String> = [
        "github.com",
        "objects.githubusercontent.com",
        "release-assets.githubusercontent.com",
        "api.github.com"
    ]

    /// 선행 `v` 접두사만 제거한다.
    /// `replacingOccurrences(of: "v")` 는 `1.0.0-dev` 를 `1.0.0-de` 로 망가뜨린다.
    public static func normalizedVersion(_ raw: String) -> String {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("v") || trimmed.hasPrefix("V") {
            trimmed.removeFirst()
        }
        return trimmed
    }

    /// `latest` 가 `current` 보다 높은 버전인지 여부. 숫자 구간 단위로 비교한다.
    public static func isNewerVersion(latest: String, current: String) -> Bool {
        let l = normalizedVersion(latest)
        let c = normalizedVersion(current)
        return (l as NSString).compare(c, options: .numeric) == .orderedDescending
    }

    /// HTTPS + 허용 호스트 검증.
    public static func isTrustedDownloadURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https", let host = url.host?.lowercased() else { return false }
        return allowedDownloadHosts.contains(host)
    }

    /// GitHub Release API 의 `digest` 필드(`sha256:<hex>`)에서 해시만 추출한다.
    public static func parseSHA256Digest(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let lowered = raw.lowercased()
        guard lowered.hasPrefix("sha256:") else { return nil }
        let hex = String(lowered.dropFirst("sha256:".count))
        guard hex.count == 64, hex.allSatisfy({ $0.isHexDigit }) else { return nil }
        return hex
    }

    /// 파일 전체 SHA-256 (스트리밍).
    public static func sha256Hex(of url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        var hasher = SHA256()
        while true {
            let chunk = handle.readData(ofLength: 1_048_576)
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// 다이제스트가 존재하고 실제 해시와 일치할 때만 true.
    public static func matchesDigest(actual: String?, expected: String?) -> Bool {
        guard let actual, let expected else { return false }
        return actual.lowercased() == expected.lowercased()
    }
}
