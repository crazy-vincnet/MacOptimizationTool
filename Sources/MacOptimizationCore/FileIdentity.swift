import Foundation

/// 파일 시스템이 보는 파일의 신원 (장치 + inode).
///
/// 하드링크는 같은 실체를 여러 경로가 가리키는 것이므로 "중복 파일" 이 아니다.
/// 하나를 지워도 공간이 회수되지 않고, 사용자는 원본을 지웠다고 오해한다.
/// 중복 그룹을 만들기 전에 같은 신원을 하나로 접어야 한다.
///
/// APFS 클론(복사 시 블록 공유)은 inode 가 서로 달라 공개 API 로 판별할 수 없다.
/// 클론은 내용이 같은 별개 파일로 취급된다 — 지워도 실제 회수량은 0 일 수 있다.
public struct FileIdentity: Hashable, Sendable {
    public let deviceID: UInt64
    public let inode: UInt64
    /// 이 실체를 가리키는 경로 수. 2 이상이면 하드링크가 존재한다.
    public let linkCount: UInt64

    public init(deviceID: UInt64, inode: UInt64, linkCount: UInt64) {
        self.deviceID = deviceID
        self.inode = inode
        self.linkCount = linkCount
    }

    /// 심볼릭 링크는 따라가지 않고 대상 자체의 신원을 읽는다.
    public init?(path: String) {
        var info = stat()
        guard lstat(path, &info) == 0 else { return nil }
        // 심볼릭 링크는 중복 후보가 아니다.
        guard (info.st_mode & S_IFMT) == S_IFREG else { return nil }
        self.deviceID = UInt64(info.st_dev)
        self.inode = UInt64(info.st_ino)
        self.linkCount = UInt64(info.st_nlink)
    }

    public var hasHardLinks: Bool { linkCount > 1 }

    /// 신원이 같은 경로를 하나만 남긴다. 순서는 입력 순서를 유지한다.
    public static func deduplicatedByIdentity(_ paths: [String]) -> [String] {
        var seen: Set<FileIdentity> = []
        var result: [String] = []
        for path in paths {
            guard let identity = FileIdentity(path: path) else { continue }
            if seen.insert(identity).inserted {
                result.append(path)
            }
        }
        return result
    }
}
