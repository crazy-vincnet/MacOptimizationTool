import Foundation
import AppKit
import Combine

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
        scanStatusText = "설치된 응용 프로그램 스캔 중..."
        
        Task {
            let apps = await Task.detached(priority: .userInitiated) { [weak self] () -> [SelectedAppInfo] in
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
                
                var results: [SelectedAppInfo] = []
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
                        
                        let icon = NSWorkspace.shared.icon(forFile: url.path)
                        var instDate = Date()
                        if let attrs = try? fm.attributesOfItem(atPath: url.path) {
                            instDate = attrs[.creationDate] as? Date ?? attrs[.modificationDate] as? Date ?? Date()
                        }
                        
                        let app = SelectedAppInfo(
                            url: url,
                            name: name,
                            bundleID: bundleID,
                            version: version,
                            icon: icon,
                            size: 0,
                            installationDate: instDate
                        )
                        results.append(app)

                        let count = results.count
                        let appName = name
                        let progress = 0.05 + (Double(index) / Double(totalContents) * 0.90)
                        await MainActor.run {
                            self?.scannedAppCount = count
                            self?.currentScanPath = appName
                            self?.scanStatusText = "앱 목록 탐색 중... (\(count)개 앱 발견)"
                            self?.scanProgress = progress
                        }
                    }
                }
                
                results.sort(by: { $0.name.localizedCompare($1.name) == .orderedAscending })
                return results
            }.value
            
            self.installedApps = apps
            self.scanProgress = 1.0
            self.isSearchingApps = false
            self.loadAppSizesInBackground()
        }
    }
    
    /// 각 앱들의 용량을 백그라운드 스레드에서 차례대로 연산하여 화면에 부분 업데이트합니다.
    private func loadAppSizesInBackground() {
        let appsToProcess = self.installedApps
        
        for app in appsToProcess {
            Task {
                let size = await Task.detached(priority: .utility) { () -> Int64 in
                    let isAccessed = app.url.startAccessingSecurityScopedResource()
                    defer {
                        if isAccessed {
                            app.url.stopAccessingSecurityScopedResource()
                        }
                    }
                    return Self.getDirectorySizeStatic(at: app.url)
                }.value
                
                if let index = self.installedApps.firstIndex(where: { $0.url == app.url }) {
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
        scanStatusText = "선택된 앱 잔여 찌꺼기 파일 탐색 중..."
        
        Task {
            let appInfo = await Task.detached(priority: .userInitiated) {
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
                
                let icon = NSWorkspace.shared.icon(forFile: url.path)
                let appSize = Self.getDirectorySizeStatic(at: url)
                var instDate = Date()
                if let attrs = try? fm.attributesOfItem(atPath: url.path) {
                    instDate = attrs[.creationDate] as? Date ?? attrs[.modificationDate] as? Date ?? Date()
                }
                
                return SelectedAppInfo(
                    url: url,
                    name: appName,
                    bundleID: bundleID,
                    version: version,
                    icon: icon,
                    size: appSize,
                    installationDate: instDate
                )
            }.value
            
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

        let items = await Task.detached(priority: .userInitiated) { [weak self] () -> [LeftoverItem] in
            let localFM = FileManager.default
            var results: [LeftoverItem] = []
            
            results.append(LeftoverItem(url: app.url, size: app.size, category: .appBundle, isSelected: true))
            
            for (idx, (dirURL, category)) in scanDirectories.enumerated() {
                let scanPath = dirURL.standardized.path
                if FileSafety.isProtectedExact(scanPath) {
                    continue
                }
                
                let dirName = dirURL.lastPathComponent
                let progress = 0.10 + (Double(idx) / Double(totalDirs) * 0.85)
                await MainActor.run {
                    self?.currentScanPath = dirName
                    self?.scanStatusText = "보조 라이브러리 스캔 중... (\(dirName))"
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
                    if Self.matchesStatic(fileName: fileName, appName: app.name, bundleID: app.bundleID) {
                        let size = Self.getDirectorySizeStatic(at: itemURL)
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
    
    nonisolated private static func matchesStatic(fileName: String, appName: String, bundleID: String?) -> Bool {
        let lowerName = fileName.lowercased()
        let lowerAppName = appName.lowercased()
        
        let genericNames = ["app", "link", "tool", "clean", "cleaner", "helper", "system", "manager", "admin", "free", "utility", "test", "demo"]
        let isShortOrGeneric = lowerAppName.count < 4 || genericNames.contains(lowerAppName)
        
        if lowerName == lowerAppName { return true }
        
        if let bid = bundleID?.lowercased() {
            if lowerName == bid { return true }
            if lowerName.contains(bid) { return true }
            if bid.contains(lowerName) && lowerName.count > 10 { return true }
        }
        
        if lowerName.hasSuffix(".plist") {
            let nameWithoutPlist = lowerName.replacingOccurrences(of: ".plist", with: "")
            if nameWithoutPlist == lowerAppName { return true }
            if let bid = bundleID?.lowercased(), nameWithoutPlist == bid { return true }
        }
        
        if isShortOrGeneric {
            return false
        }
        
        if lowerAppName.count >= 4 {
            let delimiters: [Character] = [".", "-", "_", " "]

            for delim in delimiters {
                if lowerName.hasPrefix(lowerAppName + String(delim)) {
                    return true
                }
            }

            let tokens = lowerName.split(whereSeparator: { delimiters.contains($0) })
            if tokens.contains(where: { String($0) == lowerAppName }) {
                return true
            }
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
    
    func deleteSelectedItems() {
        guard !leftoverItems.isEmpty else { return }
        
        isCleaning = true
        showCleanSuccess = false
        
        let itemsToDelete = leftoverItems.filter { $0.isSelected }
        
        Task {
            let totalCleaned = await Task.detached(priority: .userInitiated) { () -> Int64 in
                var cleaned: Int64 = 0

                for item in itemsToDelete {
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
            self.selectedApp = nil
            self.leftoverItems = []
            self.isCleaning = false
            self.showCleanSuccess = true
            self.fetchInstalledApps()
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
