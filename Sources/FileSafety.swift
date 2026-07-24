import Foundation
import CryptoKit

/// 파일 삭제/해시 관련 보안 로직 단일 소스.
/// 각 ViewModel 에 흩어져 있던 블랙리스트/삭제 코드를 통합하여 규칙 불일치를 제거한다.
enum FileSafety {

    // MARK: - Protected paths

    /// 절대 삭제해서는 안 되는 정확 경로 집합 (시스템 루트 + 사용자 홈 최상위).
    /// 캐시 하위 항목 삭제는 허용해야 하므로 prefix 가 아닌 정확 일치로 검사한다.
    private static let exactProtectedRoots: Set<String> = {
        var roots: Set<String> = [
            "/", "/system", "/library", "/applications", "/users",
            "/private", "/var", "/etc", "/bin", "/sbin", "/usr", "/dev", "/volumes",
            "/cores", "/opt", "/tmp"
        ]
        let home = FileManager.default.homeDirectoryForCurrentUser.standardized.path.lowercased()
        roots.insert(home)
        for sub in ["library", "desktop", "documents", "downloads", "applications",
                    "movies", "music", "pictures", "public", "icloud drive"] {
            roots.insert(home + "/" + sub)
        }
        return roots
    }()

    /// 사용자 지정 폴더 스캔 시(대용량/중복) 아예 진입/삭제하면 안 되는 시스템 트리.
    private static let prefixProtectedTrees: [String] = [
        "/system", "/library", "/bin", "/sbin", "/usr", "/private", "/cores",
        "/etc", "/var", "/dev", "/volumes/", "/users/shared/library"
    ]

    /// 심볼릭 링크까지 해석한 표준화 경로. `standardizingPath` 는 심링크를 풀지 않으므로 보강.
    private static func canonical(_ path: String) -> String {
        let resolved = (path as NSString).resolvingSymlinksInPath
        return (resolved as NSString).standardizingPath.lowercased()
    }

    /// 정확 일치 보호 경로 여부 (캐시 정리/언인스톨러/중복 컨텍스트).
    static func isProtectedExact(_ path: String) -> Bool {
        exactProtectedRoots.contains(canonical(path))
    }

    /// 보호 트리 하위 여부 (사용자 폴더 스캔 컨텍스트).
    static func isProtectedTree(_ path: String) -> Bool {
        let clean = canonical(path)
        if exactProtectedRoots.contains(clean) { return true }
        return prefixProtectedTrees.contains { clean == $0 || clean.hasPrefix($0.hasSuffix("/") ? $0 : $0 + "/") }
    }

    // MARK: - Deletion

    /// 안전 삭제: 영구 삭제 대신 휴지통 이동. 보호 경로면 차단하고 false 반환.
    /// - Returns: 실제로 휴지통으로 이동했으면 true.
    @discardableResult
    static func moveToTrash(_ url: URL, treeProtection: Bool = false) -> Bool {
        let path = url.standardized.path
        let blocked = treeProtection ? isProtectedTree(path) : isProtectedExact(path)
        if blocked {
            print("보안 경고: 보호 경로 삭제 차단: \(path)")
            return false
        }
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            return true
        } catch {
            print("휴지통 이동 실패: \(url.path), 에러: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Hashing

    /// 파일 전체를 스트리밍 SHA-256 해시. 부분 해시 충돌로 인한 오탐 삭제를 방지한다.
    /// 큰 파일도 64KB 청크로 읽어 메모리 사용을 억제.
    static func fullFileHash(for url: URL) -> String? {
        guard let file = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? file.close() }

        var hasher = SHA256()
        let chunkSize = 65_536
        while true {
            let data = file.readData(ofLength: chunkSize)
            if data.isEmpty { break }
            hasher.update(data: data)
        }
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
