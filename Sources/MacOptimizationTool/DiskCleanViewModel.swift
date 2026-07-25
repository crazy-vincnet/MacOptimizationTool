import Foundation
import SwiftUI
import AppKit
import MacOptimizationCore

struct JunkSubItem: Identifiable {
    let id: String // 파일/폴더의 경로
    let url: URL
    let name: String
    let size: Int64
    var isSelected: Bool = true
}

struct JunkCategory: Identifiable {
    let id: String
    let name: String
    let description: String
    let urls: [URL]
    var size: Int64 = 0
    var isSelected: Bool = true
    var subItems: [JunkSubItem] = [] // 하위 폴더/파일 상세 목록
    var isExpanded: Bool = false     // UI 펼침 상태
}

@MainActor
class DiskCleanViewModel: ObservableObject {
    static let shared = DiskCleanViewModel()

    @Published var categories: [JunkCategory] = []
    @Published var isScanning = false
    @Published var isCleaning = false
    @Published var showCleanSuccess = false
    @Published var totalJunkSize: Int64 = 0
    @Published var cleanedSize: Int64 = 0
    @Published var hasScanned = false

    // Real-Time Progress Tracking Properties
    @Published var scanProgress: Double = 0.0
    @Published var currentScanCategory: String = ""
    @Published var scanStatusText: String = ""
    @Published var scannedItemCount: Int = 0

    // 파일명 호환성 고도화 상태 변수들
    @Published var isFixingFilenames = false
    @Published var fixProgress: Double = 0.0
    @Published var showFixSuccess = false
    @Published var fixedCount = 0
    @Published var fixedHistory: [String] = []

    init() {
        resetCategories()
    }

    func resetCategories() {
        let fm = FileManager.default
        let userHome = fm.homeDirectoryForCurrentUser
        let userLibrary = userHome.appendingPathComponent("Library")

        categories = [
            JunkCategory(
                id: "userCaches",
                name: t("disk.cat.userCaches.name"),
                description: t("disk.cat.userCaches.desc"),
                urls: [userLibrary.appendingPathComponent("Caches")]
            ),
            JunkCategory(
                id: "userLogs",
                name: t("disk.cat.userLogs.name"),
                description: t("disk.cat.userLogs.desc"),
                urls: [userLibrary.appendingPathComponent("Logs")]
            ),
            JunkCategory(
                id: "systemCaches",
                name: t("disk.cat.systemCaches.name"),
                description: t("disk.cat.systemCaches.desc"),
                urls: [
                    URL(fileURLWithPath: "/Library/Caches"),
                    URL(fileURLWithPath: "/Library/Logs")
                ]
            ),
            JunkCategory(
                id: "xcodeData",
                name: t("disk.cat.xcodeData.name"),
                description: t("disk.cat.xcodeData.desc"),
                urls: [userLibrary.appendingPathComponent("Developer/Xcode/DerivedData")]
            ),
            JunkCategory(
                id: "trash",
                name: t("disk.cat.trash.name"),
                description: t("disk.cat.trash.desc"),
                urls: [userHome.appendingPathComponent(".Trash")]
            )
        ]
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

    func scanJunk() {
        cancelScan()
        isCancelled = false
        isScanning = true
        showCleanSuccess = false
        scanProgress = 0.05
        scannedItemCount = 0
        scanStatusText = t("disk.status.scanStart")
        resetCategories()

        let localCategories = categories
        let totalCategoriesCount = localCategories.count

        scanTask = Task {
            let updatedCategories = await Task.detached(priority: .userInitiated) { [weak self] () -> [JunkCategory] in
                var results = localCategories
                let fm = FileManager.default
                var totalFoundCount = 0

                for (index, cat) in localCategories.enumerated() {
                    if Task.isCancelled { break }

                    let catName = cat.name
                    await MainActor.run { [weak self] in
                        self?.currentScanCategory = catName
                        self?.scanStatusText = String(format: t("disk.status.scanningCategory"), catName)
                        self?.scanProgress = 0.05 + (Double(index) / Double(totalCategoriesCount) * 0.90)
                    }

                    var subItems: [JunkSubItem] = []
                    var totalSize: Int64 = 0

                    for url in cat.urls {
                        if Task.isCancelled { break }

                        let isAccessed = url.startAccessingSecurityScopedResource()
                        defer {
                            if isAccessed {
                                url.stopAccessingSecurityScopedResource()
                            }
                        }

                        let contents = (try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])) ?? []
                        for childURL in contents {
                            if Task.isCancelled { break }

                            let childSize = Self.getDirectorySizeStatic(at: childURL)
                            if childSize > 1024 {
                                let name = childURL.lastPathComponent
                                let subItem = JunkSubItem(id: childURL.path, url: childURL, name: name, size: childSize)
                                subItems.append(subItem)
                                totalSize += childSize
                                totalFoundCount += 1
                            }
                        }
                    }

                    subItems.sort { $0.size > $1.size }
                    results[index].subItems = subItems
                    results[index].size = totalSize

                    let count = totalFoundCount
                    await MainActor.run { [weak self] in
                        self?.scannedItemCount = count
                    }
                }


                return results
            }.value

            if !self.isCancelled {
                self.categories = updatedCategories
                self.recalculateTotalSize()
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


    func toggleCategorySelection(at index: Int) {
        let newValue = !categories[index].isSelected
        categories[index].isSelected = newValue
        for subIndex in categories[index].subItems.indices {
            categories[index].subItems[subIndex].isSelected = newValue
        }
        recalculateTotalSize()
    }

    func toggleSubItemSelection(categoryIndex: Int, subItemIndex: Int) {
        let newValue = !categories[categoryIndex].subItems[subItemIndex].isSelected
        categories[categoryIndex].subItems[subItemIndex].isSelected = newValue

        let hasSelected = categories[categoryIndex].subItems.contains { $0.isSelected }
        categories[categoryIndex].isSelected = hasSelected
        recalculateTotalSize()
    }

    func recalculateTotalSize() {
        var total: Int64 = 0
        for cat in categories {
            for sub in cat.subItems {
                if sub.isSelected {
                    total += sub.size
                }
            }
        }
        totalJunkSize = total
    }

    func cleanJunk() {
        var itemsToDelete: [JunkSubItem] = []
        for cat in categories {
            itemsToDelete.append(contentsOf: cat.subItems.filter { $0.isSelected })
        }

        guard !itemsToDelete.isEmpty else { return }
        isCleaning = true

        // 백그라운드 태스크로 넘길 값은 불변 복사본으로 고정한다.
        let deletionTargets = itemsToDelete

        Task {
            let totalCleaned = await Task.detached(priority: .userInitiated) { () -> Int64 in
                var cleaned: Int64 = 0

                for item in deletionTargets {
                    let url = item.url
                    let isAccessed = url.startAccessingSecurityScopedResource()
                    defer {
                        if isAccessed {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }

                    if FileSafety.moveToTrash(url) {
                        cleaned += item.size
                    }
                }
                return cleaned
            }.value

            self.cleanedSize = totalCleaned
            self.isCleaning = false
            self.showCleanSuccess = true
            self.scanJunk()
        }
    }

    func runWindowsFilenameFixer() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = []
        openPanel.allowsMultipleSelection = true
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = true
        openPanel.title = t("wincompat.panelTitle")
        openPanel.prompt = t("wincompat.panelPrompt")

        openPanel.begin { [weak self] response in
            guard let self = self else { return }
            if response == .OK && !openPanel.urls.isEmpty {
                let selectedURLs = openPanel.urls
                Task {
                    await self.startWindowsFilenameFix(for: selectedURLs)
                }
            }
        }
    }

    private func startWindowsFilenameFix(for urls: [URL]) async {
        isFixingFilenames = true
        showFixSuccess = false
        fixProgress = 0.0

        let result = await Task.detached(priority: .userInitiated) { () -> (Int, [String]) in
            let fm = FileManager.default
            var renamedCount = 0
            var renamedPaths: [String] = []
            var itemsToProcess: Set<URL> = []

            for url in urls {
                let isAccessed = url.startAccessingSecurityScopedResource()
                defer {
                    if isAccessed {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                var isDir: ObjCBool = false
                if fm.fileExists(atPath: url.path, isDirectory: &isDir) {
                    if isDir.boolValue {
                        itemsToProcess.insert(url)
                        if let enumerator = fm.enumerator(
                            at: url,
                            includingPropertiesForKeys: [.isDirectoryKey],
                            options: [.skipsHiddenFiles]
                        ) {
                            while let childURL = enumerator.nextObject() as? URL {
                                itemsToProcess.insert(childURL)
                            }
                        }
                    } else {
                        itemsToProcess.insert(url)
                    }
                }
            }

            var itemsArray = Array(itemsToProcess)
            itemsArray.sort { $0.path.count > $1.path.count }

            let totalItems = itemsArray.count
            for (index, url) in itemsArray.enumerated() {
                let isAccessed = url.startAccessingSecurityScopedResource()
                defer {
                    if isAccessed {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                let originalName = url.lastPathComponent
                let nfcName = originalName.precomposedStringWithCanonicalMapping

                if originalName != nfcName {
                    let destinationURL = url.deletingLastPathComponent().appendingPathComponent(nfcName)
                    do {
                        try fm.moveItem(at: url, to: destinationURL)
                        renamedCount += 1
                        renamedPaths.append("\(originalName) ➔ \(nfcName)")
                    } catch {
                        print("자모 복구 이름 변경 실패: \(url.path), 에러: \(error.localizedDescription)")
                    }
                }

                let progressValue = totalItems > 0 ? Double(index + 1) / Double(totalItems) : 1.0
                Task { @MainActor [weak self] in
                    self?.fixProgress = progressValue
                }
            }

            return (renamedCount, renamedPaths)
        }.value

        self.fixedCount = result.0
        self.fixedHistory = result.1
        self.isFixingFilenames = false
        self.showFixSuccess = true
    }

    nonisolated private static func getDirectorySizeStatic(at url: URL) -> Int64 {
        let fm = FileManager.default
        var size: Int64 = 0
        var isDir: ObjCBool = false

        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }

        if !isDir.boolValue {
            var statInfo = stat()
            if lstat(url.path, &statInfo) == 0 {
                size = Int64(statInfo.st_size)
            }
        } else {
            let keys: [URLResourceKey] = [.fileSizeKey, .isDirectoryKey]
            guard let enumerator = fm.enumerator(
                at: url,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: { _, _ in return true }
            ) else {

                return 0
            }
            while let fileURL = enumerator.nextObject() as? URL {
                if let resourceValues = try? fileURL.resourceValues(forKeys: Set(keys)) {
                    if let isDirectory = resourceValues.isDirectory, !isDirectory,
                       let fileSize = resourceValues.fileSize {
                        size += Int64(fileSize)
                    }
                }
            }
        }
        return size
    }
}
