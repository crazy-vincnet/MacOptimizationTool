import Foundation
import Combine
import MacOptimizationCore

struct LaunchAgentItem: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let label: String
    let path: String
    let type: StartupType
    var isEnabled: Bool
}

enum StartupType: String, CaseIterable {
    case userAgent
    case systemAgent
    case systemDaemon

    var displayName: String {
        switch self {
        case .userAgent: return t("startup.type.userAgent")
        case .systemAgent: return t("startup.type.systemAgent")
        case .systemDaemon: return t("startup.type.systemDaemon")
        }
    }

    var icon: String {
        switch self {
        case .userAgent: return "person.crop.square"
        case .systemAgent: return "gearshape.2"
        case .systemDaemon: return "cpu"
        }
    }
}

@MainActor
final class StartupManagerViewModel: ObservableObject {
    @Published var startupItems: [LaunchAgentItem] = []
    @Published var isScanning = false
    @Published var selectedFilter: StartupType? = nil
    @Published var statusMessage: String = ""

    private let fileManager = FileManager.default

    var filteredItems: [LaunchAgentItem] {
        if let filter = selectedFilter {
            return startupItems.filter { $0.type == filter }
        }
        return startupItems
    }

    func scanStartupItems() {
        isScanning = true
        startupItems.removeAll()

        Task {
            var items: [LaunchAgentItem] = []

            // 1. User LaunchAgents (~/Library/LaunchAgents)
            let userAgentPath = NSString(string: "~/Library/LaunchAgents").expandingTildeInPath
            items.append(contentsOf: scanDirectory(path: userAgentPath, type: .userAgent))

            // 2. System LaunchAgents (/Library/LaunchAgents)
            items.append(contentsOf: scanDirectory(path: "/Library/LaunchAgents", type: .systemAgent))

            // 3. System LaunchDaemons (/Library/LaunchDaemons)
            items.append(contentsOf: scanDirectory(path: "/Library/LaunchDaemons", type: .systemDaemon))

            self.startupItems = items
            self.isScanning = false
            self.statusMessage = String(format: t("startup.status.found"), items.count)
        }
    }

    private func scanDirectory(path: String, type: StartupType) -> [LaunchAgentItem] {
        guard let files = try? fileManager.contentsOfDirectory(atPath: path) else { return [] }
        var result: [LaunchAgentItem] = []

        for file in files {
            guard file.hasSuffix(".plist") || file.hasSuffix(".disabled") else { continue }
            let fullPath = (path as NSString).appendingPathComponent(file)
            
            let isEnabled = !file.hasSuffix(".disabled")
            let labelName = file.replacingOccurrences(of: ".plist", with: "").replacingOccurrences(of: ".disabled", with: "")
            let cleanName = labelName.components(separatedBy: ".").last ?? labelName

            result.append(LaunchAgentItem(
                name: cleanName.capitalized,
                label: labelName,
                path: fullPath,
                type: type,
                isEnabled: isEnabled
            ))
        }

        return result
    }

    func toggleStartupItem(_ item: LaunchAgentItem) {
        guard let currentItem = startupItems.first(where: { $0.id == item.id }) else { return }
        let newEnabled = !currentItem.isEnabled
        let destinationPath: String

        if newEnabled, currentItem.path.hasSuffix(".disabled") {
            destinationPath = currentItem.path.replacingOccurrences(of: ".disabled", with: ".plist")
        } else if !newEnabled, currentItem.path.hasSuffix(".plist") {
            destinationPath = currentItem.path + ".disabled"
        } else {
            statusMessage = t("startup.changeFailPrefix") + currentItem.path + t("startup.changeFailSuffix")
            return
        }

        do {
            // 기존 목적지를 먼저 삭제하면 다른 설정 파일을 잃을 수 있으므로 충돌은 실패로 처리한다.
            guard !fileManager.fileExists(atPath: destinationPath) else {
                throw CocoaError(.fileWriteFileExists)
            }
            try fileManager.moveItem(atPath: currentItem.path, toPath: destinationPath)
            scanStartupItems()
        } catch {
            statusMessage = t("startup.changeFailPrefix") + error.localizedDescription
        }
    }

    /// 삭제는 관리자 권한 프롬프트와 파일 I/O를 동반하므로 메인 스레드를 막지 않도록 비동기 처리한다.
    func removeItem(_ item: LaunchAgentItem) {
        let url = URL(fileURLWithPath: item.path)
        Task {
            await FileSafety.moveToTrashAsync(url)
            self.scanStartupItems()
        }
    }


}
