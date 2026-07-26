import Foundation
import SwiftUI
import AppKit
import MacOptimizationCore

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
    /// node_modules·DerivedData 등 개발 캐시를 스캔에서 뺄지 여부.
    /// 기본 꺼짐 — 그 안의 대용량 바이너리도 실제로 디스크를 차지하므로, 숨기는 것은 사용자 선택이다.
    @Published var excludeDeveloperCaches: Bool {
        didSet { UserDefaults.standard.set(excludeDeveloperCaches, forKey: Self.excludeDevCachesKey) }
    }
    /// 진입 전에 가지치기한 디렉터리 수.
    @Published var prunedDirectoryCount: Int = 0

    private static let excludeDevCachesKey = "largeFilesExcludeDeveloperCaches"
    @Published var targetFolderPath: String = t("common.noFolderSelected")
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
        excludeDeveloperCaches = UserDefaults.standard.bool(forKey: Self.excludeDevCachesKey)

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
        scanStatusText = t("common.scanCancelled")
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
        scanStatusText = t("large.status.start")

        let sizeLimit = Int64(sizeThresholdMB * 1024 * 1024)
        let calendar = Calendar.current
        let now = Date()
        let ageMonths = ageThresholdMonths
        let skipDeveloperCaches = excludeDeveloperCaches
        let homeDirectory = NSHomeDirectory()

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
            var prunedDirectories = 0
            var lastUIUpdate = Date()

            while let url = enumerator.nextObject() as? URL {
                if Task.isCancelled {
                    break
                }

                guard let resourceValues = try? url.resourceValues(forKeys: Set(resourceKeys)) else {
                    continue
                }

                // 제외 대상은 진입 전에 가지치기한다. 이전 구현은 시스템·Library 트리를
                // 전부 열거한 뒤 결과만 버려서, 홈 전체 스캔에서 19만 항목의 비용을 그대로 냈다.
                if resourceValues.isDirectory == true {
                    var shouldPrune = ScanExclusion.isExcluded(path: url.path, homeDirectory: homeDirectory)
                    // 개발 캐시 제외는 선택 사항이다. 켜면 훨씬 빠르지만 node_modules 안의
                    // 100MB 넘는 바이너리가 결과에서 사라진다 — 실제로 디스크를 차지하는 파일이다.
                    if !shouldPrune && skipDeveloperCaches {
                        shouldPrune = ScanExclusion.shouldPruneDirectory(named: url.lastPathComponent)
                    }
                    if shouldPrune {
                        enumerator.skipDescendants()
                        prunedDirectories += 1
                    }
                    continue
                }

                guard let fileSize = resourceValues.fileSize,
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
                    await MainActor.run { [weak self] in
                        self?.scannedCount = scanned
                        self?.matchedCount = matched
                        self?.currentScanPath = currentPath
                        self?.scanStatusText = String(format: t("large.status.scanning"), scanned, matched)
                        self?.scanProgress = min(0.95, Double(scanned) / 10000.0 * 0.95)
                    }

                }
            }

            results.sort { $0.size > $1.size }
            let prunedTotal = prunedDirectories
            await MainActor.run { [weak self] in
                self?.prunedDirectoryCount = prunedTotal
            }
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
            self.scanStatusText = t("common.scanCancelled")
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
