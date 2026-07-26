import Foundation

/// 중복 검사 후보의 최소 크기.
/// 회수되는 용량은 큰 파일에서 나온다. 하한이 낮으면 해시 대상만 수십 배로 늘어난다.
public enum DuplicateMinimumSize: Int64, CaseIterable, Identifiable, Sendable {
    case small = 102_400        // 100 KB
    case medium = 1_048_576     // 1 MB  (기본값)
    case large = 10_485_760     // 10 MB

    public var id: Int64 { rawValue }
    public var bytes: Int64 { rawValue }

    public var displayName: String {
        switch self {
        case .small: return "100 KB"
        case .medium: return "1 MB"
        case .large: return "10 MB"
        }
    }
}

/// 검사 정밀도.
public enum DuplicateScanMode: String, CaseIterable, Identifiable, Sendable {
    /// 앞·중간·뒤 8KB 샘플 해시까지만 비교한다. 전체 읽기를 하지 않아 훨씬 빠르다.
    case fast
    /// 샘플 해시가 같은 후보를 전체 SHA-256 으로 재검증한다.
    case thorough

    public var id: String { rawValue }
}

/// 스캔 범위 프리셋. 전체 디스크를 훑지 않고 실제로 중복이 쌓이는 폴더만 본다.
public enum DuplicateScanScope: String, CaseIterable, Identifiable, Sendable {
    case downloads
    case desktop
    case documents
    case home
    case custom

    public var id: String { rawValue }

    /// 프리셋이 가리키는 경로. `custom` 은 사용자가 직접 고른 폴더를 쓰므로 nil.
    public func url(homeDirectory: String = NSHomeDirectory()) -> URL? {
        let home = URL(fileURLWithPath: homeDirectory)
        switch self {
        case .downloads: return home.appendingPathComponent("Downloads")
        case .desktop: return home.appendingPathComponent("Desktop")
        case .documents: return home.appendingPathComponent("Documents")
        case .home: return home
        case .custom: return nil
        }
    }
}

/// 해시 병렬도. SHA-256 은 CPU 바운드라 코어 수를 넘겨도 경쟁만 늘어난다.
public enum ScanConcurrency {
    public static var recommended: Int {
        let cores = ProcessInfo.processInfo.activeProcessorCount
        // UI 응답을 위해 코어 하나는 남기고, 최소 2 / 최대 12 로 제한한다.
        return max(2, min(12, cores - 1))
    }
}
