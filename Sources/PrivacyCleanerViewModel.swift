import Foundation
import Combine
import AppKit

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
    case webCache = "웹 캐시 & 임시 파일"
    case cookies = "웹 쿠키 & 세션 데이터"
    case history = "방문 기록 & 폼 채우기"
    case downloadHistory = "다운로드 기록"
    case webStorage = "HTML5 웹 스토리지"
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
    
    func scanPrivacyData() {
        isScanning = true
        hasScanned = false
        showCleanSuccess = false
        categories = []
        scanProgress = 0.05
        scanStatusText = "브라우저 및 개인정보 데이터 탐색 준비 중..."
        scannedItemCount = 0
        
        Task {
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
                    await MainActor.run {
                        self?.currentScanBrowser = bName
                        self?.scanStatusText = "\(bName) 데이터 검사 중..."
                        self?.scanProgress = progress
                    }
                    
                    var subItems: [PrivacySubItem] = []
                    
                    for (type, targetURL) in targets {
                        let path = targetURL.standardized.path
                        if FileSafety.isProtectedExact(path) { continue }
                        
                        var isDir: ObjCBool = false
                        if fm.fileExists(atPath: path, isDirectory: &isDir) {
                            let size = Self.calculateSizeStatic(at: targetURL)
                            if size > 0 {
                                foundCount += 1
                                subItems.append(PrivacySubItem(
                                    name: "\(type.rawValue) (\(targetURL.lastPathComponent))",
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
                            description: "\(bName) 브라우저의 웹 캐시, 쿠키, 저장 데이터입니다.",
                            items: subItems,
                            isExpanded: true
                        ))
                    }
                }
                
                await MainActor.run {
                    self?.scannedItemCount = foundCount
                }
                
                return list
            }.value
            
            self.categories = resultCategories
            self.scanProgress = 1.0
            self.isScanning = false
            self.hasScanned = true
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
        
        Task {
            let cleanedBytes = await Task.detached(priority: .userInitiated) { () -> Int64 in
                var freed: Int64 = 0
                let fm = FileManager.default
                for url in targetsToDelete {
                    let size = Self.calculateSizeStatic(at: url)
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
    
    nonisolated private static func calculateSizeStatic(at url: URL) -> Int64 {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }
        
        if !isDir.boolValue {
            var statInfo = stat()
            if lstat(url.path, &statInfo) == 0 {
                return Int64(statInfo.st_size)
            }
            return 0
        }
        
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, _ in return true }
        ) else { return 0 }
        
        var total: Int64 = 0
        while let fileURL = enumerator.nextObject() as? URL {
            if let vals = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
               let isDirectory = vals.isDirectory, !isDirectory,
               let fileSize = vals.fileSize {
                total += Int64(fileSize)
            }
        }
        return total
    }

}
