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
        case .appBundle: return "응용 프로그램 본체"
        case .appSupport: return "Application Support (설정/데이터)"
        case .caches: return "Caches (캐시 및 임시 파일)"
        case .preferences: return "Preferences (설정)"
        case .logs: return "Logs (로그 및 크래시)"
        case .containers: return "Containers (샌드박스)"
        case .launchAgents: return "Launch Agents (자동실행)"
        case .others: return "기타 잔여 파일"
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
        case .nameAsc: return "이름 (가나다순)"
        case .nameDesc: return "이름 (역순)"
        case .sizeDesc: return "크기 (큰 순서)"
        case .sizeAsc: return "크기 (작은 순서)"
        case .dateDesc: return "설치 날짜 (최신순)"
        case .dateAsc: return "설치 날짜 (오래된순)"
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
        guard size > 0 else { return "계산 중..." }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    static func == (lhs: SelectedAppInfo, rhs: SelectedAppInfo) -> Bool {
        return lhs.url == rhs.url && lhs.size == rhs.size && lhs.installationDate == rhs.installationDate
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
}
