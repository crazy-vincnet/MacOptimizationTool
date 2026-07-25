import Foundation
import Combine
import AppKit

struct OldDownloadItem: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let path: String
    let size: Int64
    let category: OldDownloadCategory
    let daysOld: Int
    let modificationDate: Date
    var isSelected: Bool = true
    
    var readableSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

enum OldDownloadCategory: String, CaseIterable, Identifiable {
    case installers = "설치 파일 & 압축본 (.dmg/.pkg/.zip)"
    case media = "대용량 동영상 & 미디어 (.mp4/.mov)"
    case documents = "오래된 문서 & 기타"
    
    var id: String { rawValue }
    
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
        "\(rawValue)일 이상 방치"
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

    var selectedSize: Int64 {
        items.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
    }

    var selectedCount: Int {
        items.filter { $0.isSelected }.count
    }

    func scanOldDownloads() {
        isScanning = true
        hasScanned = false
        showCleanSuccess = false
        items = []
        scanProgress = 0.05
        scanStatusText = "다운로드 폴더 방치 파일 탐색 중..."
        scannedCount = 0
        matchedCount = 0

        let thresholdDays = selectedAgeThreshold.rawValue

        Task {
            let resultItems = await Task.detached(priority: .userInitiated) { [weak self] () -> [OldDownloadItem] in
                let fm = FileManager.default
                let downloadsURL = fm.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
                let now = Date()
                var list: [OldDownloadItem] = []

                guard let enumerator = fm.enumerator(
                    at: downloadsURL,
                    includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey],
                    options: [.skipsHiddenFiles],
                    errorHandler: nil
                ) else { return [] }

                var localScanned = 0
                var localMatched = 0

                while let fileURL = enumerator.nextObject() as? URL {
                    localScanned += 1

                    let path = fileURL.standardized.path

                    if FileSafety.isProtectedExact(path) { continue }

                    guard let vals = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey]),
                          let isDir = vals.isDirectory, !isDir,
                          let size = vals.fileSize, size > 0,
                          let modDate = vals.contentModificationDate else { continue }


                    let days = Calendar.current.dateComponents([.day], from: modDate, to: now).day ?? 0
                    if days >= thresholdDays {
                        localMatched += 1
                        let ext = fileURL.pathExtension.lowercased()
                        let category: OldDownloadCategory

                        if ["dmg", "pkg", "zip", "iso", "tar", "gz", "7z", "rar"].contains(ext) {
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
                            size: Int64(size),
                            category: category,
                            daysOld: days,
                            modificationDate: modDate,
                            isSelected: true
                        )
                        list.append(item)
                    }

                    if localScanned % 50 == 0 {
                        let filename = fileURL.lastPathComponent
                        let countScanned = localScanned
                        let countMatched = localMatched
                        await MainActor.run {
                            self?.scannedCount = countScanned
                            self?.matchedCount = countMatched
                            self?.currentScanPath = filename
                            self?.scanStatusText = "다운로드 스캔 중... (\(countScanned)개 검사, \(countMatched)개 방치 파일 발견)"
                            self?.scanProgress = min(0.95, Double(countScanned) / 3000.0 * 0.95)
                        }
                    }
                }

                list.sort(by: { $0.daysOld > $1.daysOld })
                return list
            }.value

            self.items = resultItems
            self.scanProgress = 1.0
            self.isScanning = false
            self.hasScanned = true
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
                        totalCleaned += item.size
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
