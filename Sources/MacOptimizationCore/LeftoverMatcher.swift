import Foundation

/// 앱 완전 삭제기의 잔여 파일 매칭 규칙.
///
/// 이 판정이 오탐을 내면 무관한 파일이 삭제 후보에 오르고, `/Library` 하위인 경우
/// 관리자 권한 영구 삭제까지 이어질 수 있다. 규칙을 단독 모듈로 분리해 테스트로 고정한다.
public enum LeftoverMatcher {

    /// 이 이름들은 너무 흔해서 부분 일치를 허용하지 않는다.
    static let genericNames: Set<String> = [
        "app", "link", "tool", "clean", "cleaner", "helper", "system",
        "manager", "admin", "free", "utility", "test", "demo"
    ]

    static let delimiters: [Character] = [".", "-", "_", " "]

    public static func matches(fileName: String, appName: String, bundleID: String?) -> Bool {
        let lowerName = fileName.lowercased()
        let lowerAppName = appName.lowercased()

        if lowerName == lowerAppName { return true }

        if let bid = bundleID?.lowercased(), !bid.isEmpty {
            if lowerName == bid { return true }
            if lowerName.contains(bid) { return true }
            if bid.contains(lowerName) && lowerName.count > 10 { return true }
        }

        if lowerName.hasSuffix(".plist") {
            let nameWithoutPlist = String(lowerName.dropLast(".plist".count))
            if nameWithoutPlist == lowerAppName { return true }
            if let bid = bundleID?.lowercased(), nameWithoutPlist == bid { return true }
        }

        // 짧거나 지나치게 일반적인 앱 이름은 여기서 중단한다. 토큰 일치까지 허용하면 오탐이 커진다.
        let isShortOrGeneric = lowerAppName.count < 4 || genericNames.contains(lowerAppName)
        if isShortOrGeneric { return false }

        for delim in delimiters where lowerName.hasPrefix(lowerAppName + String(delim)) {
            return true
        }

        let tokens = lowerName.split(whereSeparator: { delimiters.contains($0) })
        return tokens.contains { String($0) == lowerAppName }
    }
}
