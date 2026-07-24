import Foundation
import SwiftUI
import AppKit

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
    @Published var categories: [JunkCategory] = []
    @Published var isScanning = false
    @Published var isCleaning = false
    @Published var showCleanSuccess = false
    @Published var totalJunkSize: Int64 = 0
    @Published var cleanedSize: Int64 = 0
    @Published var hasScanned = false
    
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
                name: "사용자 캐시 파일",
                description: "앱 임시 보관 데이터로, 삭제 시 재다운로드 혹은 로드됩니다.",
                urls: [userLibrary.appendingPathComponent("Caches")]
            ),
            JunkCategory(
                id: "userLogs",
                name: "사용자 시스템 로그",
                description: "앱 크래시나 작동 추적 일지 파일로, 보관할 필요가 없습니다.",
                urls: [userLibrary.appendingPathComponent("Logs")]
            ),
            JunkCategory(
                id: "systemCaches",
                name: "시스템 캐시 & 로그",
                description: "OS 공용으로 저장된 로그 및 공유 자원 임시 파일입니다.",
                urls: [
                    URL(fileURLWithPath: "/Library/Caches"),
                    URL(fileURLWithPath: "/Library/Logs")
                ]
            ),
            JunkCategory(
                id: "xcodeData",
                name: "Xcode 개발자 DerivedData",
                description: "Xcode 개발 찌꺼기 파일로 개발 시 언제든지 재생성되는 용량 먹는 데이터입니다.",
                urls: [userLibrary.appendingPathComponent("Developer/Xcode/DerivedData")]
            ),
            JunkCategory(
                id: "trash",
                name: "시스템 휴지통",
                description: "사용자가 임의로 삭제하여 휴지통에 들어간 실제 파일들입니다.",
                urls: [userHome.appendingPathComponent(".Trash")]
            )
        ]
    }
    
    func scanJunk() {
        isScanning = true
        showCleanSuccess = false
        resetCategories()
        
        let localCategories = categories
        
        Task {
            // TaskGroup을 사용하여 비동기 병렬 스캔 처리 (최신 Swift Concurrency 표준)
            let updatedCategories = await withTaskGroup(of: (Int, [JunkSubItem], Int64).self) { group in
                for (index, cat) in localCategories.enumerated() {
                    group.addTask(priority: .userInitiated) {
                        let fm = FileManager.default
                        var subItems: [JunkSubItem] = []
                        var totalSize: Int64 = 0
                        
                        for url in cat.urls {
                            let isAccessed = url.startAccessingSecurityScopedResource()
                            defer {
                                if isAccessed {
                                    url.stopAccessingSecurityScopedResource()
                                }
                            }
                            
                            let contents = (try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])) ?? []
                            for childURL in contents {
                                let childSize = Self.getDirectorySizeStatic(at: childURL)
                                if childSize > 1024 {
                                    let name = childURL.lastPathComponent
                                    let subItem = JunkSubItem(id: childURL.path, url: childURL, name: name, size: childSize)
                                    subItems.append(subItem)
                                    totalSize += childSize
                                }
                            }
                        }
                        
                        subItems.sort { $0.size > $1.size }
                        return (index, subItems, totalSize)
                    }
                }
                
                var results = localCategories
                for await (index, subItems, totalSize) in group {
                    results[index].subItems = subItems
                    results[index].size = totalSize
                }
                return results
            }
            
            self.categories = updatedCategories
            self.recalculateTotalSize()
            self.isScanning = false
            self.hasScanned = true
        }
    }
    
    // 카테고리 전체 체크/체크해제 시 하위 항목 일괄 동기화
    func toggleCategorySelection(at index: Int) {
        let newValue = !categories[index].isSelected
        categories[index].isSelected = newValue
        for subIndex in categories[index].subItems.indices {
            categories[index].subItems[subIndex].isSelected = newValue
        }
        recalculateTotalSize()
    }
    
    // 하위 개별 항목 체크 상태 변경
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
        
        Task {
            let totalCleaned = await Task.detached(priority: .userInitiated) { () -> Int64 in
                let fm = FileManager.default
                var cleaned: Int64 = 0
                
                for item in itemsToDelete {
                    let url = item.url
                    let isAccessed = url.startAccessingSecurityScopedResource()
                    defer {
                        if isAccessed {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }
                    
                    do {
                        let path = url.standardized.path
                        if !Self.isBlacklistedStatic(path) {
                            try fm.removeItem(at: url)
                            cleaned += item.size
                        }
                    } catch {
                        print("파일 제거 실패: \(url.path), 에러: \(error.localizedDescription)")
                    }
                }
                return cleaned
            }.value
            
            self.cleanedSize = totalCleaned
            self.isCleaning = false
            self.showCleanSuccess = true
            self.scanJunk() // 정리 완료 후 화면 갱신
        }
    }
    
    // Windows 한글 자모 풀림 문제 해결 메서드 (다중 파일 및 폴더 동시 지원)
    func runWindowsFilenameFixer() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = []
        openPanel.allowsMultipleSelection = true
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = true
        openPanel.title = "호환성 검사할 파일 또는 폴더 선택"
        openPanel.prompt = "선택 완료"
        
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
                            // NSEnumerator while-nextObject 구조로 변경하여 Sendability 준수
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
    
    nonisolated private static func isBlacklistedStatic(_ path: String) -> Bool {
        let cleanPath = (path as NSString).standardizingPath.lowercased()
        let systemBlacklist = [
            "/", "/system", "/library", "/applications", "/users",
            "/private", "/var", "/etc", "/bin", "/sbin", "/usr", "/dev", "/volumes"
        ]
        
        if systemBlacklist.contains(cleanPath) {
            return true
        }
        
        let homePath = FileManager.default.homeDirectoryForCurrentUser.standardized.path.lowercased()
        let userBlacklist = [
            homePath,
            homePath + "/library",
            homePath + "/desktop",
            homePath + "/documents",
            homePath + "/downloads",
            homePath + "/applications",
            homePath + "/movies",
            homePath + "/music",
            homePath + "/pictures"
        ]
        
        if userBlacklist.contains(cleanPath) {
            return true
        }
        
        return false
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
                errorHandler: nil
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
