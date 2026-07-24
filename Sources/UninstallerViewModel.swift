import Foundation
import AppKit
import Combine

@MainActor
class UninstallerViewModel: ObservableObject {
    @Published var selectedApp: SelectedAppInfo? = nil
    @Published var leftoverItems: [LeftoverItem] = []
    @Published var isScanning = false
    @Published var isCleaning = false
    @Published var showCleanSuccess = false
    @Published var cleanedSize: Int64 = 0
    
    // 설치된 앱 목록을 위한 변수
    @Published var installedApps: [SelectedAppInfo] = []
    @Published var isSearchingApps = false
    @Published var sortOption: AppSortOption = .nameAsc
    
    private var cancellables = Set<AnyCancellable>()
    
    /// 설치된 응용 프로그램 목록을 /Applications 폴더에서 검색하여 불러옵니다.
    func fetchInstalledApps() {
        isSearchingApps = true
        installedApps = []
        
        Task {
            let apps = await Task.detached(priority: .userInitiated) { () -> [SelectedAppInfo] in
                let fm = FileManager.default
                let appsURL = URL(fileURLWithPath: "/Applications")
                
                // 샌드박스 접근 토큰 획득
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
                for url in contents {
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
                    }
                }
                
                results.sort(by: { $0.name.localizedCompare($1.name) == .orderedAscending })
                return results
            }.value
            
            self.installedApps = apps
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
    
    /// 앱 선택 창을 띄웁니다.
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
    
    /// Drag & Drop이나 선택 완료 후 앱 정보를 로드하고 스캔을 시작합니다.
    func loadAppAndScan(at url: URL) {
        isScanning = true
        showCleanSuccess = false
        leftoverItems = []
        
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
    
    /// 앱을 직접 드롭했을 때의 경로 처리
    func handleDroppedAppURL(_ url: URL) {
        guard url.pathExtension.lowercased() == "app" else { return }
        loadAppAndScan(at: url)
    }
    
    /// 앱과 연관된 잔여 파일을 탐색합니다.
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
        
        let items = await Task.detached(priority: .userInitiated) { () -> [LeftoverItem] in
            let localFM = FileManager.default
            var results: [LeftoverItem] = []
            
            // A. 앱 자체 파일 추가 (.app bundle)
            results.append(LeftoverItem(url: app.url, size: app.size, category: .appBundle, isSelected: true))
            
            // B. 시스템 디렉토리 스캔
            for (dirURL, category) in scanDirectories {
                let scanPath = dirURL.standardized.path
                if FileSafety.isProtectedExact(scanPath) {
                    continue
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
        
        // 앱 이름 매칭은 경계(구분자) 기준으로만 허용한다.
        // 단순 substring contains 는 무관한 다른 앱의 파일을 오탐하므로 제거.
        if lowerAppName.count >= 4 {
            let delimiters: [Character] = [".", "-", "_", " "]

            // "AppName" + 구분자 로 시작 (예: "myapp.helper.plist")
            for delim in delimiters {
                if lowerName.hasPrefix(lowerAppName + String(delim)) {
                    return true
                }
            }

            // 구분자로 나눈 토큰 중 하나가 앱 이름과 정확히 일치할 때만 허용.
            // (com.vendor.myapp / myapp-2024.log 등은 잡고, "myapplication" 오탐은 배제)
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
    }
}
