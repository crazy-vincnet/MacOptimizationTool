import Foundation
import CryptoKit
import AppKit

/// 파일 삭제/해시 관련 보안 로직 단일 소스.
/// 각 ViewModel 에 흩어져 있던 블랙리스트/삭제 코드를 통합하여 규칙 불일치를 제거한다.
enum FileSafety {

    // MARK: - Protected paths

    /// 절대 삭제해서는 안 되는 정확 경로 집합 (시스템 루트 + 사용자 홈 최상위).
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

    /// 심볼릭 링크까지 해석한 표준화 경로.
    private static func canonical(_ path: String) -> String {
        let resolved = (path as NSString).resolvingSymlinksInPath
        return (resolved as NSString).standardizingPath.lowercased()
    }

    /// 정확 일치 보호 경로 여부.
    static func isProtectedExact(_ path: String) -> Bool {
        exactProtectedRoots.contains(canonical(path))
    }

    /// 보호 트리 하위 여부.
    static func isProtectedTree(_ path: String) -> Bool {
        let clean = canonical(path)
        if exactProtectedRoots.contains(clean) { return true }
        return prefixProtectedTrees.contains { clean == $0 || clean.hasPrefix($0.hasSuffix("/") ? $0 : $0 + "/") }
    }

    // MARK: - Deletion

    /// 언인스톨러 / 일괄 삭제 보안 엔진.
    /// 삭제 대상 중 관리자 권한(/Library, Root 소유 등)이 필요한 항목이 존재하는 경우,
    /// 사전 암호 인증을 실시합니다. 사용자가 비밀번호를 틀리거나 [취소]하면
    /// 메인 앱 번들(.app) 포함 어떤 파일도 지우지 않고 작업을 전면 안전 취소(Abort)합니다.
    static func deleteBatch(items: [(url: URL, size: Int64)]) -> (cleanedSize: Int64, isSuccess: Bool) {
        let fm = FileManager.default
        let validItems = items.filter { item in
            let path = item.url.standardized.path
            guard !isProtectedExact(path) && fm.fileExists(atPath: item.url.path) else { return false }
            return true
        }

        guard !validItems.isEmpty else { return (0, true) }

        // 관리자 권한이 필요한 항목 사전 검사 (/Library 하위 또는 소유권 미확보 파일)
        let adminRequiredItems = validItems.filter { item in
            let p = item.url.path.lowercased()
            return p.hasPrefix("/library") || !fm.isWritableFile(atPath: item.url.path)
        }

        // 관리자 권한 필요 항목이 포함되어 있다면 삭제 전 사전 승인 실행
        if !adminRequiredItems.isEmpty {
            let escapedPaths = adminRequiredItems.map { "'\($0.url.path.replacingOccurrences(of: "'", with: "'\\''"))'" }.joined(separator: " ")
            let script = "do shell script \"rm -rf \(escapedPaths)\" with administrator privileges"
            var errorDict: NSDictionary?
            if let scriptObject = NSAppleScript(source: script) {
                scriptObject.executeAndReturnError(&errorDict)
                if errorDict != nil {
                    // 관리자 암호 오류 또는 사용자가 취소함 -> 전면 안전 중단 (앱 및 어떤 파일도 지우지 않음)
                    print("보안 인증 실패/취소: 비밀번호 불일치로 전체 앱 삭제 프로세스가 안전하게 취소되었습니다.")
                    return (0, false)
                }
            }
        }

        // 일반 항목 및 잔여 항목 휴지통 수거
        var totalCleaned: Int64 = 0
        for item in validItems {
            if fm.fileExists(atPath: item.url.path) {
                if moveToTrash(item.url) {
                    totalCleaned += item.size
                }
            } else {
                totalCleaned += item.size
            }
        }

        return (totalCleaned, true)
    }

    /// 단일 파일 휴지통 이동.
    @discardableResult
    static func moveToTrash(_ url: URL, treeProtection: Bool = false) -> Bool {
        let path = url.standardized.path
        let blocked = treeProtection ? isProtectedTree(path) : isProtectedExact(path)
        if blocked {
            print("보안 경고: 보호 경로 삭제 차단: \(path)")
            return false
        }
        guard FileManager.default.fileExists(atPath: url.path) else { return false }

        // 1차 시도: 표준 FileManager 휴지통 이동
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            return true
        } catch {
            print("1차 휴지통 이동 실패 (\(url.path)): \(error.localizedDescription)")
        }

        // 2차 시도: NSWorkspace.shared.recycle
        var recycleSuccess = false
        let semaphore = DispatchSemaphore(value: 0)
        NSWorkspace.shared.recycle([url]) { _, error in
            if error == nil {
                recycleSuccess = true
            }
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 2.0)
        if recycleSuccess { return true }

        // 3차 시도: FileManager.default.removeItem
        do {
            try FileManager.default.removeItem(at: url)
            return true
        } catch {
            print("3차 direct removeItem 실패 (\(url.path)): \(error.localizedDescription)")
        }

        // 4차 시도: AppleScript 관리자 권한
        let escapedPath = url.path.replacingOccurrences(of: "'", with: "'\\''")
        let script = "do shell script \"rm -rf '\(escapedPath)'\" with administrator privileges"
        var errorDict: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&errorDict)
            if errorDict == nil && !FileManager.default.fileExists(atPath: url.path) {
                return true
            }
        }

        return false
    }

    // MARK: - Hashing

    static func partialFileHash(for url: URL) -> String? {
        guard let file = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? file.close() }

        var hasher = SHA256()
        let headData = file.readData(ofLength: 16_384)
        hasher.update(data: headData)

        let fileSize = (try? file.seekToEnd()) ?? 0
        if fileSize > 32_768 {
            try? file.seek(toOffset: fileSize - 16_384)
            let tailData = file.readData(ofLength: 16_384)
            hasher.update(data: tailData)
        }

        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

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
