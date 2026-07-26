import Foundation

/// 폴더 크기 측정 결과.
///
/// 두 값을 함께 낸다. 하나로 합칠 수 없기 때문이다.
/// - `logicalBytes`: 파일 크기의 합. iCloud 에서 내려받지 않은 파일도 원래 크기로 센다.
/// - `localBytes`: 실제로 로컬 디스크를 점유하는 양. 하드링크는 한 번만 세고,
///   클라우드에만 있는 파일은 0 이다. 삭제로 회수되는 용량은 이 값이다.
///
/// 실측 예: iCloud Drive 동기화가 켜진 데스크탑에서 79MB 짜리 `.psd` 의 `st_blocks` 가 0 이었다.
/// 논리 크기만 쓰면 회수량을 과대 보고하고, 로컬 크기만 쓰면 사용자가 아는 파일 크기와 어긋난다.
public struct DirectorySizeResult: Sendable, Equatable {
    public let logicalBytes: Int64
    public let localBytes: Int64
    public let fileCount: Int
    /// 로컬 점유가 0 인데 논리 크기가 있는 파일 (클라우드 오프로드).
    public let offloadedCount: Int
    /// 같은 실체를 가리켜 중복 계산에서 제외한 하드링크 수.
    public let hardLinkFoldedCount: Int
    /// 취소되어 중간에 멈춘 결과인지. true 면 값이 불완전하다.
    public let wasCancelled: Bool

    public init(logicalBytes: Int64 = 0,
                localBytes: Int64 = 0,
                fileCount: Int = 0,
                offloadedCount: Int = 0,
                hardLinkFoldedCount: Int = 0,
                wasCancelled: Bool = false) {
        self.logicalBytes = logicalBytes
        self.localBytes = localBytes
        self.fileCount = fileCount
        self.offloadedCount = offloadedCount
        self.hardLinkFoldedCount = hardLinkFoldedCount
        self.wasCancelled = wasCancelled
    }
}

/// 폴더·파일 크기 측정.
///
/// 이 로직은 언인스톨러·디스크 정리·개인정보 정리·방치 다운로드에 각각 복제돼 있었고,
/// 네 복사본 모두 하드링크를 여러 번 더하고 취소를 확인하지 않았다.
public enum DirectorySize {

    /// 대상의 크기를 측정한다.
    /// - Parameter isCancelled: 매 항목마다 확인한다. 큰 트리에서 스캔 취소가 즉시 먹히도록 하기 위한 것이다.
    public static func measure(at url: URL, isCancelled: () -> Bool = { false }) -> DirectorySizeResult {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return DirectorySizeResult()
        }

        if !isDirectory.boolValue {
            return measureSingleFile(at: url)
        }

        let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey]
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else {
            return DirectorySizeResult()
        }

        var logical: Int64 = 0
        var local: Int64 = 0
        var fileCount = 0
        var offloaded = 0
        var folded = 0
        var seenIdentities: Set<FileIdentity> = []

        while let child = enumerator.nextObject() as? URL {
            if isCancelled() {
                return DirectorySizeResult(logicalBytes: logical,
                                           localBytes: local,
                                           fileCount: fileCount,
                                           offloadedCount: offloaded,
                                           hardLinkFoldedCount: folded,
                                           wasCancelled: true)
            }

            guard let values = try? child.resourceValues(forKeys: Set(keys)),
                  values.isDirectory == false else { continue }

            // 하드링크는 한 실체를 여러 경로가 가리킨다. 두 번째 이후는 회수 대상이 아니다.
            if let identity = FileIdentity(path: child.path), identity.hasHardLinks {
                if !seenIdentities.insert(identity).inserted {
                    folded += 1
                    continue
                }
            }

            let fileLogical = Int64(values.fileSize ?? 0)
            let fileLocal = Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)

            fileCount += 1
            logical += fileLogical
            local += fileLocal
            if fileLocal == 0 && fileLogical > 0 { offloaded += 1 }
        }

        return DirectorySizeResult(logicalBytes: logical,
                                   localBytes: local,
                                   fileCount: fileCount,
                                   offloadedCount: offloaded,
                                   hardLinkFoldedCount: folded)
    }

    private static func measureSingleFile(at url: URL) -> DirectorySizeResult {
        var info = stat()
        guard lstat(url.path, &info) == 0 else { return DirectorySizeResult() }

        let logical = Int64(info.st_size)
        let local = Int64(info.st_blocks) * 512

        return DirectorySizeResult(logicalBytes: logical,
                                   localBytes: local,
                                   fileCount: 1,
                                   offloadedCount: (local == 0 && logical > 0) ? 1 : 0,
                                   hardLinkFoldedCount: 0)
    }
}
