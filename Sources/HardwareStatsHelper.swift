import Foundation

struct RAMStats {
    let total: Int64
    let used: Int64
    let free: Int64
    let percent: Double
}

struct TelemetryData {
    let cpuUsage: Double
    let ramStats: RAMStats
}

class HardwareStatsHelper {
    static var previousCPULoad: host_cpu_load_info?
    
    /// 실시간 하드웨어 텔레메트리 비동기 데이터 스트림 반환
    static func startTelemetryStream() -> AsyncStream<TelemetryData> {
        return AsyncStream { continuation in
            let task = Task {
                while !Task.isCancelled {
                    let cpu = getCPUUsage()
                    let ram = getRAMStats()
                    continuation.yield(TelemetryData(cpuUsage: cpu, ramStats: ram))
                    
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
    
    static func getCPUUsage() -> Double {
        var cpuLoad = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let kerr = withUnsafeMutablePointer(to: &cpuLoad) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        
        guard kerr == KERN_SUCCESS else { return 5.0 }
        
        if let prev = previousCPULoad {
            let userDiff = Double(cpuLoad.cpu_ticks.0 - prev.cpu_ticks.0)
            let sysDiff = Double(cpuLoad.cpu_ticks.1 - prev.cpu_ticks.1)
            let idleDiff = Double(cpuLoad.cpu_ticks.2 - prev.cpu_ticks.2)
            let niceDiff = Double(cpuLoad.cpu_ticks.3 - prev.cpu_ticks.3)
            
            let total = userDiff + sysDiff + idleDiff + niceDiff
            previousCPULoad = cpuLoad
            
            if total > 0 {
                return ((userDiff + sysDiff + niceDiff) / total) * 100.0
            }
        } else {
            previousCPULoad = cpuLoad
        }
        return 5.0
    }
    
    static func getRAMStats() -> RAMStats {
        let totalBytes = ProcessInfo.processInfo.physicalMemory
        var stats = vm_statistics64()
        var countStats = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        
        let kerrStats = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(countStats)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &countStats)
            }
        }
        
        if kerrStats == KERN_SUCCESS {
            let pageSize = vm_kernel_page_size
            let active = Double(stats.active_count) * Double(pageSize)
            let wired = Double(stats.wire_count) * Double(pageSize)
            let compressed = Double(stats.compressor_page_count) * Double(pageSize)
            
            let used = Int64(active + wired + compressed)
            let free = Int64(totalBytes) - used
            let percent = (Double(used) / Double(totalBytes)) * 100.0
            return RAMStats(total: Int64(totalBytes), used: used, free: free, percent: percent)
        }
        
        return RAMStats(total: Int64(totalBytes), used: Int64(Double(totalBytes) * 0.6), free: Int64(Double(totalBytes) * 0.4), percent: 60.0)
    }
}
