import Foundation

public struct RAMStats: Sendable {
    public let total: Int64
    public let used: Int64
    public let free: Int64
    public let percent: Double
}

public struct TelemetryData: Sendable {
    /// 커널 통계 조회 실패 시 nil. 추정값을 지어내지 않는다.
    public let cpuUsage: Double?
    public let ramStats: RAMStats?
}

public enum HardwareStatsHelper {
    /// 여러 스레드(메뉴바 타이머, 대시보드 텔레메트리 스트림)에서 동시에 접근하므로
    /// 직전 CPU 틱 스냅샷은 반드시 락으로 보호해야 한다.
    private static let cpuLoadLock = NSLock()
    nonisolated(unsafe) private static var previousCPULoad: host_cpu_load_info?

    /// 커널 페이지 크기. `vm_kernel_page_size` 는 전역 가변 변수라 동시성 안전하지 않아 sysconf 를 사용한다.
    private static var pageSize: Int64 { Int64(sysconf(_SC_PAGESIZE)) }

    /// 실시간 하드웨어 텔레메트리 비동기 데이터 스트림 반환
    public static func startTelemetryStream() -> AsyncStream<TelemetryData> {
        return AsyncStream { continuation in
            let task = Task {
                while !Task.isCancelled {
                    continuation.yield(TelemetryData(cpuUsage: getCPUUsage(), ramStats: getRAMStats()))

                    do {
                        // 2초 간격 대기
                        try await Task.sleep(nanoseconds: 2_000_000_000)
                    } catch {
                        break
                    }
                }
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// 직전 호출 이후의 CPU 사용률(%). 커널 조회 실패 또는 첫 호출(기준 스냅샷 없음)이면 nil.
    public static func getCPUUsage() -> Double? {
        var cpuLoad = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let kerr = withUnsafeMutablePointer(to: &cpuLoad) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }

        guard kerr == KERN_SUCCESS else { return nil }

        cpuLoadLock.lock()
        defer { cpuLoadLock.unlock() }

        guard let prev = previousCPULoad else {
            previousCPULoad = cpuLoad
            return nil
        }

        let userDiff = Double(cpuLoad.cpu_ticks.0 &- prev.cpu_ticks.0)
        let sysDiff = Double(cpuLoad.cpu_ticks.1 &- prev.cpu_ticks.1)
        let idleDiff = Double(cpuLoad.cpu_ticks.2 &- prev.cpu_ticks.2)
        let niceDiff = Double(cpuLoad.cpu_ticks.3 &- prev.cpu_ticks.3)

        previousCPULoad = cpuLoad

        let total = userDiff + sysDiff + idleDiff + niceDiff
        guard total > 0 else { return nil }
        return ((userDiff + sysDiff + niceDiff) / total) * 100.0
    }

    /// 물리 메모리 사용 현황. 커널 조회 실패 시 nil.
    public static func getRAMStats() -> RAMStats? {
        let totalBytes = Int64(ProcessInfo.processInfo.physicalMemory)
        guard totalBytes > 0 else { return nil }

        var stats = vm_statistics64()
        var countStats = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let kerrStats = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(countStats)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &countStats)
            }
        }

        guard kerrStats == KERN_SUCCESS else { return nil }

        let bytesPerPage = pageSize
        let active = Int64(stats.active_count) * bytesPerPage
        let wired = Int64(stats.wire_count) * bytesPerPage
        let compressed = Int64(stats.compressor_page_count) * bytesPerPage

        let used = min(active + wired + compressed, totalBytes)
        let free = totalBytes - used
        let percent = (Double(used) / Double(totalBytes)) * 100.0
        return RAMStats(total: totalBytes, used: used, free: free, percent: percent)
    }
}
