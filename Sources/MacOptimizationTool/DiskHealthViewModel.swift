import Foundation
import Combine
import AppKit
import MacOptimizationCore

struct DiskHealthInfo: Identifiable {
    let id = UUID()
    let volumeName: String
    let mountPath: String
    let fileSystem: String
    let totalBytes: Int64
    let freeBytes: Int64
    let usedBytes: Int64
    let usagePercent: Double
    let smartStatus: String?
    let temperatureCelsius: Int?
    let healthRatingPercent: Int?
    let isSSD: Bool?
}

@MainActor
final class DiskHealthViewModel: ObservableObject {
    static let shared = DiskHealthViewModel()

    @Published var disks: [DiskHealthInfo] = []
    @Published var isLoading: Bool = false
    @Published var lastRefreshed: Date = Date()

    init() {
        fetchDiskHealth()
    }

    func fetchDiskHealth() {
        isLoading = true
        disks = []

        Task {
            let fetched = await Task.detached(priority: .userInitiated) { () -> [DiskHealthInfo] in
                var results: [DiskHealthInfo] = []
                let fm = FileManager.default
                let keys: [URLResourceKey] = [.volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey, .volumeLocalizedFormatDescriptionKey]
                
                guard let urls = fm.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) else {
                    return []
                }

                for url in urls {
                    guard let vals = try? url.resourceValues(forKeys: Set(keys)) else { continue }
                    
                    let name = vals.volumeName ?? url.lastPathComponent
                    let total = Int64(vals.volumeTotalCapacity ?? 0)
                    let available = Int64(vals.volumeAvailableCapacity ?? 0)
                    
                    guard total > 0 else { continue }
                    
                    let used = max(0, total - available)
                    let usagePct = (Double(used) / Double(total)) * 100.0
                    let format = vals.volumeLocalizedFormatDescription ?? "—"
                    
                    // Foundation의 볼륨 API는 SMART, 온도, 수명 또는 SSD 여부를 제공하지 않는다.
                    // 측정하지 않은 값을 정상 수치로 만들어 내지 않고 명시적으로 미측정 상태로 둔다.
                    results.append(DiskHealthInfo(
                        volumeName: name,
                        mountPath: url.path,
                        fileSystem: format,
                        totalBytes: total,
                        freeBytes: available,
                        usedBytes: used,
                        usagePercent: usagePct,
                        smartStatus: nil,
                        temperatureCelsius: nil,
                        healthRatingPercent: nil,
                        isSSD: nil
                    ))
                }
                
                // Root 시스템 볼륨 우선 정렬
                results.sort { $0.mountPath == "/" && $1.mountPath != "/" }
                return results
            }.value

            self.disks = fetched
            self.lastRefreshed = Date()
            self.isLoading = false
        }
    }
}
