import Foundation
import Testing
@testable import MacOptimizationCore

/// 텔레메트리는 실패 시 추정값을 지어내면 안 된다 (모니터링 도구가 거짓 수치를 표시하는 문제).
@Suite("하드웨어 텔레메트리")
struct HardwareStatsTests {

    @Test("RAM 통계는 내부적으로 일관적이다")
    func ramStatsAreInternallyConsistent() throws {
        let stats = try #require(HardwareStatsHelper.getRAMStats())
        #expect(stats.total > 0)
        #expect(stats.used > 0)
        #expect(stats.used <= stats.total)
        #expect(stats.used + stats.free == stats.total)
        #expect(stats.percent > 0)
        #expect(stats.percent <= 100)
    }

    /// 첫 호출은 기준 스냅샷이 없어 nil, 이후 값은 0~100 범위의 실제 측정값이어야 한다.
    @Test("CPU 사용률은 범위를 벗어나지 않는다")
    func cpuUsageIsBounded() async throws {
        _ = HardwareStatsHelper.getCPUUsage()
        try await Task.sleep(nanoseconds: 200_000_000)

        if let usage = HardwareStatsHelper.getCPUUsage() {
            #expect(usage >= 0)
            #expect(usage <= 100)
        }
    }

    @Test("텔레메트리 스트림이 값을 방출한다")
    func telemetryStreamYieldsValues() async {
        var received = 0
        for await sample in HardwareStatsHelper.startTelemetryStream() {
            received += 1
            #expect(sample.ramStats != nil)
            break
        }
        #expect(received == 1)
    }
}
