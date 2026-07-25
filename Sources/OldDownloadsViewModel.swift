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

    @Published var isCancelled: Bool = false
    private var scanTask: Task<Void, Never>?

    func cancelScan() {
        isCancelled = true
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        scanProgress = 0.0
        scanStatusText = "스캔이 취소되었습니다."
    }

    func scanOldDownloads() {
        cancelScan()
        isCancelled = false
        isScanning = true
        hasScanned = false
        showCleanSuccess = false
        items = []
        scanProgress = 0.05
        scanStatusText = "다운로드 폴더 방치 파일 탐색 중..."
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
                    
                    let size: Int64
                    if isDirectoryOrPkg {
                        size = Self.calculateSizeStatic(at: fileURL)
                    } else {
                        size = Int64(vals.fileSize ?? 0)
                    }

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
                            self?.scanStatusText = "다운로드 스캔 중... (\(countScanned)개 검사, \(countMatched)개 방치 파일 발견)"
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
                self.scanStatusText = "스캔이 취소되었습니다."
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

    nonisolated private static func calculateSizeStatic(at url: URL) -> Int64 {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }
        
        if !isDir.boolValue {
            var statInfo = stat()
            if lstat(url.path, &statInfo) == 0 {
                return Int64(statInfo.st_size)
            }
            return 0
        }
        
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: nil
        ) else { return 0 }
        
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let vals = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
               let isDirectory = vals.isDirectory, !isDirectory,
               let fileSize = vals.fileSize {
                total += Int64(fileSize)
            }
        }
        return total
    }
}
