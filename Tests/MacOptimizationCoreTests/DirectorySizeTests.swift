import Foundation
import Testing
@testable import MacOptimizationCore

/// 폴더 크기 측정 테스트.
/// 이 로직은 언인스톨러·디스크 정리·개인정보 정리·방치 다운로드에 네 번 복제돼 있었고,
/// 네 복사본 모두 하드링크를 중복으로 더하고 취소를 확인하지 않았다.
@Suite("폴더 크기 측정")
struct DirectorySizeTests {

    private func makeTemporaryDirectory() throws -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("일반 파일들의 크기를 합산한다")
    func sumsPlainFiles() throws {
        let dir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        try Data(repeating: 1, count: 4_096).write(to: dir.appendingPathComponent("a.bin"))
        try Data(repeating: 2, count: 8_192).write(to: dir.appendingPathComponent("b.bin"))

        let result = DirectorySize.measure(at: dir)
        #expect(result.fileCount == 2)
        #expect(result.logicalBytes == 12_288)
        // 할당 크기는 블록 단위라 논리 크기보다 작지 않다.
        #expect(result.localBytes >= result.logicalBytes)
        #expect(result.hardLinkFoldedCount == 0)
        #expect(result.wasCancelled == false)
    }

    @Test("하드링크는 한 번만 센다")
    func foldsHardLinks() throws {
        let dir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let original = dir.appendingPathComponent("movie.mov")
        try Data(repeating: 42, count: 1_048_576).write(to: original)
        for index in 1...3 {
            try FileManager.default.linkItem(at: original, to: dir.appendingPathComponent("link\(index).mov"))
        }

        let result = DirectorySize.measure(at: dir)
        #expect(result.hardLinkFoldedCount == 3)
        #expect(result.fileCount == 1)
        // 복제 전 구현은 4배(4MB)를 보고했다.
        #expect(result.logicalBytes == 1_048_576)
    }

    @Test("취소되면 즉시 멈추고 불완전함을 표시한다")
    func stopsWhenCancelled() throws {
        let dir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        for index in 0..<50 {
            try Data(repeating: 3, count: 1_024).write(to: dir.appendingPathComponent("f\(index).bin"))
        }

        var visits = 0
        let result = DirectorySize.measure(at: dir, isCancelled: {
            visits += 1
            return visits > 5
        })

        #expect(result.wasCancelled)
        #expect(result.fileCount < 50)
    }

    @Test("단일 파일도 측정한다")
    func measuresSingleFile() throws {
        let dir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let file = dir.appendingPathComponent("single.bin")
        try Data(repeating: 5, count: 2_048).write(to: file)

        let result = DirectorySize.measure(at: file)
        #expect(result.fileCount == 1)
        #expect(result.logicalBytes == 2_048)
        #expect(result.localBytes > 0)
        #expect(result.offloadedCount == 0)
    }

    @Test("없는 경로는 0 이다")
    func missingPathIsZero() {
        let result = DirectorySize.measure(at: URL(fileURLWithPath: "/tmp/no-such-dir-\(UUID().uuidString)"))
        #expect(result == DirectorySizeResult())
    }

    @Test("빈 폴더는 0 이고 취소 표시가 없다")
    func emptyDirectory() throws {
        let dir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let result = DirectorySize.measure(at: dir)
        #expect(result.fileCount == 0)
        #expect(result.logicalBytes == 0)
        #expect(result.localBytes == 0)
        #expect(result.wasCancelled == false)
    }

    @Test("로컬 점유가 0 이고 크기가 있는 파일은 오프로드로 센다")
    func countsOffloadedFiles() throws {
        let dir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        // 실제 iCloud 오프로드 파일은 테스트에서 만들 수 없다.
        // 대신 스파스 파일로 "논리 크기 > 0, 블록 0" 상태를 재현한다.
        let file = dir.appendingPathComponent("sparse.bin")
        FileManager.default.createFile(atPath: file.path, contents: nil)
        let handle = try FileHandle(forWritingTo: file)
        try handle.truncate(atOffset: 10_485_760)   // 10 MB, 블록 미할당
        try handle.close()

        let result = DirectorySize.measure(at: file)
        #expect(result.logicalBytes == 10_485_760)
        if result.localBytes == 0 {
            #expect(result.offloadedCount == 1)
        }
    }
}
