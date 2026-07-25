import Foundation
import SwiftUI
import AppKit

enum LargeFileSortColumn {
    case name
    case modifiedDate
    case path
    case size
}

enum SortDirection {
    case ascending
    case descending

    var arrow: String {
        self == .ascending ? " ▲" : " ▼"
    }
}

struct LargeFileItem: Identifiable, Hashable {
    let id: String // 파일 전체 경로
    let url: URL
    let name: String
    let size: Int64
    let lastModified: Date
    var isSelected: Bool = false
}

@MainActor
class LargeFilesViewModel: ObservableObject {
    static let shared = LargeFilesViewModel()

    @Published var files: [LargeFileItem] = []
    @Published var isScanning = false
    @Published var isDeleting = false
    @Published var sizeThresholdMB: Double = 100.0 // 기본 100MB
    @Published var ageThresholdMonths: Int = 0 // 0: 상관없음, 3: 3개월 이상, 6: 6개월 이상, 12: 1년 이상
    @Published var targetFolderPath: String = "선택된 폴더 없음"
    @Published var selectedFolderURL: URL? = nil
    @Published var hasScanned = false
    @Published var isCancelled = false

    // Table Sorting State
    @Published var currentSortColumn: LargeFileSortColumn = .size
    @Published var currentSortDirection: SortDirection = .descending

    // Real-Time Progress Tracking Properties
    @Published var scanProgress: Double = 0.0
    @Published var scannedCount: Int = 0
    @Published var matchedCount: Int = 0
    @Published var currentScanPath: String = ""
    @Published var scanStatusText: String = ""

    @Published var showDeleteSuccess = false
    @Published var deletedSize: Int64 = 0
    @Published var deletedCount = 0

    init() {
        let defaultURL = SettingsViewModel.getSavedDefaultScanURL()
        selectedFolderURL = defaultURL
        targetFolderPath = defaultURL.path
    }

    var sortedFiles: [LargeFileItem] {
        files.sorted { a, b in
            switch currentSortColumn {
            case .name:
                return currentSortDirection == .ascending ? a.name.localizedStandardCompare(b.name) == .orderedAscending : a.name.localizedStandardCompare(b.name) == .orderedDescending
            case .modifiedDate:
                return currentSortDirection == .ascending ? a.lastModified < b.lastModified : a.lastModified > b.lastModified
            case .path:
                return currentSortDirection == .ascending ? a.url.path.localizedStandardCompare(b.url.path) == .orderedAscending : a.url.path.localizedStandardCompare(b.url.path) == .orderedDescending
            case .size:
                return currentSortDirection == .ascending ? a.size < b.size : a.size > b.size
            }
        }
    }

    func toggleSort(column: LargeFileSortColumn) {
        if currentSortColumn == column {
            currentSortDirection = (currentSortDirection == .ascending) ? .descending : .ascending
        } else {
            currentSortColumn = column
            currentSortDirection = (column == .size || column == .modifiedDate) ? .descending : .ascending
        }
    }

    func selectFolder() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = false
        openPanel.title = t("large.panelTitle")

        openPanel.begin { [weak self] response in
            guard let self = self else { return }
            if response == .OK, let url = openPanel.url {
                Task {
                    await self.updateSelectedFolder(url)
                }
            }
        }
    }

    private func updateSelectedFolder(_ url: URL) async {
        self.isCancelled = true
        self.selectedFolderURL = url
        self.targetFolderPath = url.path

        try? await Task.sleep(nanoseconds: 100_000_000)
        self.scanFiles()
    }

    private var scanTask: Task<Void, Never>?

    func cancelScan() {
        isCancelled = true
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        scanProgress = 0.0
        scanStatusText = "스캔이 취소되었습니다."
    }

    func scanFiles() {
        guard let rootURL = selectedFolderURL else { return }

        cancelScan()
        isCancelled = false

        scanTask = Task {
            await self.startScanExecution(rootURL: rootURL)
        }
    }


    private func startScanExecution(rootURL: URL) async {
        isScanning = true
        hasScanned = false
        showDeleteSuccess = false
        scanProgress = 0.05
        scannedCount = 0
        matchedCount = 0
        scanStatusText = "대용량 파일 검색 시작..."

        let sizeLimit = Int64(sizeThresholdMB * 1024 * 1024)
        let calendar = Calendar.current
        let now = Date()
        let ageMonths = ageThresholdMonths

        let foundFiles = await Task.detached(priority: .userInitiated) { [weak self] () -> [LargeFileItem] in
            let fm = FileManager.default
            let isAccessed = rootURL.startAccessingSecurityScopedResource()
            defer {
                if isAccessed {
                    rootURL.stopAccessingSecurityScopedResource()
                }
            }

            var results: [LargeFileItem] = []
            let resourceKeys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey]
            guard let enumerator = fm.enumerator(
                at: rootURL,
                includingPropertiesForKeys: resourceKeys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: { _, _ in return true }
            ) else {
                return []
            }


            var totalScanned = 0
            var lastUIUpdate = Date()

            while let url = enumerator.nextObject() as? URL {
                if Task.isCancelled {
                    break
                }

                let path = url.path
                if path.contains("/Library") || path.contains("/.gemini") || path.contains("/System") {
                    continue
                }

                guard let resourceValues = try? url.resourceValues(forKeys: Set(resourceKeys)),
                      let isDir = resourceValues.isDirectory, !isDir,
                      let fileSize = resourceValues.fileSize,
                      let modDate = resourceValues.contentModificationDate else {
                    continue
                }

                totalScanned += 1

                if fileSize >= sizeLimit {
                    var matchesAge = true
                    if ageMonths > 0 {
                        if let limitDate = calendar.date(byAdding: .month, value: -ageMonths, to: now) {
                            matchesAge = modDate < limitDate
                        }
                    }

                    if matchesAge {
                        let item = LargeFileItem(
                            id: url.path,
                            url: url,
                            name: url.lastPathComponent,
                            size: Int64(fileSize),
                            lastModified: modDate
                        )
                        results.append(item)
                    }
                }

                if Date().timeIntervalSince(lastUIUpdate) > 0.08 {
                    lastUIUpdate = Date()
                    let scanned = totalScanned
                    let matched = results.count
                    let currentPath = url.lastPathComponent
                    await MainActor.run {
                        self?.scannedCount = scanned
                        self?.matchedCount = matched
                        self?.currentScanPath = currentPath
                        self?.scanStatusText = "대용량 파일 스캔 중... (\(scanned)개 탐색, \(matched)개 발견)"
                        self?.scanProgress = min(0.95, Double(scanned) / 10000.0 * 0.95)
                    }
                }
            }

            results.sort { $0.size > $1.size }
            return results
        }.value

        if !isCancelled {
            self.files = foundFiles
            self.scanProgress = 1.0
            self.isScanning = false
            self.hasScanned = true
        } else {
            self.isScanning = false
            self.scanProgress = 0.0
            self.scanStatusText = "스캔이 취소되었습니다."
        }

    }

    func deleteSelectedFiles() {
        let itemsToDelete = files.filter { $0.isSelected }
        guard !itemsToDelete.isEmpty else { return }

        isDeleting = true

        Task {
            var count = 0
            var totalSize: Int64 = 0

            let result = await Task.detached(priority: .userInitiated) { () -> (Int, Int64) in
                var localCount = 0
                var localSize: Int64 = 0
                for item in itemsToDelete {
                    let isAccessed = item.url.startAccessingSecurityScopedResource()
                    defer {
                        if isAccessed {
                            item.url.stopAccessingSecurityScopedResource()
                        }
                    }
                    if FileSafety.moveToTrash(item.url, treeProtection: true) {
                        localCount += 1
                        localSize += item.size
                    }
                }
                return (localCount, localSize)
            }.value
            count = result.0
            totalSize = result.1

            self.deletedCount = count
            self.deletedSize = totalSize
            self.isDeleting = false
            self.showDeleteSuccess = true
            self.scanFiles()
        }
    }
}
