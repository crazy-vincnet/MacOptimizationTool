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
    static let shared = DuplicateViewModel()

    @Published var groups: [DuplicateGroup] = []

    @Published var isScanning = false
    @Published var isDeleting = false
    @Published var targetFolderPath: String = "선택된 폴더 없음"
    @Published var selectedFolderURL: URL? = nil
    @Published var hasScanned = false
    @Published var isCancelled = false
    
    // Real-Time Progress Tracking Properties
    @Published var scanProgress: Double = 0.0
    @Published var scannedCount: Int = 0
    @Published var candidateCount: Int = 0
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
    
    func selectFolder() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = false
        openPanel.title = t("dup.panelTitle")
        
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
        hasScanned = false
        showDeleteSuccess = false
        scanProgress = 0.05
        scannedCount = 0
        candidateCount = 0
        scanStatusText = "디렉토리 탐색 및 파일 정보 수집 중..."
        
        let foundGroups = await Task.detached(priority: .userInitiated) { [weak self] () -> [DuplicateGroup] in
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
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: { _, _ in return true }
            ) else {
                return []
            }

            
            var totalFiles = 0
            var lastUIUpdate = Date()
            
            // 1단계: 전체 파일 탐색 및 크기별 1차 그룹화
            while let url = enumerator.nextObject() as? URL {
                if Task.isCancelled { break }
                
                let path = url.path
                if path.contains("/Library") || path.contains("/.gemini") || path.contains("/System") {
                    continue
                }
                
                guard let resourceValues = try? url.resourceValues(forKeys: Set(resourceKeys)),
                      let isDir = resourceValues.isDirectory, !isDir,
                      let fileSize = resourceValues.fileSize, fileSize > 2048 else {
                    continue
                }
                
                totalFiles += 1
                sizeToURLs[Int64(fileSize), default: []].append(url)
                
                if Date().timeIntervalSince(lastUIUpdate) > 0.1 {
                    lastUIUpdate = Date()
                    let count = totalFiles
                    let currentPath = url.lastPathComponent
                    await MainActor.run {
                        self?.scannedCount = count
                        self?.currentScanPath = currentPath
                        self?.scanStatusText = "파일 탐색 중... (\(count)개 수집 완료)"
                        self?.scanProgress = min(0.35, Double(count) / 10000.0 * 0.35)
                    }
                }
            }
            
            if Task.isCancelled { return [] }
            
            // 2단계: 동일 크기 파일들만 추출하여 1단계 16KB 고속 부분 해시 비교
            var sameSizeCandidates: [[URL]] = []
            var totalCandidatesCount = 0
            for (_, urls) in sizeToURLs {
                if urls.count > 1 {
                    sameSizeCandidates.append(urls)
                    totalCandidatesCount += urls.count
                }
            }
            
            await MainActor.run {
                self?.candidateCount = totalCandidatesCount
                self?.scanProgress = 0.40
                self?.scanStatusText = "고속 해시 1차 검증 중... (대상: \(totalCandidatesCount)개 파일)"
            }
            
            var partialHashGroups: [String: [URL]] = [:]
            var processedCandidateCount = 0
            
            for urls in sameSizeCandidates {
                if Task.isCancelled { break }
                for url in urls {
                    if Task.isCancelled { break }
                    if let partialHash = FileSafety.partialFileHash(for: url) {
                        let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                        let key = "\(fileSize)_\(partialHash)"
                        partialHashGroups[key, default: []].append(url)
                    }
                    
                    processedCandidateCount += 1
                    if Date().timeIntervalSince(lastUIUpdate) > 0.08 {
                        lastUIUpdate = Date()
                        let processed = processedCandidateCount
                        let total = max(1, totalCandidatesCount)
                        let currentPath = url.lastPathComponent
                        await MainActor.run {
                            self?.currentScanPath = currentPath
                            self?.scanProgress = 0.40 + (Double(processed) / Double(total) * 0.35)
                            self?.scanStatusText = "1차 고속 해시 비교 중... (\(processed)/\(total))"
                        }
                    }
                }
            }
            
            if Task.isCancelled { return [] }
            
            // 3단계: 1단계 부분 해시까지 100% 동일한 후보만 2단계 전체 SHA-256 해시 최종 검증
            var finalDuplicateMap: [String: [URL]] = [:]
            var fullHashCandidates: [[URL]] = []
            var totalFullHashCount = 0
            for (_, urls) in partialHashGroups {
                if urls.count > 1 {
                    fullHashCandidates.append(urls)
                    totalFullHashCount += urls.count
                }
            }
            
            await MainActor.run {
                self?.scanProgress = 0.75
                self?.scanStatusText = "정밀 2차 SHA-256 검증 중... (대상: \(totalFullHashCount)개 파일)"
            }
            
            var processedFullCount = 0
            for urls in fullHashCandidates {
                if Task.isCancelled { break }
                for url in urls {
                    if Task.isCancelled { break }
                    if let fullHash = FileSafety.fullFileHash(for: url) {
                        let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                        let key = "\(fileSize)_\(fullHash)"
                        finalDuplicateMap[key, default: []].append(url)
                    }
                    
                    processedFullCount += 1
                    if Date().timeIntervalSince(lastUIUpdate) > 0.08 {
                        lastUIUpdate = Date()
                        let processed = processedFullCount
                        let total = max(1, totalFullHashCount)
                        let currentPath = url.lastPathComponent
                        await MainActor.run {
                            self?.currentScanPath = currentPath
                            self?.scanProgress = 0.75 + (Double(processed) / Double(total) * 0.23)
                            self?.scanStatusText = "정밀 해시 최종 검증 중... (\(processed)/\(total))"
                        }
                    }
                }
            }
            
            if Task.isCancelled { return [] }
            
            // 4단계: 중복 그룹 생성 및 용량순 정렬
            var duplicateGroups: [DuplicateGroup] = []
            for (key, urls) in finalDuplicateMap {
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
            self.scanProgress = 1.0
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
