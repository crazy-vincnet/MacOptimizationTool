import Foundation
import Testing
@testable import MacOptimizationCore

/// 중복 검사 성능 개선 부품 테스트.
/// 제외 규칙·최소 크기·해시 캐시·하드링크 판정은 스캔 시간과 정확도를 직접 좌우한다.
@Suite("중복 검사 스캔 규칙")
struct DuplicateScanTests {

    // MARK: - 제외 규칙

    @Test("의존성·캐시 디렉터리는 이름만으로 가지치기된다")
    func prunesDependencyDirectories() {
        for name in ["node_modules", ".git", "DerivedData", "Pods", "Caches", ".venv"] {
            #expect(ScanExclusion.shouldPruneDirectory(named: name), "\(name) 가 가지치기되지 않는다")
        }
    }

    @Test("일반 폴더는 가지치기되지 않는다")
    func keepsOrdinaryDirectories() {
        for name in ["Downloads", "Photos", "MyProject", "library"] {
            #expect(!ScanExclusion.shouldPruneDirectory(named: name))
        }
    }

    @Test("트리 판정은 경로 경계를 지킨다")
    func treeMatchingRespectsBoundaries() {
        #expect(ScanExclusion.isWithinTree(path: "/usr/lib/x", tree: "/usr"))
        #expect(ScanExclusion.isWithinTree(path: "/usr", tree: "/usr"))
        // 접두사만 같은 다른 경로를 오차단하지 않는다.
        #expect(!ScanExclusion.isWithinTree(path: "/usrdata/x", tree: "/usr"))
    }

    @Test("시스템 트리와 홈 Library 는 제외되고 사용자 폴더는 유지된다")
    func excludesSystemAndHomeLibrary() {
        let home = "/Users/tester"
        #expect(ScanExclusion.isExcluded(path: "/System/Library/x", homeDirectory: home))
        #expect(ScanExclusion.isExcluded(path: "\(home)/Library/Caches/x", homeDirectory: home))
        #expect(ScanExclusion.isExcluded(path: "\(home)/.Trash/x", homeDirectory: home))
        // 사용자가 만든 Library 라는 이름의 폴더는 제외 대상이 아니다.
        #expect(!ScanExclusion.isExcluded(path: "\(home)/Projects/Library/x", homeDirectory: home))
        #expect(!ScanExclusion.isExcluded(path: "\(home)/Downloads/x", homeDirectory: home))
    }

    // MARK: - 설정

    @Test("최소 크기 기본값은 1MB 이고 프리셋이 오름차순이다")
    func minimumSizePresets() {
        #expect(DuplicateMinimumSize.medium.bytes == 1_048_576)
        let sizes = DuplicateMinimumSize.allCases.map(\.bytes)
        #expect(sizes == sizes.sorted())
    }

    @Test("해시 병렬도는 코어 수를 넘지 않고 최소 2 이상이다")
    func concurrencyIsBounded() {
        let recommended = ScanConcurrency.recommended
        #expect(recommended >= 2)
        #expect(recommended <= max(2, ProcessInfo.processInfo.activeProcessorCount))
    }

    @Test("스캔 범위 프리셋은 홈 하위 경로를 가리키고 custom 은 비어 있다")
    func scopeURLs() {
        let home = "/Users/tester"
        #expect(DuplicateScanScope.downloads.url(homeDirectory: home)?.path == "\(home)/Downloads")
        #expect(DuplicateScanScope.home.url(homeDirectory: home)?.path == home)
        #expect(DuplicateScanScope.custom.url(homeDirectory: home) == nil)
    }

    // MARK: - 해시 캐시

    @Test("수정 시각이나 크기가 바뀌면 캐시가 무효화된다")
    func cacheKeyInvalidatesOnChange() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let base = HashCacheKey(path: "/tmp/a", size: 10, modified: now, kind: .sampled)

        #expect(base.storageKey == HashCacheKey(path: "/tmp/a", size: 10, modified: now, kind: .sampled).storageKey)
        #expect(base.storageKey != HashCacheKey(path: "/tmp/a", size: 11, modified: now, kind: .sampled).storageKey)
        #expect(base.storageKey != HashCacheKey(path: "/tmp/a", size: 10, modified: now.addingTimeInterval(60), kind: .sampled).storageKey)
        // 샘플 해시와 전체 해시는 서로 섞이면 안 된다.
        #expect(base.storageKey != HashCacheKey(path: "/tmp/a", size: 10, modified: now, kind: .full).storageKey)
    }

    @Test("캐시는 두 번째 조회에서 계산을 건너뛴다")
    func cacheAvoidsRecomputation() {
        let cache = HashCache(fileURL: nil)
        let key = HashCacheKey(path: "/tmp/a", size: 10, modified: Date(timeIntervalSince1970: 0), kind: .sampled)

        var computeCount = 0
        let first = cache.value(for: key) { computeCount += 1; return "deadbeef" }
        let second = cache.value(for: key) { computeCount += 1; return "deadbeef" }

        #expect(first == "deadbeef")
        #expect(second == "deadbeef")
        #expect(computeCount == 1)
    }

    @Test("계산이 실패하면 캐시에 남기지 않는다")
    func cacheDoesNotStoreFailures() {
        let cache = HashCache(fileURL: nil)
        let key = HashCacheKey(path: "/tmp/missing", size: 1, modified: Date(timeIntervalSince1970: 0), kind: .full)
        #expect(cache.value(for: key) { nil } == nil)
        #expect(cache.count == 0)
    }

    @Test("캐시는 디스크에 저장하고 다시 읽을 수 있다")
    func cachePersists() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("cache.json")

        let key = HashCacheKey(path: "/tmp/a", size: 10, modified: Date(timeIntervalSince1970: 0), kind: .sampled)
        let writer = HashCache(fileURL: file)
        writer.store("cafebabe", for: key)
        writer.save()

        let reader = HashCache(fileURL: file)
        #expect(reader.hash(for: key) == "cafebabe")
    }

    // MARK: - 하드링크

    @Test("하드링크는 같은 신원으로 접힌다")
    func hardLinksFoldIntoOneIdentity() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let original = dir.appendingPathComponent("original.bin")
        try Data(repeating: 7, count: 4_096).write(to: original)
        let link = dir.appendingPathComponent("link.bin")
        try FileManager.default.linkItem(at: original, to: link)

        let copy = dir.appendingPathComponent("copy.bin")
        try Data(repeating: 7, count: 4_096).write(to: copy)

        let originalIdentity = try #require(FileIdentity(path: original.path))
        let linkIdentity = try #require(FileIdentity(path: link.path))
        let copyIdentity = try #require(FileIdentity(path: copy.path))

        #expect(originalIdentity == linkIdentity)
        #expect(originalIdentity.hasHardLinks)
        // 내용이 같은 별개 파일은 다른 신원이라 중복으로 남는다.
        #expect(originalIdentity != copyIdentity)

        let deduped = FileIdentity.deduplicatedByIdentity([original.path, link.path, copy.path])
        #expect(deduped.count == 2)
        #expect(deduped.first == original.path)
    }

    @Test("디렉터리와 없는 경로는 신원이 없다")
    func identityRejectsNonRegularFiles() {
        #expect(FileIdentity(path: NSTemporaryDirectory()) == nil)
        #expect(FileIdentity(path: "/tmp/definitely-not-here-\(UUID().uuidString)") == nil)
    }

    // MARK: - 샘플 해시

    @Test("중간 청크가 다르면 샘플 해시도 다르다")
    func sampledHashDetectsMiddleDifference() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        // 앞 8KB 와 뒤 8KB 는 같고 중간만 다른 두 파일. 앞뒤만 보는 해시는 이를 구분하지 못한다.
        let head = Data(repeating: 1, count: 8_192)
        let tail = Data(repeating: 2, count: 8_192)
        var a = head; a.append(Data(repeating: 3, count: 32_768)); a.append(tail)
        var b = head; b.append(Data(repeating: 4, count: 32_768)); b.append(tail)

        let urlA = dir.appendingPathComponent("a.bin")
        let urlB = dir.appendingPathComponent("b.bin")
        try a.write(to: urlA)
        try b.write(to: urlB)

        #expect(FileSafety.partialFileHash(for: urlA) == FileSafety.partialFileHash(for: urlB))
        #expect(FileSafety.sampledFileHash(for: urlA) != FileSafety.sampledFileHash(for: urlB))
    }

    @Test("같은 내용이면 샘플 해시가 같고, 없는 파일은 nil 이다")
    func sampledHashIsStable() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let payload = Data((0..<40_000).map { UInt8($0 % 251) })
        let a = dir.appendingPathComponent("a.bin")
        let b = dir.appendingPathComponent("b.bin")
        try payload.write(to: a)
        try payload.write(to: b)

        #expect(FileSafety.sampledFileHash(for: a) == FileSafety.sampledFileHash(for: b))
        #expect(FileSafety.sampledFileHash(for: a)?.count == 64)
        #expect(FileSafety.sampledFileHash(for: dir.appendingPathComponent("missing.bin")) == nil)
    }

    @Test("크기가 다르면 같은 샘플 구간이어도 해시가 다르다")
    func sampledHashIncludesSize() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let a = dir.appendingPathComponent("a.bin")
        let b = dir.appendingPathComponent("b.bin")
        try Data(repeating: 9, count: 4_000).write(to: a)
        try Data(repeating: 9, count: 5_000).write(to: b)

        #expect(FileSafety.sampledFileHash(for: a) != FileSafety.sampledFileHash(for: b))
    }
}
