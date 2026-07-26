import Foundation
import Combine
import AppKit
import MacOptimizationCore

struct OldDownloadItem: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let path: String
    let size: Int64
    /// 실제로 로컬 디스크를 점유하는 양. iCloud 에서 내려받지 않은 파일은 0 이다.
    /// `size` 는 사용자가 아는 파일 크기, 이 값은 삭제로 회수되는 용량이다.
    let localSize: Int64
    let category: OldDownloadCategory
    let daysOld: Int
    let modificationDate: Date
    var isSelected: Bool = true
    
    /// 로컬에 블록이 없는 파일. 지워도 디스크 공간이 회수되지 않는다.
    var isCloudOnly: Bool { localSize == 0 && size > 0 }

    var readableLocalSize: String {
        ByteCountFormatter.string(fromByteCount: localSize, countStyle: .file)
    }

    var readableSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

enum OldDownloadCategory: String, CaseIterable, Identifiable {
    case installers
    case media
    case documents
    
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .installers: return t("old.cat.installers")
        case .media: return t("old.cat.media")
        case .documents: return t("old.cat.documents")
        }
    }

    var iconName: String {
        switch self {
        case .installers: return "archivebox.fill"
        case .media: return "film.fill"
        case .documents: return "doc.fill"
        }
    }
}

enum AgeThreshold: Int, CaseIterable, Identifiable {
    case days30 = 30
    case days60 = 60
    case days90 = 90
    
    var id: Int { rawValue }
    
    var displayName: String {
        String(format: t("old.age.threshold"), String(rawValue))
    }
}

@MainActor
final class OldDownloadsViewModel: ObservableObject {
    static let shared = OldDownloadsViewModel()

    @Published var items: [OldDownloadItem] = []
    @Published var selectedAgeThreshold: AgeThreshold = .days30
    @Published var isScanning: Bool = false
    @Published var isCleaning: Bool = false
    @Published var hasScanned: Bool = false
    @Published var showCleanSuccess: Bool = false
    @Published var cleanedSize: Int64 = 0

    // Real-Time Progress Properties
    @Published var scanProgress: Double = 0.0
    @Published var scanStatusText: String = ""
    @Published var scannedCount: Int = 0
    @Published var matchedCount: Int = 0
    @Published var currentScanPath: String = ""

    /// 삭제 시 실제로 회수되는 용량 (로컬 점유 합).
    var selectedSize: Int64 {
        items.filter { $0.isSelected }.reduce(0) { $0 + $1.localSize }
    }

    /// 선택한 파일들의 파일 크기 합. 클라우드 전용 파일도 원래 크기로 센다.
    var selectedLogicalSize: Int64 {
        items.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
    }

    /// 선택 항목 중 클라우드에만 있는 파일 수.
    var selectedCloudOnlyCount: Int {
        items.filter { $0.isSelected && $0.isCloudOnly }.count
    }

    var selectedCount: Int {
        items.filter { $0.isSelected }.count
    }

    @Published var isCancelled: Bool = false
    private var scanTask: Task<Void, Never>?

    func cancelScan() {
        isCancelled = true
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        scanProgress = 0.0
        scanStatusText = t("common.scanCancelled")
    }

    func scanOldDownloads() {
        cancelScan()
        isCancelled = false
        isScanning = true
        hasScanned = false
        showCleanSuccess = false
        items = []
        scanProgress = 0.05
        scanStatusText = t("old.status.start")
        scannedCount = 0
        matchedCount = 0

        let thresholdDays = selectedAgeThreshold.rawValue

        scanTask = Task {
            let resultItems = await Task.detached(priority: .userInitiated) { [weak self] () -> [OldDownloadItem] in
                let fm = FileManager.default
                let downloadsURL = fm.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
                let now = Date()
                var list: [OldDownloadItem] = []

                let options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles, .skipsPackageDescendants, .skipsSubdirectoryDescendants]
                let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey, .isPackageKey]

                guard let enumerator = fm.enumerator(
                    at: downloadsURL,
                    includingPropertiesForKeys: keys,
                    options: options,
                    errorHandler: { _, _ in return true }
                ) else { return [] }

                var localScanned = 0
                var localMatched = 0

                while let fileURL = enumerator.nextObject() as? URL {
                    if Task.isCancelled { break }


                    localScanned += 1
                    let path = fileURL.standardized.path

                    if FileSafety.isProtectedExact(path) { continue }

                    guard let vals = try? fileURL.resourceValues(forKeys: Set(keys)),
                          let isDir = vals.isDirectory,
                          let isPkg = vals.isPackage,
                          let modDate = vals.contentModificationDate else { continue }

                    // 폴더나 패키지 내부 깊은 탐색은 스킵
                    let isDirectoryOrPkg = isDir || isPkg
                    
                    // 파일 크기(논리)와 실제 로컬 점유를 함께 잡는다.
                    // 클라우드에만 있는 파일은 지워도 공간이 회수되지 않으므로 구분해서 보여준다.
                    let measurement = DirectorySize.measure(at: fileURL, isCancelled: { Task.isCancelled })
                    let size = measurement.logicalBytes
                    let localSize = measurement.localBytes

                    guard size > 0 else { continue }

                    let days = Calendar.current.dateComponents([.day], from: modDate, to: now).day ?? 0
                    if days >= thresholdDays {
                        localMatched += 1
                        let ext = fileURL.pathExtension.lowercased()
                        let category: OldDownloadCategory

                        if ["dmg", "pkg", "zip", "iso", "tar", "gz", "7z", "rar", "app"].contains(ext) {
                            category = .installers
                        } else if ["mov", "mp4", "mkv", "avi", "mp3", "flac"].contains(ext) {
                            category = .media
                        } else {
                            category = .documents
                        }

                        let item = OldDownloadItem(
                            url: fileURL,
                            name: fileURL.lastPathComponent,
                            path: path,
                            size: size,
                            localSize: localSize,
                            category: category,
                            daysOld: days,
                            modificationDate: modDate,
                            isSelected: true
                        )
                        list.append(item)
                    }

                    if localScanned % 15 == 0 {
                        let filename = fileURL.lastPathComponent
                        let countScanned = localScanned
                        let countMatched = localMatched
                        await MainActor.run { [weak self] in
                            self?.scannedCount = countScanned
                            self?.matchedCount = countMatched
                            self?.currentScanPath = filename
                            self?.scanStatusText = String(format: t("old.status.scanning"), countScanned, countMatched)
                            self?.scanProgress = min(0.95, Double(countScanned) / 1000.0 * 0.95)
                        }

                    }
                }

                list.sort(by: { $0.daysOld > $1.daysOld })
                return list
            }.value

            if !self.isCancelled {
                self.items = resultItems
                self.scanProgress = 1.0
                self.isScanning = false
                self.hasScanned = true
            } else {
                self.isScanning = false
                self.scanProgress = 0.0
                self.scanStatusText = t("common.scanCancelled")
            }
        }

    }

    func deleteSelectedItems() {
        let targets = items.filter { $0.isSelected }
        guard !targets.isEmpty else { return }

        isCleaning = true
        showCleanSuccess = false

        Task {
            let freed = await Task.detached(priority: .userInitiated) { () -> Int64 in
                var totalCleaned: Int64 = 0
                for item in targets {
                    if FileSafety.moveToTrash(item.url) {
                        // 회수 용량은 로컬 점유 기준이다. 클라우드 전용 파일은 0 을 더한다.
                        totalCleaned += item.localSize
                    }
                }
                return totalCleaned
            }.value

            self.cleanedSize = freed
            self.isCleaning = false
            self.showCleanSuccess = true
            self.scanOldDownloads()
        }
    }

}
