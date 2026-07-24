import Foundation
import SwiftUI
import AppKit

struct DuplicateFileInstance: Identifiable, Hashable {
    let id: String // 파일 경로
    let url: URL
    let lastModified: Date
    var isSelected: Bool // 삭제 타겟 여부
}

struct DuplicateGroup: Identifiable, Hashable {
    let id: String // 크기 + 해시값의 고유 키
    let name: String // 파일명
    let size: Int64 // 개별 파일 크기
    var instances: [DuplicateFileInstance] // 중복 복제본 파일 인스턴스 배열
}

@MainActor
class DuplicateViewModel: ObservableObject {
    @Published var groups: [DuplicateGroup] = []
    @Published var isScanning = false
    @Published var isDeleting = false
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
        openPanel.title = "중복 스캔할 대상 폴더 선택"
        
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
        self.scanDuplicates()
    }
    
    func scanDuplicates() {
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
        
        let foundGroups = await Task.detached(priority: .userInitiated) { () -> [DuplicateGroup] in
            let fm = FileManager.default
            
            let isAccessed = rootURL.startAccessingSecurityScopedResource()
            defer {
                if isAccessed {
                    rootURL.stopAccessingSecurityScopedResource()
                }
            }
            
            var sizeToURLs: [Int64: [URL]] = [:]
            let resourceKeys: [URLResourceKey] = [.fileSizeKey, .isDirectoryKey]
            
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
                      let fileSize = resourceValues.fileSize, fileSize > 1024 else {
                    continue
                }
                
                sizeToURLs[Int64(fileSize), default: []].append(url)
            }
            
            if Task.isCancelled { return [] }
            
            var potentialDuplicates: [String: [URL]] = [:]
            for (size, urls) in sizeToURLs {
                if Task.isCancelled { break }
                if urls.count > 1 {
                    for url in urls {
                        if Task.isCancelled { break }
                        if let hash = FileSafety.fullFileHash(for: url) {
                            let key = "\(size)_\(hash)"
                            potentialDuplicates[key, default: []].append(url)
                        }
                    }
                }
            }
            
            if Task.isCancelled { return [] }
            
            var duplicateGroups: [DuplicateGroup] = []
            for (key, urls) in potentialDuplicates {
                if Task.isCancelled { break }
                if urls.count > 1 {
                    let firstURL = urls[0]
                    let size = Int64(key.split(separator: "_")[0]) ?? 0
                    
                    var instances: [DuplicateFileInstance] = []
                    for (index, url) in urls.enumerated() {
                        let attr = try? fm.attributesOfItem(atPath: url.path)
                        let modDate = (attr?[.modificationDate] as? Date) ?? Date()
                        let isSelected = index > 0
                        
                        let instance = DuplicateFileInstance(
                            id: url.path,
                            url: url,
                            lastModified: modDate,
                            isSelected: isSelected
                        )
                        instances.append(instance)
                    }
                    
                    let group = DuplicateGroup(
                        id: key,
                        name: firstURL.lastPathComponent,
                        size: size,
                        instances: instances
                    )
                    duplicateGroups.append(group)
                }
            }
            
            duplicateGroups.sort { $0.size > $1.size }
            return duplicateGroups
        }.value
        
        if !isCancelled {
            self.groups = foundGroups
            self.isScanning = false
            self.hasScanned = true
        }
    }
    
    func deleteSelectedDuplicates() {
        var itemsToDelete: [DuplicateFileInstance] = []
        for group in groups {
            itemsToDelete.append(contentsOf: group.instances.filter { $0.isSelected })
        }
        
        guard !itemsToDelete.isEmpty else { return }
        isDeleting = true
        
        Task {
            let count = await Task.detached(priority: .userInitiated) { () -> Int in
                var localCount = 0
                for item in itemsToDelete {
                    let isAccessed = item.url.startAccessingSecurityScopedResource()
                    defer {
                        if isAccessed {
                            item.url.stopAccessingSecurityScopedResource()
                        }
                    }
                    if FileSafety.moveToTrash(item.url, treeProtection: true) {
                        localCount += 1
                    }
                }
                return localCount
            }.value

            self.deletedCount = count
            self.isDeleting = false
            self.showDeleteSuccess = true
            self.scanDuplicates()
        }
    }
}
