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

/// 탐색 단계에서 모은 후보. 해시 캐시 키에 수정 시각이 필요하므로 함께 들고 다닌다.
struct ScanCandidate: Sendable {
    let url: URL
    let size: Int64
    let modified: Date
}

/// 해시 워커의 반환값.
struct HashResult: Sendable {
    let candidate: ScanCandidate
    let hash: String?
}

/// 스캔 결과와 함께, 사용자에게 설명해야 하는 부수 정보를 돌려준다.
struct ScanOutcome: Sendable {
    let groups: [DuplicateGroup]
    let prunedDirectories: Int
    let hardLinkSkipped: Int
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

    /// 후보 최소 크기. 회수량은 큰 파일에서 나오고, 하한이 낮으면 해시 대상만 폭증한다.
    @Published var minimumSize: DuplicateMinimumSize {
        didSet { UserDefaults.standard.set(minimumSize.rawValue, forKey: Self.minimumSizeKey) }
    }

    /// 빠른 검사는 24KB 샘플 해시까지만, 정밀 검사는 전체 SHA-256 까지 본다.
    @Published var scanMode: DuplicateScanMode {
        didSet { UserDefaults.standard.set(scanMode.rawValue, forKey: Self.scanModeKey) }
    }

    /// 스캔 범위 프리셋. 전체 디스크를 훑지 않게 하는 가장 직접적인 수단이다.
    @Published var scanScope: DuplicateScanScope = .custom

    /// 하드링크로 접힌 항목 수. 사용자에게 "왜 개수가 줄었나" 를 설명할 수 있어야 한다.
    @Published var hardLinkSkippedCount: Int = 0
    /// 가지치기로 건너뛴 디렉터리 수.
    @Published var prunedDirectoryCount: Int = 0

    private static let minimumSizeKey = "duplicateMinimumSizeBytes"
    private static let scanModeKey = "duplicateScanMode"

    init() {
        let defaults = UserDefaults.standard
        let storedSize = defaults.object(forKey: Self.minimumSizeKey) as? Int64
        minimumSize = storedSize.flatMap(DuplicateMinimumSize.init(rawValue:)) ?? .medium
        let storedMode = defaults.string(forKey: Self.scanModeKey)
        scanMode = storedMode.flatMap(DuplicateScanMode.init(rawValue:)) ?? .fast

        let defaultURL = SettingsViewModel.getSavedDefaultScanURL()
        selectedFolderURL = defaultURL
        targetFolderPath = defaultURL.path
    }

    /// 프리셋을 고르면 해당 폴더로 대상을 바꾼다.
    func applyScope(_ scope: DuplicateScanScope) {
        scanScope = scope
        guard let url = scope.url() else { return }
        selectedFolderURL = url
        targetFolderPath = url.path
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
        self.scanScope = .custom
        
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
        
        // 백그라운드로 넘길 설정은 값으로 고정한다.
        let minimumBytes = minimumSize.bytes
        let mode = scanMode
        let workerCount = ScanConcurrency.recommended
        let homeDirectory = NSHomeDirectory()

        let outcome = await Task.detached(priority: .userInitiated) { [weak self] () -> ScanOutcome in
            let fm = FileManager.default
            let cache = HashCache.shared

            let isAccessed = rootURL.startAccessingSecurityScopedResource()
            defer {
                if isAccessed {
                    rootURL.stopAccessingSecurityScopedResource()
                }
            }

            var sizeToFiles: [Int64: [ScanCandidate]] = [:]
            let resourceKeys: [URLResourceKey] = [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey]
            let keySet = Set(resourceKeys)

            guard let enumerator = fm.enumerator(
                at: rootURL,
                includingPropertiesForKeys: resourceKeys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: { _, _ in return true }
            ) else {
                return ScanOutcome(groups: [], prunedDirectories: 0, hardLinkSkipped: 0)
            }

            var totalFiles = 0
            var prunedDirectories = 0
            var lastUIUpdate = Date()

            // 1단계: 파일 탐색 및 크기별 1차 그룹화.
            // 제외 대상 디렉터리는 **진입 전에** 가지치기한다. 이전 구현은 그 안을 전부
            // 열거한 뒤 결과만 버려서 ~/Library·node_modules 의 수십만 파일 비용을 그대로 냈다.
            while let url = enumerator.nextObject() as? URL {
                if Task.isCancelled { break }

                guard let resourceValues = try? url.resourceValues(forKeys: keySet) else { continue }

                if resourceValues.isDirectory == true {
                    if ScanExclusion.shouldPruneDirectory(named: url.lastPathComponent)
                        || ScanExclusion.isExcluded(path: url.path, homeDirectory: homeDirectory) {
                        enumerator.skipDescendants()
                        prunedDirectories += 1
                    }
                    continue
                }

                guard let fileSize = resourceValues.fileSize, Int64(fileSize) >= minimumBytes else {
                    continue
                }

                totalFiles += 1
                sizeToFiles[Int64(fileSize), default: []].append(
                    ScanCandidate(url: url,
                                  size: Int64(fileSize),
                                  modified: resourceValues.contentModificationDate ?? Date(timeIntervalSince1970: 0))
                )

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

            if Task.isCancelled { return ScanOutcome(groups: [], prunedDirectories: prunedDirectories, hardLinkSkipped: 0) }

            // 2단계: 같은 크기 파일만 추려 24KB 샘플 해시(앞·중간·뒤)를 병렬 계산한다.
            var sameSizeCandidates: [ScanCandidate] = []
            for (_, files) in sizeToFiles where files.count > 1 {
                sameSizeCandidates.append(contentsOf: files)
            }
            let totalCandidatesCount = sameSizeCandidates.count
            
            let candCount = totalCandidatesCount
            await MainActor.run { [weak self] in
                self?.candidateCount = candCount
                self?.scanProgress = 0.40
                self?.scanStatusText = String(format: t("dup.status.hash1Start"), candCount)
            }

            
            var sampledGroups: [String: [ScanCandidate]] = [:]
            var processedCandidateCount = 0
            // 빠른 검사는 이 단계가 마지막이므로 진행률 구간을 더 넓게 잡는다.
            let sampleProgressSpan = mode == .fast ? 0.58 : 0.35

            await withTaskGroup(of: HashResult.self) { group in
                var index = 0

                while index < sameSizeCandidates.count && index < workerCount {
                    let item = sameSizeCandidates[index]
                    index += 1
                    group.addTask {
                        let key = HashCacheKey(path: item.url.path, size: item.size, modified: item.modified, kind: .sampled)
                        let hash = cache.value(for: key) { FileSafety.sampledFileHash(for: item.url) }
                        return HashResult(candidate: item, hash: hash)
                    }
                }

                while let result = await group.next() {
                    if Task.isCancelled { break }

                    if let hash = result.hash {
                        sampledGroups["\(result.candidate.size)_\(hash)", default: []].append(result.candidate)
                    }

                    processedCandidateCount += 1

                    if index < sameSizeCandidates.count {
                        let item = sameSizeCandidates[index]
                        index += 1
                        group.addTask {
                            let key = HashCacheKey(path: item.url.path, size: item.size, modified: item.modified, kind: .sampled)
                            let hash = cache.value(for: key) { FileSafety.sampledFileHash(for: item.url) }
                            return HashResult(candidate: item, hash: hash)
                        }
                    }

                    if Date().timeIntervalSince(lastUIUpdate) > 0.05 {
                        lastUIUpdate = Date()
                        let processed = processedCandidateCount
                        let total = max(1, totalCandidatesCount)
                        let currentPath = result.candidate.url.lastPathComponent
                        await MainActor.run { [weak self] in
                            self?.currentScanPath = currentPath
                            self?.scanProgress = 0.40 + (Double(processed) / Double(total) * sampleProgressSpan)
                            self?.scanStatusText = String(format: t("dup.status.hash1Progress"), processed, total)
                        }
                    }
                }
            }

            if Task.isCancelled { return ScanOutcome(groups: [], prunedDirectories: prunedDirectories, hardLinkSkipped: 0) }

            // 3단계: 정밀 검사에서만 전체 SHA-256 으로 재검증한다.
            // 빠른 검사는 샘플 해시(크기 + 앞·중간·뒤 8KB)까지 같은 파일을 중복으로 본다.
            var finalDuplicateMap: [String: [ScanCandidate]] = [:]

            if mode == .fast {
                for (key, files) in sampledGroups where files.count > 1 {
                    finalDuplicateMap[key] = files
                }
            } else {
                var fullHashCandidates: [ScanCandidate] = []
                for (_, files) in sampledGroups where files.count > 1 {
                    fullHashCandidates.append(contentsOf: files)
                }
                let totalFullHashCount = fullHashCandidates.count

                await MainActor.run { [weak self] in
                    self?.scanProgress = 0.75
                    self?.scanStatusText = String(format: t("dup.status.hash2Start"), totalFullHashCount)
                }

                var processedFullCount = 0
                await withTaskGroup(of: HashResult.self) { group in
                    var index = 0

                    while index < fullHashCandidates.count && index < workerCount {
                        let item = fullHashCandidates[index]
                        index += 1
                        group.addTask {
                            let key = HashCacheKey(path: item.url.path, size: item.size, modified: item.modified, kind: .full)
                            let hash = cache.value(for: key) { FileSafety.fullFileHash(for: item.url) }
                            return HashResult(candidate: item, hash: hash)
                        }
                    }

                    while let result = await group.next() {
                        if Task.isCancelled { break }

                        if let hash = result.hash {
                            finalDuplicateMap["\(result.candidate.size)_\(hash)", default: []].append(result.candidate)
                        }

                        processedFullCount += 1

                        if index < fullHashCandidates.count {
                            let item = fullHashCandidates[index]
                            index += 1
                            group.addTask {
                                let key = HashCacheKey(path: item.url.path, size: item.size, modified: item.modified, kind: .full)
                                let hash = cache.value(for: key) { FileSafety.fullFileHash(for: item.url) }
                                return HashResult(candidate: item, hash: hash)
                            }
                        }

                        if Date().timeIntervalSince(lastUIUpdate) > 0.05 {
                            lastUIUpdate = Date()
                            let processed = processedFullCount
                            let total = max(1, totalFullHashCount)
                            let currentPath = result.candidate.url.lastPathComponent
                            await MainActor.run { [weak self] in
                                self?.currentScanPath = currentPath
                                self?.scanProgress = 0.75 + (Double(processed) / Double(total) * 0.23)
                                self?.scanStatusText = String(format: t("dup.status.hash2Progress"), processed, total)
                            }
                        }
                    }
                }
            }


            
            if Task.isCancelled { return ScanOutcome(groups: [], prunedDirectories: prunedDirectories, hardLinkSkipped: 0) }

            // 4단계: 중복 그룹 생성 및 용량순 정렬.
            // 하드링크는 같은 실체를 가리키는 경로라 중복이 아니다. 하나를 지워도 공간이
            // 회수되지 않으므로 그룹을 만들기 전에 하나로 접는다.
            var duplicateGroups: [DuplicateGroup] = []
            var hardLinkSkipped = 0

            for (key, files) in finalDuplicateMap {
                if Task.isCancelled { break }
                guard files.count > 1 else { continue }

                var seenIdentities: Set<FileIdentity> = []
                var unique: [ScanCandidate] = []
                for file in files {
                    guard let identity = FileIdentity(path: file.url.path) else { continue }
                    if seenIdentities.insert(identity).inserted {
                        unique.append(file)
                    } else {
                        hardLinkSkipped += 1
                    }
                }

                guard unique.count > 1 else { continue }

                let size = unique[0].size
                let instances = unique.enumerated().map { index, file in
                    DuplicateFileInstance(
                        id: file.url.path,
                        url: file.url,
                        lastModified: file.modified,
                        // 가장 오래된 파일을 원본으로 남기고 나머지를 선택한다.
                        isSelected: index > 0
                    )
                }

                duplicateGroups.append(
                    DuplicateGroup(id: key,
                                   name: unique[0].url.lastPathComponent,
                                   size: size,
                                   instances: instances)
                )
            }

            duplicateGroups.sort { $0.size > $1.size }
            // 다음 스캔에서 재사용할 해시를 디스크에 남긴다.
            cache.save()

            return ScanOutcome(groups: duplicateGroups,
                               prunedDirectories: prunedDirectories,
                               hardLinkSkipped: hardLinkSkipped)
        }.value

        if !isCancelled {
            self.groups = outcome.groups
            self.prunedDirectoryCount = outcome.prunedDirectories
            self.hardLinkSkippedCount = outcome.hardLinkSkipped
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
