import Foundation

/// 해시 계산 결과 캐시.
///
/// 키는 `경로 + 크기 + 수정 시각 + 해시 종류` 다. 세 값 중 하나라도 다르면 다른 항목이므로,
/// 파일이 바뀌면 캐시가 자동으로 무효화된다. (경로만 키로 쓰면 내용이 바뀐 파일에
/// 옛 해시를 그대로 쓰게 되어 중복 판정이 틀린다.)
public enum HashKind: String, Codable, Sendable {
    /// 앞·중간·뒤 샘플 해시
    case sampled
    /// 전체 SHA-256
    case full
}

public struct HashCacheKey: Hashable, Codable, Sendable {
    public let path: String
    public let size: Int64
    /// 수정 시각. 파일 시스템 해상도를 고려해 초 단위로 내림한다.
    public let modifiedSeconds: Int64
    public let kind: HashKind

    public init(path: String, size: Int64, modified: Date, kind: HashKind) {
        self.path = path
        self.size = size
        self.modifiedSeconds = Int64(modified.timeIntervalSince1970)
        self.kind = kind
    }

    /// 사전 직렬화용 문자열 키.
    public var storageKey: String {
        "\(kind.rawValue)|\(size)|\(modifiedSeconds)|\(path)"
    }
}

/// 디스크에 남는 해시 캐시. 백그라운드 해시 워커들이 동시에 접근하므로 락으로 보호한다.
public final class HashCache: @unchecked Sendable {

    public static let shared = HashCache()

    /// 캐시 상한. 넘으면 전체를 비운다 (LRU 를 유지하는 비용이 이득보다 크다).
    public static let maxEntries = 200_000

    private let lock = NSLock()
    private var entries: [String: String] = [:]
    private var isDirty = false
    private let fileURL: URL?

    public init(fileURL: URL? = HashCache.defaultFileURL()) {
        self.fileURL = fileURL
        load()
    }

    public static func defaultFileURL() -> URL? {
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let directory = support.appendingPathComponent("MacOptimizationTool", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("duplicate-hash-cache.json")
    }

    public func hash(for key: HashCacheKey) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return entries[key.storageKey]
    }

    public func store(_ hash: String, for key: HashCacheKey) {
        lock.lock()
        defer { lock.unlock() }
        if entries.count >= Self.maxEntries {
            entries.removeAll(keepingCapacity: true)
        }
        entries[key.storageKey] = hash
        isDirty = true
    }

    /// 캐시에 있으면 그것을, 없으면 `compute` 를 실행해 채운다.
    public func value(for key: HashCacheKey, compute: () -> String?) -> String? {
        if let cached = hash(for: key) { return cached }
        guard let computed = compute() else { return nil }
        store(computed, for: key)
        return computed
    }

    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return entries.count
    }

    public func removeAll() {
        lock.lock()
        entries.removeAll()
        isDirty = true
        lock.unlock()
        save()
    }

    public func load() {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return }
        guard let decoded = try? JSONDecoder().decode([String: String].self, from: data) else { return }
        lock.lock()
        entries = decoded
        isDirty = false
        lock.unlock()
    }

    /// 변경이 있을 때만 기록한다. 스캔이 끝난 시점에 한 번 호출하면 된다.
    public func save() {
        guard let fileURL else { return }
        lock.lock()
        let shouldWrite = isDirty
        let snapshot = entries
        isDirty = false
        lock.unlock()

        guard shouldWrite, let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
