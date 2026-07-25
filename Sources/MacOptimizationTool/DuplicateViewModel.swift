import Foundation
import SwiftUI
import AppKit
import MacOptimizationCore

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
    @Published var targetFolderPath: String = t("common.noFolderSelected")
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
    
    private var scanTask: Task<Void, Never>?

    func cancelScan() {
        isCancelled = true
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        scanProgress = 0.0
        scanStatusText = t("common.scanCancelled")
    }

    func scanDuplicates() {
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
        candidateCount = 0
        scanStatusText = t("dup.status.collecting")
        
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
                    await MainActor.run { [weak self] in
                        self?.scannedCount = count
                        self?.currentScanPath = currentPath
                        self?.scanStatusText = String(format: t("dup.status.scanning"), count)
                        self?.scanProgress = min(0.35, Double(count) / 10000.0 * 0.35)
                    }
                }
            }
            
            if Task.isCancelled { return [] }
            
            // 2단계: 동일 크기 파일들만 추출하여 1단계 8KB 병렬 초고속 부분 해시 비교
            var sameSizeCandidates: [(url: URL, size: Int64)] = []
            var totalCandidatesCount = 0
            for (size, urls) in sizeToURLs {
                if urls.count > 1 {
                    for u in urls {
                        sameSizeCandidates.append((url: u, size: size))
                    }
                    totalCandidatesCount += urls.count
                }
            }
            
            let candCount = totalCandidatesCount
            await MainActor.run { [weak self] in
                self?.candidateCount = candCount
                self?.scanProgress = 0.40
                self?.scanStatusText = String(format: t("dup.status.hash1Start"), candCount)
            }

            
            var partialHashGroups: [String: [URL]] = [:]
            var processedCandidateCount = 0
            
            await withTaskGroup(of: (URL, Int64, String?).self) { group in
                let maxConcurrency = 16
                var index = 0

                while index < sameSizeCandidates.count && index < maxConcurrency {
                    let item = sameSizeCandidates[index]
                    index += 1
                    group.addTask {
                        let hash = FileSafety.partialFileHash(for: item.url)
                        return (item.url, item.size, hash)
                    }
                }

                while let (url, size, hashOpt) = await group.next() {
                    if Task.isCancelled { break }

                    if let partialHash = hashOpt {
                        let key = "\(size)_\(partialHash)"
                        partialHashGroups[key, default: []].append(url)
                    }

                    processedCandidateCount += 1

                    if index < sameSizeCandidates.count {
                        let item = sameSizeCandidates[index]
                        index += 1
                        group.addTask {
                            let hash = FileSafety.partialFileHash(for: item.url)
                            return (item.url, item.size, hash)
                        }
                    }

                    if Date().timeIntervalSince(lastUIUpdate) > 0.05 {
                        lastUIUpdate = Date()
                        let processed = processedCandidateCount
                        let total = max(1, totalCandidatesCount)
                        let currentPath = url.lastPathComponent
                        await MainActor.run { [weak self] in
                            self?.currentScanPath = currentPath
                            self?.scanProgress = 0.40 + (Double(processed) / Double(total) * 0.35)
                            self?.scanStatusText = String(format: t("dup.status.hash1Progress"), processed, total)
                        }

                    }
                }
            }
            
            if Task.isCancelled { return [] }
            
            // 3단계: 1단계 부분 해시까지 100% 동일한 후보만 2단계 병렬 SHA-256 해시 최종 검증
            var finalDuplicateMap: [String: [URL]] = [:]
            var fullHashCandidates: [(url: URL, size: Int64)] = []
            var totalFullHashCount = 0
            for (key, urls) in partialHashGroups {
                if urls.count > 1 {
                    let sizeStr = key.components(separatedBy: "_").first ?? "0"
                    let size = Int64(sizeStr) ?? 0
                    for u in urls {
                        fullHashCandidates.append((url: u, size: size))
                    }
                    totalFullHashCount += urls.count
                }
            }
            
            let fullCount = totalFullHashCount
            await MainActor.run { [weak self] in
                self?.scanProgress = 0.75
                self?.scanStatusText = String(format: t("dup.status.hash2Start"), fullCount)
            }

            
            var processedFullCount = 0
            await withTaskGroup(of: (URL, Int64, String?).self) { group in
                let maxConcurrency = 16
                var index = 0

                while index < fullHashCandidates.count && index < maxConcurrency {
                    let item = fullHashCandidates[index]
                    index += 1
                    group.addTask {
                        let hash = FileSafety.fullFileHash(for: item.url)
                        return (item.url, item.size, hash)
                    }
                }

                while let (url, size, hashOpt) = await group.next() {
                    if Task.isCancelled { break }

                    if let fullHash = hashOpt {
                        let key = "\(size)_\(fullHash)"
                        finalDuplicateMap[key, default: []].append(url)
                    }

                    processedFullCount += 1

                    if index < fullHashCandidates.count {
                        let item = fullHashCandidates[index]
                        index += 1
                        group.addTask {
                            let hash = FileSafety.fullFileHash(for: item.url)
                            return (item.url, item.size, hash)
                        }
                    }

                    if Date().timeIntervalSince(lastUIUpdate) > 0.05 {
                        lastUIUpdate = Date()
                        let processed = processedFullCount
                        let total = max(1, totalFullHashCount)
                        let currentPath = url.lastPathComponent
                        await MainActor.run { [weak self] in
                            self?.currentScanPath = currentPath
                            self?.scanProgress = 0.75 + (Double(processed) / Double(total) * 0.23)
                            self?.scanStatusText = String(format: t("dup.status.hash2Progress"), processed, total)
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
        } else {
            self.isScanning = false
            self.scanProgress = 0.0
            self.scanStatusText = t("common.scanCancelled")
        }

    }
    
    func deleteSelectedDuplicates() {
        var itemsToDelete: [DuplicateFileInstance] = []
        for group in groups {
            itemsToDelete.append(contentsOf: group.instances.filter { $0.isSelected })
        }
        
        guard !itemsToDelete.isEmpty else { return }
        isDeleting = true

        // 백그라운드 태스크로 넘길 값은 불변 복사본으로 고정한다.
        let deletionTargets = itemsToDelete

        Task {
            let count = await Task.detached(priority: .userInitiated) { () -> Int in
                var localCount = 0
                for item in deletionTargets {
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
