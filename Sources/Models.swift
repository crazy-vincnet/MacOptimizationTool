import Foundation
import AppKit

/// 잔여 파일의 카테고리 정의
enum LeftoverCategory: String, CaseIterable, Identifiable {
    case appBundle
    case appSupport
    case caches
    case preferences
    case logs
    case containers
    case launchAgents
    case others
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .appBundle: return t("uninst.cat.appBundle")
        case .appSupport: return t("uninst.cat.appSupport")
        case .caches: return t("uninst.cat.caches")
        case .preferences: return t("uninst.cat.preferences")
        case .logs: return t("uninst.cat.logs")
        case .containers: return t("uninst.cat.containers")
        case .launchAgents: return t("uninst.cat.launchAgents")
        case .others: return t("uninst.cat.others")
        }
    }
    
    var iconName: String {
        switch self {
        case .appBundle: return "app.badge"
        case .appSupport: return "folder.badge.gearshape"
        case .caches: return "trash.square"
        case .preferences: return "slider.horizontal.3"
        case .logs: return "doc.text"
        case .containers: return "shippingbox"
        case .launchAgents: return "bolt.horizontal"
        case .others: return "doc.questionmark"
        }
    }
}

/// 개별 잔여 파일/폴더 정보
struct LeftoverItem: Identifiable, Equatable, Hashable {
    let id = UUID()
    let url: URL
    let size: Int64
    let category: LeftoverCategory
    var isSelected: Bool
    
    var path: String {
        return url.path
    }
    
    var readableSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    static func == (lhs: LeftoverItem, rhs: LeftoverItem) -> Bool {
        return lhs.url.standardized.path == rhs.url.standardized.path
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(url.standardized.path)
    }
}

/// 정렬 옵션 정의
enum AppSortOption: String, CaseIterable, Identifiable {
    case nameAsc
    case nameDesc
    case sizeDesc
    case sizeAsc
    case dateDesc
    case dateAsc
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .nameAsc: return t("uninst.sort.nameAsc")
        case .nameDesc: return t("uninst.sort.nameDesc")
        case .sizeDesc: return t("uninst.sort.sizeDesc")
        case .sizeAsc: return t("uninst.sort.sizeAsc")
        case .dateDesc: return t("uninst.sort.dateDesc")
        case .dateAsc: return t("uninst.sort.dateAsc")
        }
    }
}

/// 삭제할 대상 앱 정보
struct SelectedAppInfo: Identifiable, Equatable, Hashable {
    var id: URL { url }
    let url: URL
    let name: String
    let bundleID: String?
    let version: String?
    let icon: NSImage
    var size: Int64
    let installationDate: Date
    
    var readableSize: String {
        guard size > 0 else { return t("common.calculating") }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    static func == (lhs: SelectedAppInfo, rhs: SelectedAppInfo) -> Bool {
        return lhs.url == rhs.url && lhs.size == rhs.size && lhs.installationDate == rhs.installationDate
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
}
