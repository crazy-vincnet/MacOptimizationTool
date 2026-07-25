import Foundation
import Combine

struct LaunchAgentItem: Identifiable {
    let id = UUID()
    let name: String
    let label: String
    let path: String
    let type: StartupType
    var isEnabled: Bool
}

enum StartupType: String, CaseIterable {
    case userAgent = "사용자 시작 에이전트"
    case systemAgent = "시스템 에이전트"
    case systemDaemon = "시스템 데몬"

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
            self.statusMessage = "총 \(items.count)개의 시작 및 백그라운드 에이전트가 발견되었습니다."
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
        guard let index = startupItems.firstIndex(where: { $0.id == item.id }) else { return }
        let currentItem = startupItems[index]
        let newEnabled = !currentItem.isEnabled

        if newEnabled {
            if currentItem.path.hasSuffix(".disabled") {
                let newPath = currentItem.path.replacingOccurrences(of: ".disabled", with: ".plist")
                try? fileManager.removeItem(atPath: newPath)
                try? fileManager.moveItem(atPath: currentItem.path, toPath: newPath)
            }
        } else {
            if currentItem.path.hasSuffix(".plist") {
                let newPath = currentItem.path + ".disabled"
                try? fileManager.removeItem(atPath: newPath)
                try? fileManager.moveItem(atPath: currentItem.path, toPath: newPath)
            }
        }


        startupItems[index].isEnabled = newEnabled
        scanStartupItems()
    }

    func removeItem(_ item: LaunchAgentItem) {
        FileSafety.moveToTrash(URL(fileURLWithPath: item.path))
        scanStartupItems()
    }


}
