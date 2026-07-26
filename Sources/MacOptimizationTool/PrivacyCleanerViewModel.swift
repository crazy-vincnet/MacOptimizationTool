import Foundation
import Combine
import AppKit
import MacOptimizationCore

struct PrivacyItemCategory: Identifiable {
    let id = UUID()
    let browserName: String
    let iconName: String
    let description: String
    var items: [PrivacySubItem]
    var isExpanded: Bool = true
    
    var totalSize: Int64 {
        items.reduce(0) { $0 + ($1.isSelected ? $1.size : 0) }
    }
    
    var isSelected: Bool {
        get { !items.isEmpty && items.allSatisfy { $0.isSelected } }
        set {
            for i in 0..<items.count {
                items[i].isSelected = newValue
            }
        }
    }
}

struct PrivacySubItem: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let url: URL
    let itemType: PrivacyItemType
    let size: Int64
    var isSelected: Bool = true
}

enum PrivacyItemType: String {
    case webCache
    case cookies
    case history
    case downloadHistory
    case webStorage

    var displayName: String {
        switch self {
        case .webCache: return t("priv.cat.webCache")
        case .cookies: return t("priv.cat.cookies")
        case .history: return t("priv.cat.history")
        case .downloadHistory: return t("priv.cat.downloadHistory")
        case .webStorage: return t("priv.cat.webStorage")
        }
    }
}

@MainActor
final class PrivacyCleanerViewModel: ObservableObject {
    static let shared = PrivacyCleanerViewModel()
    
    @Published var categories: [PrivacyItemCategory] = []
    @Published var isScanning: Bool = false
    @Published var isCleaning: Bool = false
    @Published var hasScanned: Bool = false
    @Published var showCleanSuccess: Bool = false
    @Published var cleanedSize: Int64 = 0
    
    // Real-Time Progress Tracking
    @Published var scanProgress: Double = 0.0
    @Published var scanStatusText: String = ""
    @Published var currentScanBrowser: String = ""
    @Published var scannedItemCount: Int = 0
    
    var totalReclaimableSize: Int64 {
        categories.reduce(0) { $0 + $1.totalSize }
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

    func scanPrivacyData() {
        cancelScan()
        isCancelled = false
        isScanning = true
        hasScanned = false
        showCleanSuccess = false
        categories = []
        scanProgress = 0.05
        scanStatusText = t("priv.status.start")
        scannedItemCount = 0
        
        scanTask = Task {
            let resultCategories = await Task.detached(priority: .userInitiated) { [weak self] () -> [PrivacyItemCategory] in
                var list: [PrivacyItemCategory] = []
                let fm = FileManager.default
                let home = fm.homeDirectoryForCurrentUser
                let library = home.appendingPathComponent("Library")

                
                // 브라우저별 스캔 타겟 정의
                let browserTargets: [(String, String, [(PrivacyItemType, URL)])] = [
                    ("Safari", "safari.fill", [
                        (.webCache, library.appendingPathComponent("Caches/com.apple.Safari")),
                        (.webCache, library.appendingPathComponent("Containers/com.apple.Safari/Data/Library/Caches")),
                        (.cookies, library.appendingPathComponent("Cookies/Cookies.binarycookies")),
                        (.webStorage, library.appendingPathComponent("Safari/LocalStorage")),
                        (.webCache, library.appendingPathComponent("Safari/Favicon Cache"))
                    ]),
                    ("Google Chrome", "globe", [
                        (.webCache, library.appendingPathComponent("Caches/Google/Chrome/Default/Cache")),
                        (.webCache, library.appendingPathComponent("Caches/Google/Chrome/Default/Code Cache")),
                        (.cookies, library.appendingPathComponent("Application Support/Google/Chrome/Default/Cookies")),
                        (.webStorage, library.appendingPathComponent("Application Support/Google/Chrome/Default/Local Storage")),
                        (.history, library.appendingPathComponent("Application Support/Google/Chrome/Default/History"))
                    ]),
                    ("Microsoft Edge", "globe.americas.fill", [
                        (.webCache, library.appendingPathComponent("Caches/Microsoft Edge/Default/Cache")),
                        (.cookies, library.appendingPathComponent("Application Support/Microsoft Edge/Default/Cookies")),
                        (.webStorage, library.appendingPathComponent("Application Support/Microsoft Edge/Default/Local Storage"))
                    ]),
                    ("Firefox", "flame.fill", [
                        (.webCache, library.appendingPathComponent("Caches/Firefox/Profiles")),
                        (.cookies, library.appendingPathComponent("Application Support/Firefox/Profiles"))
                    ]),
                    ("Brave Browser", "shield.fill", [
                        (.webCache, library.appendingPathComponent("Caches/BraveSoftware/Brave-Browser/Default/Cache")),
                        (.cookies, library.appendingPathComponent("Application Support/BraveSoftware/Brave-Browser/Default/Cookies"))
                    ])
                ]
                
                let totalBrowsers = browserTargets.count
                var foundCount = 0
                
                for (bIdx, (bName, icon, targets)) in browserTargets.enumerated() {
                    let progress = 0.05 + (Double(bIdx) / Double(totalBrowsers) * 0.90)
                    await MainActor.run { [weak self] in
                        self?.currentScanBrowser = bName
                        self?.scanStatusText = String(format: t("priv.status.scanning"), bName)
                        self?.scanProgress = progress
                    }

                    
                    var subItems: [PrivacySubItem] = []
                    
                    for (type, targetURL) in targets {
                        let path = targetURL.standardized.path
                        if FileSafety.isProtectedExact(path) { continue }
                        
                        var isDir: ObjCBool = false
                        if fm.fileExists(atPath: path, isDirectory: &isDir) {
                            let size = DirectorySize.measure(at: targetURL, isCancelled: { Task.isCancelled }).localBytes
                            if size > 0 {
                                foundCount += 1
                                subItems.append(PrivacySubItem(
                                    name: "\(type.displayName) (\(targetURL.lastPathComponent))",
                                    path: path,
                                    url: targetURL,
                                    itemType: type,
                                    size: size,
                                    isSelected: true
                                ))
                            }
                        }
                    }
                    
                    if !subItems.isEmpty {
                        list.append(PrivacyItemCategory(
                            browserName: bName,
                            iconName: icon,
                            description: String(format: t("priv.item.description"), bName),
                            items: subItems,
                            isExpanded: true
                        ))
                    }
                }
                
                let count = foundCount
                await MainActor.run { [weak self] in
                    self?.scannedItemCount = count
                }


                
                return list
            }.value
            
            if !self.isCancelled {
                self.categories = resultCategories
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
    
    func cleanPrivacyData() {
        guard totalReclaimableSize > 0 else { return }
        
        isCleaning = true
        showCleanSuccess = false
        
        var targetsToDelete: [URL] = []
        for cat in categories {
            for item in cat.items where item.isSelected {
                targetsToDelete.append(item.url)
            }
        }
        
        // 백그라운드 태스크로 넘길 값은 불변 복사본으로 고정한다.
        let deletionTargets = targetsToDelete

        Task {
            let cleanedBytes = await Task.detached(priority: .userInitiated) { () -> Int64 in
                var freed: Int64 = 0
                let fm = FileManager.default
                for url in deletionTargets {
                    let size = DirectorySize.measure(at: url).localBytes
                    if FileSafety.moveToTrash(url) {
                        freed += size
                    } else {
                        try? fm.removeItem(at: url)
                        freed += size
                    }
                }
                return freed
            }.value
            
            self.cleanedSize = cleanedBytes
            self.isCleaning = false
            self.showCleanSuccess = true
            self.scanPrivacyData()
        }
    }
    
}
