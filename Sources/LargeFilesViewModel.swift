import Foundation
import SwiftUI
import AppKit

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
    @Published var files: [LargeFileItem] = []
    @Published var isScanning = false
    @Published var isDeleting = false
    @Published var sizeThresholdMB: Double = 100.0 // 기본 100MB
    @Published var ageThresholdMonths: Int = 0 // 0: 상관없음, 3: 3개월 이상, 6: 6개월 이상, 12: 1년 이상
    @Published var targetFolderPath: String = "선택된 폴더 없음"
    @Published var selectedFolderURL: URL? = nil
    @Published var hasScanned = false
    @Published var isCancelled = false
    
    @Published var showDeleteSuccess = false
    @Published var deletedSize: Int64 = 0
    @Published var deletedCount = 0
    
    init() {
        let defaultURL = SettingsViewModel.getSavedDefaultScanURL()
        selectedFolderURL = defaultURL
        targetFolderPath = defaultURL.path
    }
    
    func selectFolder() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = false
        openPanel.title = "스캔할 대상 폴더 선택"
        
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
    
    func scanFiles() {
        guard let rootURL = selectedFolderURL else { return }
        
        if isScanning {
            isCancelled = true
            Task {
                try? await Task.sleep(nanoseconds: 100_000_000)
                self.isCancelled = false
                await self.startScanExecution(rootURL: rootURL)
            }
        } else {
            isCancelled = false
            Task {
                await self.startScanExecution(rootURL: rootURL)
            }
        }
    }
    
    private func startScanExecution(rootURL: URL) async {
        isScanning = true
        showDeleteSuccess = false
        
        let sizeLimit = Int64(sizeThresholdMB * 1024 * 1024)
        let calendar = Calendar.current
        let now = Date()
        let ageMonths = ageThresholdMonths
        
        let foundFiles = await Task.detached(priority: .userInitiated) { () -> [LargeFileItem] in
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
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                return []
            }
            
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
            }
            
            results.sort { $0.size > $1.size }
            return results
        }.value
        
        if !isCancelled {
            self.files = foundFiles
            self.isScanning = false
            self.hasScanned = true
        }
    }
    
    func deleteSelectedFiles() {
        let itemsToDelete = files.filter { $0.isSelected }
        guard !itemsToDelete.isEmpty else { return }
        
        isDeleting = true
        
        Task {
            var count = 0
            var totalSize: Int64 = 0
            
            await Task.detached(priority: .userInitiated) {
                let fm = FileManager.default
                for item in itemsToDelete {
                    let isAccessed = item.url.startAccessingSecurityScopedResource()
                    defer {
                        if isAccessed {
                            item.url.stopAccessingSecurityScopedResource()
                        }
                    }
                    
                    do {
                        if !Self.isBlacklistedStatic(item.url.path) {
                            try fm.removeItem(at: item.url)
                            count += 1
                            totalSize += item.size
                        }
                    } catch {
                        print("대용량 파일 삭제 실패 (\(item.name)): \(error.localizedDescription)")
                    }
                }
            }.value
            
            self.deletedCount = count
            self.deletedSize = totalSize
            self.isDeleting = false
            self.showDeleteSuccess = true
            self.scanFiles()
        }
    }
    
    nonisolated private static func isBlacklistedStatic(_ path: String) -> Bool {
        let cleanPath = (path as NSString).standardizingPath.lowercased()
        let blacklistedPaths = [
            "/system", "/library", "/bin", "/sbin", "/usr", "/private", "/cores",
            "/users/shared/library", "/etc", "/var"
        ]
        return blacklistedPaths.contains { cleanPath.hasPrefix($0) }
    }
}
