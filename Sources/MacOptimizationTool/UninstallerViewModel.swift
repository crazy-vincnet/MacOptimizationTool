import Foundation
import AppKit
import Combine
import MacOptimizationCore

@MainActor
class UninstallerViewModel: ObservableObject {
    static let shared = UninstallerViewModel()

    @Published var selectedApp: SelectedAppInfo? = nil
    @Published var leftoverItems: [LeftoverItem] = []
    @Published var isScanning = false
    @Published var isCleaning = false
    @Published var showCleanSuccess = false
    @Published var cleanedSize: Int64 = 0
    
    // Real-Time Progress Tracking Properties
    @Published var scanProgress: Double = 0.0
    @Published var scanStatusText: String = ""
    @Published var currentScanPath: String = ""
    @Published var scannedAppCount: Int = 0

    // 설치된 앱 목록을 위한 변수
    @Published var installedApps: [SelectedAppInfo] = []
    @Published var isSearchingApps = false
    @Published var sortOption: AppSortOption = .nameAsc
    
    private var cancellables = Set<AnyCancellable>()
    
    /// 설치된 응용 프로그램 목록을 /Applications 폴더에서 검색하여 불러옵니다.
    func fetchInstalledApps() {
        isSearchingApps = true
        installedApps = []
        scanProgress = 0.05
        scanStatusText = t("uninst.status.scanningApps")
        
        Task {
            let scanned = await Task.detached(priority: .userInitiated) { [weak self] () -> [AppMetadata] in
                let fm = FileManager.default
                let appsURL = URL(fileURLWithPath: "/Applications")
                
                let isAccessed = appsURL.startAccessingSecurityScopedResource()
                defer {
                    if isAccessed {
                        appsURL.stopAccessingSecurityScopedResource()
                    }
                }
                
                guard let contents = try? fm.contentsOfDirectory(at: appsURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
                    return []
                }
                
                var results: [AppMetadata] = []
                let totalContents = contents.count

                for (index, url) in contents.enumerated() {
                    if url.pathExtension.lowercased() == "app" {
                        let name = url.deletingPathExtension().lastPathComponent
                        let infoPlistURL = url.appendingPathComponent("Contents/Info.plist")
                        var bundleID: String? = nil
                        var version: String? = nil
                        
                        if fm.fileExists(atPath: infoPlistURL.path) {
                            if let infoDict = NSDictionary(contentsOf: infoPlistURL) {
                                bundleID = infoDict["CFBundleIdentifier"] as? String
                                version = infoDict["CFBundleShortVersionString"] as? String ?? infoDict["CFBundleVersion"] as? String
                            }
                        }
                        
                        var instDate = Date()
                        if let attrs = try? fm.attributesOfItem(atPath: url.path) {
                            instDate = attrs[.creationDate] as? Date ?? attrs[.modificationDate] as? Date ?? Date()
                        }

                        let app = AppMetadata(
                            url: url,
                            name: name,
                            bundleID: bundleID,
                            version: version,
                            size: 0,
                            installationDate: instDate
                        )
                        results.append(app)

                        let count = results.count
                        let appName = name
                        let progress = 0.05 + (Double(index) / Double(totalContents) * 0.90)
                        await MainActor.run { [weak self] in
                            self?.scannedAppCount = count
                            self?.currentScanPath = appName
                            self?.scanStatusText = String(format: t("uninst.status.foundApps"), count)
                            self?.scanProgress = progress
                        }

                    }
                }
                
                results.sort(by: { $0.name.localizedCompare($1.name) == .orderedAscending })
                return results
            }.value
            
            // 아이콘은 메인 액터에서 붙인다 (NSImage 는 Sendable 이 아니다).
            self.installedApps = scanned.map { SelectedAppInfo(metadata: $0) }
            self.scanProgress = 1.0
            self.isSearchingApps = false
            self.loadAppSizesInBackground()
        }
    }
    
    /// 각 앱들의 용량을 백그라운드 스레드에서 차례대로 연산하여 화면에 부분 업데이트합니다.
    private func loadAppSizesInBackground() {
        let appsToProcess = self.installedApps
        
        for app in appsToProcess {
            // SelectedAppInfo 는 NSImage 를 담고 있어 Sendable 이 아니다. URL 만 백그라운드로 넘긴다.
            let appURL = app.url
            Task {
                let size = await Task.detached(priority: .utility) { () -> Int64 in
                    let isAccessed = appURL.startAccessingSecurityScopedResource()
                    defer {
                        if isAccessed {
                            appURL.stopAccessingSecurityScopedResource()
                        }
                    }
                    return DirectorySize.measure(at: appURL, isCancelled: { Task.isCancelled }).localBytes
                }.value

                if let index = self.installedApps.firstIndex(where: { $0.url == appURL }) {
                    let oldApp = self.installedApps[index]
                    self.installedApps[index] = SelectedAppInfo(
                        url: oldApp.url,
                        name: oldApp.name,
                        bundleID: oldApp.bundleID,
                        version: oldApp.version,
                        icon: oldApp.icon,
                        size: size,
                        installationDate: oldApp.installationDate
                    )
                }
            }
        }
    }
    
    func selectAppAndScan() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.application]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.directoryURL = URL(fileURLWithPath: "/Applications")
        
        openPanel.begin { [weak self] response in
            if response == .OK, let url = openPanel.url {
                self?.loadAppAndScan(at: url)
            }
        }
    }
    
    func loadAppAndScan(at url: URL) {
        isScanning = true
        showCleanSuccess = false
        leftoverItems = []
        scanProgress = 0.05
        scanStatusText = t("uninst.status.scanningLeftovers")
        
        Task {
            let metadata = await Task.detached(priority: .userInitiated) { () -> AppMetadata in
                let fm = FileManager.default
                let isAccessed = url.startAccessingSecurityScopedResource()
                defer {
                    if isAccessed {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                
                let appName = url.deletingPathExtension().lastPathComponent
                let infoPlistURL = url.appendingPathComponent("Contents/Info.plist")
                var bundleID: String? = nil
                var version: String? = nil
                
                if fm.fileExists(atPath: infoPlistURL.path) {
                    if let infoDict = NSDictionary(contentsOf: infoPlistURL) {
                        bundleID = infoDict["CFBundleIdentifier"] as? String
                        version = infoDict["CFBundleShortVersionString"] as? String ?? infoDict["CFBundleVersion"] as? String
                    }
                }
                
                let appSize = DirectorySize.measure(at: url, isCancelled: { Task.isCancelled }).localBytes
                var instDate = Date()
                if let attrs = try? fm.attributesOfItem(atPath: url.path) {
                    instDate = attrs[.creationDate] as? Date ?? attrs[.modificationDate] as? Date ?? Date()
                }
                
                return AppMetadata(
                    url: url,
                    name: appName,
                    bundleID: bundleID,
                    version: version,
                    size: appSize,
                    installationDate: instDate
                )
            }.value

            let appInfo = SelectedAppInfo(metadata: metadata)
            self.selectedApp = appInfo
            await self.scanLeftovers(for: appInfo)
        }
    }
    
    func handleDroppedAppURL(_ url: URL) {
        guard url.pathExtension.lowercased() == "app" else { return }
        loadAppAndScan(at: url)
    }
    
    private func scanLeftovers(for app: SelectedAppInfo) async {
        let fm = FileManager.default
        let userHome = fm.homeDirectoryForCurrentUser
        let userLibrary = userHome.appendingPathComponent("Library")
        
        let scanDirectories: [(URL, LeftoverCategory)] = [
            (userLibrary.appendingPathComponent("Application Support"), .appSupport),
            (userLibrary.appendingPathComponent("Caches"), .caches),
            (userLibrary.appendingPathComponent("Preferences"), .preferences),
            (userLibrary.appendingPathComponent("Logs"), .logs),
            (userLibrary.appendingPathComponent("Containers"), .containers),
            (userLibrary.appendingPathComponent("Group Containers"), .containers),
            (userLibrary.appendingPathComponent("Saved Application State"), .others),
            (userLibrary.appendingPathComponent("LaunchAgents"), .launchAgents),
            (userLibrary.appendingPathComponent("Cookies"), .caches),
            (userLibrary.appendingPathComponent("HTTPStorages"), .caches),
            (userLibrary.appendingPathComponent("Application Support/CrashReporter"), .logs),
            (userLibrary.appendingPathComponent("WebKit"), .caches),
            
            (URL(fileURLWithPath: "/Library/Application Support"), .appSupport),
            (URL(fileURLWithPath: "/Library/Caches"), .caches),
            (URL(fileURLWithPath: "/Library/Preferences"), .preferences),
            (URL(fileURLWithPath: "/Library/Logs"), .logs),
            (URL(fileURLWithPath: "/Library/LaunchAgents"), .launchAgents),
            (URL(fileURLWithPath: "/Library/LaunchDaemons"), .launchAgents)
        ]
        
        let totalDirs = scanDirectories.count

        // 클로저가 SelectedAppInfo(비Sendable) 전체를 캡처하지 않도록 필요한 값만 꺼낸다.
        let appURL = app.url
        let appSize = app.size
        let appName = app.name
        let appBundleID = app.bundleID

        let items = await Task.detached(priority: .userInitiated) { [weak self] () -> [LeftoverItem] in
            let localFM = FileManager.default
            var results: [LeftoverItem] = []
            
            results.append(LeftoverItem(url: appURL, size: appSize, category: .appBundle, isSelected: true))
            
            for (idx, (dirURL, category)) in scanDirectories.enumerated() {
                let scanPath = dirURL.standardized.path
                if FileSafety.isProtectedExact(scanPath) {
                    continue
                }
                
                let dirName = dirURL.lastPathComponent
                let progress = 0.10 + (Double(idx) / Double(totalDirs) * 0.85)
                await MainActor.run { [weak self] in
                    self?.currentScanPath = dirName
                    self?.scanStatusText = String(format: t("uninst.status.scanningLibrary"), dirName)
                    self?.scanProgress = progress
                }


                let isAccessed = dirURL.startAccessingSecurityScopedResource()
                defer {
                    if isAccessed {
                        dirURL.stopAccessingSecurityScopedResource()
                    }
                }
                
                var isDir: ObjCBool = false
                guard localFM.fileExists(atPath: dirURL.path, isDirectory: &isDir), isDir.boolValue else {
                    continue
                }
                
                guard let contents = try? localFM.contentsOfDirectory(at: dirURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
                    continue
                }
                
                for itemURL in contents {
                    let itemPath = itemURL.standardized.path
                    if FileSafety.isProtectedExact(itemPath) {
                        continue
                    }
                    
                    let fileName = itemURL.lastPathComponent
                    if LeftoverMatcher.matches(fileName: fileName, appName: appName, bundleID: appBundleID) {
                        let size = DirectorySize.measure(at: itemURL, isCancelled: { Task.isCancelled }).localBytes
                        if !results.contains(where: { $0.url.standardized.path == itemPath }) {
                            results.append(LeftoverItem(url: itemURL, size: size, category: category, isSelected: true))
                        }
                    }
                }
            }
            return results
        }.value
        
        self.leftoverItems = items
        self.scanProgress = 1.0
        self.isScanning = false
    }
    
    @Published var showAuthError: Bool = false

    func deleteSelectedItems() {
        guard !leftoverItems.isEmpty else { return }
        
        isCleaning = true
        showCleanSuccess = false
        showAuthError = false
        
        let itemsToDelete = leftoverItems.filter { $0.isSelected }.map { (url: $0.url, size: $0.size) }
        
        Task {
            let (totalCleaned, isSuccess) = await Task.detached(priority: .userInitiated) { () -> (Int64, Bool) in
                return FileSafety.deleteBatch(items: itemsToDelete)
            }.value
            
            if isSuccess {
                self.cleanedSize = totalCleaned
                self.selectedApp = nil
                self.leftoverItems = []
                self.isCleaning = false
                self.showCleanSuccess = true
                self.fetchInstalledApps()
            } else {
                // 비밀번호 불일치 또는 사용자가 인증 취소 시 메인 앱 포함 어떤 파일도 지우지 않고 안전 중단
                self.isCleaning = false
                self.showCleanSuccess = false
                self.showAuthError = true
            }
        }
    }

    
    func reset() {
        selectedApp = nil
        leftoverItems = []
        showCleanSuccess = false
        isScanning = false
        isCleaning = false
    }
}
