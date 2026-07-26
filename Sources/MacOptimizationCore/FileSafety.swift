import Foundation
import CryptoKit
import AppKit

/// 파일 삭제/해시 관련 보안 로직 단일 소스.
/// 각 ViewModel 에 흩어져 있던 블랙리스트/삭제 코드를 통합하여 규칙 불일치를 제거한다.
public enum FileSafety {

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

    /// `/Library` 는 통째로 보호 트리이지만, 앱 완전 삭제 시 반드시 지워야 하는 잔여물이
    /// 존재하는 하위 트리만 예외적으로 삭제를 허용한다.
    /// 각 항목의 "직접 하위"만 허용되며, 디렉터리 자기 자신은 절대 대상이 되지 않는다.
    private static let elevatableLibrarySubtrees: [String] = [
        "/library/application support/",
        "/library/caches/",
        "/library/logs/",
        "/library/preferences/",
        "/library/launchagents/",
        "/library/launchdaemons/",
        "/library/privilegedhelpertools/",
        "/library/containers/",
        "/library/saved application state/",
        "/library/internet plug-ins/"
    ]

    /// 심볼릭 링크까지 해석한 표준화 경로.
    private static func canonical(_ path: String) -> String {
        let resolved = (path as NSString).resolvingSymlinksInPath
        return (resolved as NSString).standardizingPath.lowercased()
    }

    /// 정확 일치 보호 경로 여부.
    public static func isProtectedExact(_ path: String) -> Bool {
        exactProtectedRoots.contains(canonical(path))
    }

    /// 보호 트리 하위 여부.
    public static func isProtectedTree(_ path: String) -> Bool {
        let clean = canonical(path)
        if exactProtectedRoots.contains(clean) { return true }
        return prefixProtectedTrees.contains { clean == $0 || clean.hasPrefix($0.hasSuffix("/") ? $0 : $0 + "/") }
    }

    /// `/Library` 예외 허용 트리의 "하위" 항목 여부. 트리 루트 자기 자신은 false.
    private static func isElevatableLibraryLeftover(_ canonicalPath: String) -> Bool {
        elevatableLibrarySubtrees.contains {
            canonicalPath.hasPrefix($0) && canonicalPath.count > $0.count
        }
    }

    /// 앱 완전 삭제기의 잔여물 삭제 허용 여부.
    /// 보호 트리를 기본 차단하되, 잔여물이 실제로 존재하는 `/Library` 하위 트리만 예외 허용한다.
    public static func isDeletableLeftover(_ path: String) -> Bool {
        let clean = canonical(path)
        if exactProtectedRoots.contains(clean) { return false }
        if isElevatableLibraryLeftover(clean) { return true }
        return !isProtectedTree(clean)
    }

    // MARK: - Shell / AppleScript escaping

    /// 제어 문자가 포함된 경로는 어떤 이스케이프로도 안전을 보장할 수 없으므로 아예 거부한다.
    private static func isShellSafePath(_ path: String) -> Bool {
        !path.isEmpty && !path.unicodeScalars.contains { $0.value < 0x20 || $0.value == 0x7F }
    }

    /// 경로를 POSIX 셸 단어 하나로 안전하게 감싼다.
    private static func shellQuoted(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// `do shell script "..."` 는 AppleScript 문자열 파싱 → 셸 파싱의 2단계를 거친다.
    /// 셸 레이어만 이스케이프하면 경로에 포함된 `"` 나 `\` 로 AppleScript 문자열을 탈출해
    /// 관리자 권한 임의 명령 실행이 가능해지므로, 두 레이어를 모두 이스케이프한다.
    /// 백슬래시를 반드시 먼저 치환해야 한다.
    private static func appleScriptStringLiteral(_ shellCommand: String) -> String {
        let escaped = shellCommand
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"" + escaped + "\""
    }

    /// 관리자 권한으로 셸 명령 실행. 성공 시 true.
    private static func runElevated(shellCommand: String) -> Bool {
        let script = "do shell script \(appleScriptStringLiteral(shellCommand)) with administrator privileges"
        var errorDict: NSDictionary?
        guard let scriptObject = NSAppleScript(source: script) else { return false }
        scriptObject.executeAndReturnError(&errorDict)
        return errorDict == nil
    }

    // MARK: - Deletion

    /// 언인스톨러 / 일괄 삭제 보안 엔진.
    /// 삭제 대상 중 관리자 권한(/Library, Root 소유 등)이 필요한 항목이 존재하는 경우,
    /// 사전 암호 인증을 실시합니다. 사용자가 비밀번호를 틀리거나 [취소]하면
    /// 메인 앱 번들(.app) 포함 어떤 파일도 지우지 않고 작업을 전면 안전 취소(Abort)합니다.
    public static func deleteBatch(items: [(url: URL, size: Int64)]) -> (cleanedSize: Int64, isSuccess: Bool) {
        let fm = FileManager.default
        let validItems = items.filter { item in
            let path = item.url.standardized.path
            // 보호 트리 전체를 차단하고, 잔여물이 실존하는 /Library 하위 트리만 예외 허용한다.
            guard isDeletableLeftover(path), isShellSafePath(item.url.path),
                  fm.fileExists(atPath: item.url.path) else { return false }
            return true
        }

        guard !validItems.isEmpty else { return (0, true) }

        // 관리자 권한이 필요한 항목 사전 검사 (/Library 하위 또는 소유권 미확보 파일)
        let adminRequiredItems = validItems.filter { item in
            let clean = canonical(item.url.path)
            return isElevatableLibraryLeftover(clean) || !fm.isWritableFile(atPath: item.url.path)
        }

        // 관리자 권한 필요 항목이 포함되어 있다면 삭제 전 사전 승인 실행.
        // 이 경로는 root 소유 파일이라 휴지통 이동이 불가능하며 영구 삭제된다.
        if !adminRequiredItems.isEmpty {
            let escapedPaths = adminRequiredItems.map { shellQuoted($0.url.path) }.joined(separator: " ")
            if !runElevated(shellCommand: "rm -rf \(escapedPaths)") {
                // 관리자 암호 오류 또는 사용자가 취소함 -> 전면 안전 중단 (앱 및 어떤 파일도 지우지 않음)
                print("보안 인증 실패/취소: 비밀번호 불일치로 전체 앱 삭제 프로세스가 안전하게 취소되었습니다.")
                return (0, false)
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
    ///
    /// - Important: 관리자 권한 프롬프트와 `NSWorkspace.recycle` 대기가 포함되므로
    ///   메인 스레드에서 직접 호출하면 UI가 멈춘다. `@MainActor` 컨텍스트에서는
    ///   `moveToTrashAsync(_:treeProtection:)` 를 사용할 것.
    @discardableResult
    public static func moveToTrash(_ url: URL, treeProtection: Bool = false) -> Bool {
        let path = url.standardized.path
        let blocked = treeProtection ? isProtectedTree(path) : isProtectedExact(path)
        if blocked {
            print("보안 경고: 보호 경로 삭제 차단: \(path)")
            return false
        }
        guard FileManager.default.fileExists(atPath: url.path) else { return false }

        // 이미 휴지통 안에 있는 항목은 다시 휴지통으로 옮겨도 공간이 회수되지 않는다.
        // 실제로 디스크를 비우려면 영구 삭제해야 한다.
        if isInsideTrash(path) {
            return permanentlyDelete(url)
        }

        // 1차 시도: 표준 FileManager 휴지통 이동
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            return true
        } catch {
            print("1차 휴지통 이동 실패 (\(url.path)): \(error.localizedDescription)")
        }

        // 2차 시도: NSWorkspace.shared.recycle
        // 완료 핸들러가 메인 런루프로 디스패치되므로, 메인 스레드에서 세마포어를 기다리면
        // 데드락이 된다. 백그라운드에서 호출된 경우에만 시도한다.
        if !Thread.isMainThread {
            let outcome = CompletionFlag()
            let semaphore = DispatchSemaphore(value: 0)
            NSWorkspace.shared.recycle([url]) { _, error in
                outcome.set(error == nil)
                semaphore.signal()
            }
            _ = semaphore.wait(timeout: .now() + 2.0)
            if outcome.value { return true }
        }

        // 3차 시도: FileManager.default.removeItem
        do {
            try FileManager.default.removeItem(at: url)
            return true
        } catch {
            print("3차 direct removeItem 실패 (\(url.path)): \(error.localizedDescription)")
        }

        // 4차 시도: AppleScript 관리자 권한 (셸 + AppleScript 이중 이스케이프)
        guard isShellSafePath(url.path) else {
            print("보안 경고: 제어 문자가 포함된 경로는 관리자 권한 삭제를 거부합니다: \(url.path)")
            return false
        }
        if runElevated(shellCommand: "rm -rf \(shellQuoted(url.path))") {
            return !FileManager.default.fileExists(atPath: url.path)
        }

        return false
    }

    /// 메인 액터에서 안전하게 호출할 수 있는 비동기 삭제 래퍼.
    @discardableResult
    public static func moveToTrashAsync(_ url: URL, treeProtection: Bool = false) async -> Bool {
        await Task.detached(priority: .userInitiated) {
            moveToTrash(url, treeProtection: treeProtection)
        }.value
    }

    /// 휴지통 내부 경로 여부.
    private static func isInsideTrash(_ path: String) -> Bool {
        let clean = canonical(path)
        let home = FileManager.default.homeDirectoryForCurrentUser.standardized.path.lowercased()
        return clean.hasPrefix(home + "/.trash/")
    }

    /// 휴지통을 거치지 않는 영구 삭제. 필요 시 관리자 권한으로 승격한다.
    private static func permanentlyDelete(_ url: URL) -> Bool {
        do {
            try FileManager.default.removeItem(at: url)
            return true
        } catch {
            print("영구 삭제 실패 (\(url.path)): \(error.localizedDescription)")
        }

        guard isShellSafePath(url.path) else { return false }
        if runElevated(shellCommand: "rm -rf \(shellQuoted(url.path))") {
            return !FileManager.default.fileExists(atPath: url.path)
        }
        return false
    }

    // MARK: - Hashing

    public static func partialFileHash(for url: URL) -> String? {
        guard let vals = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
              vals.isRegularFile == true,
              let fileSize = vals.fileSize, fileSize > 0 else { return nil }

        guard let file = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? file.close() }

        var hasher = SHA256()
        let headData = file.readData(ofLength: 8_192)
        hasher.update(data: headData)

        if fileSize > 16_384 {
            try? file.seek(toOffset: UInt64(fileSize - 8_192))
            let tailData = file.readData(ofLength: 8_192)
            hasher.update(data: tailData)
        }

        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// 앞·중간·뒤 8KB 를 읽어 만드는 샘플 해시.
    ///
    /// `partialFileHash` 는 앞뒤만 본다. 같은 헤더/푸터를 쓰는 형식(동일 카메라의 RAW,
    /// 같은 툴로 만든 zip, 컨테이너 동영상)에서는 앞뒤가 일치하는 경우가 흔해
    /// 전체 해시 대상이 불필요하게 늘어난다. 중간 청크를 하나 더 보면 그 후보가 크게 줄고,
    /// 읽는 양은 24KB 로 여전히 고정이다.
    public static func sampledFileHash(for url: URL) -> String? {
        guard let vals = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
              vals.isRegularFile == true,
              let fileSize = vals.fileSize, fileSize > 0 else { return nil }

        guard let file = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? file.close() }

        let chunk = 8_192
        var hasher = SHA256()
        // 크기를 해시에 포함해, 크기가 다른 파일이 같은 샘플을 가질 때 충돌하지 않게 한다.
        hasher.update(data: withUnsafeBytes(of: Int64(fileSize).littleEndian) { Data($0) })
        hasher.update(data: file.readData(ofLength: chunk))

        if fileSize > chunk * 3 {
            let middleOffset = UInt64(fileSize / 2 - Int(chunk / 2))
            try? file.seek(toOffset: middleOffset)
            hasher.update(data: file.readData(ofLength: chunk))
        }

        if fileSize > chunk * 2 {
            try? file.seek(toOffset: UInt64(fileSize - chunk))
            hasher.update(data: file.readData(ofLength: chunk))
        }

        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    public static func fullFileHash(for url: URL) -> String? {
        guard let vals = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
              vals.isRegularFile == true,
              let fileSize = vals.fileSize, fileSize > 0 else { return nil }

        // 2GB 초과 거대 파일은 16KB 고속 부분 해시로 대체하여 시스템 IO 블로킹 원천 차단
        if fileSize > 2_000_000_000 {
            return partialFileHash(for: url)
        }

        guard let file = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? file.close() }

        var hasher = SHA256()
        let chunkSize = 524_288
        while true {
            let data = file.readData(ofLength: chunkSize)
            if data.isEmpty { break }
            hasher.update(data: data)
        }
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }


}

// MARK: - Testing hooks

/// 이스케이프·안전성 판정은 보안상 핵심이라 단위 테스트로 고정한다.
/// `@testable import` 로만 접근 가능한 내부 래퍼.
extension FileSafety {
    static func shellQuotedForTesting(_ path: String) -> String {
        shellQuoted(path)
    }

    static func appleScriptLiteralForTesting(_ shellCommand: String) -> String {
        appleScriptStringLiteral(shellCommand)
    }

    static func isShellSafePathForTesting(_ path: String) -> Bool {
        isShellSafePath(path)
    }
}

/// 완료 핸들러와 대기 스레드가 공유하는 불리언 플래그.
private final class CompletionFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var flag = false

    func set(_ newValue: Bool) {
        lock.lock()
        flag = newValue
        lock.unlock()
    }

    var value: Bool {
        lock.lock()
        defer { lock.unlock() }
        return flag
    }
}
