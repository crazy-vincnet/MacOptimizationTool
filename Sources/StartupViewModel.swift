import Foundation
import SwiftUI
import AppKit

struct StartupItem: Identifiable, Hashable {
    let id: String // 파일 전체 경로
    let name: String
    let plistName: String
    let type: String // "사용자 에이전트" or "시스템 에이전트" or "시스템 데몬"
    let url: URL
    var isEnabled: Bool
    
    var isSystemProtected: Bool {
        return url.path.hasPrefix("/Library")
    }
}

@MainActor
class StartupViewModel: ObservableObject {
    @Published var items: [StartupItem] = []
    @Published var isScanning = false
    @Published var showSuccessAlert = false
    @Published var alertMessage = ""
    @Published var hasScanned = false
    
    private let fileManager = FileManager.default
    
    func scanStartupItems() {
        isScanning = true
        
        let userHome = fileManager.homeDirectoryForCurrentUser
        let userLaunchAgents = userHome.appendingPathComponent("Library/LaunchAgents")
        let systemLaunchAgents = URL(fileURLWithPath: "/Library/LaunchAgents")
        let systemLaunchDaemons = URL(fileURLWithPath: "/Library/LaunchDaemons")
        
        Task {
            let foundItems = await Task.detached(priority: .userInitiated) { [weak self] () -> [StartupItem] in
                guard let self = self else { return [] }
                var results: [StartupItem] = []
                
                results.append(contentsOf: self.scanDirectory(userLaunchAgents, type: "사용자 에이전트"))
                results.append(contentsOf: self.scanDirectory(systemLaunchAgents, type: "시스템 에이전트"))
                results.append(contentsOf: self.scanDirectory(systemLaunchDaemons, type: "시스템 데몬"))
                
                return results
            }.value
            
            self.items = foundItems
            self.isScanning = false
            self.hasScanned = true
        }
    }
    
    nonisolated private func scanDirectory(_ dirURL: URL, type: String) -> [StartupItem] {
        let fm = FileManager.default
        let isAccessed = dirURL.startAccessingSecurityScopedResource()
        defer {
            if isAccessed {
                dirURL.stopAccessingSecurityScopedResource()
            }
        }
        
        var dirItems: [StartupItem] = []
        guard let files = try? fm.contentsOfDirectory(at: dirURL, includingPropertiesForKeys: nil, options: []) else {
            return []
        }
        
        for url in files {
            let filename = url.lastPathComponent
            let isPlist = filename.hasSuffix(".plist")
            let isBak = filename.hasSuffix(".plist.bak")
            
            if isPlist || isBak {
                var labelName = url.deletingPathExtension().lastPathComponent
                if isBak {
                    labelName = url.deletingPathExtension().deletingPathExtension().lastPathComponent
                }
                
                if let plistData = try? Data(contentsOf: url),
                   let plistDict = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] {
                    if let label = plistDict["Label"] as? String {
                        labelName = label
                    }
                }
                
                let item = StartupItem(
                    id: url.path,
                    name: labelName,
                    plistName: filename,
                    type: type,
                    url: url,
                    isEnabled: isPlist
                )
                dirItems.append(item)
            }
        }
        return dirItems
    }
    
    func toggleItem(_ item: StartupItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }

        // 시스템 영역(/Library)은 관리자 권한이 필요하고 rename 이 조용히 실패한다.
        // 시도 후 실패 메시지 대신, 처음부터 명확히 차단한다.
        if item.isSystemProtected {
            alertMessage = "'\(item.name)'" + t("startup.systemProtectedMsg")
            showSuccessAlert = true
            return
        }

        let currentStatus = items[index].isEnabled
        let targetURL = item.url

        let destinationURL: URL
        if currentStatus {
            destinationURL = targetURL.deletingPathExtension().appendingPathExtension("plist.bak")
        } else {
            destinationURL = targetURL.deletingPathExtension().deletingPathExtension().appendingPathExtension("plist")
        }

        do {
            if currentStatus {
                // 비활성화: 먼저 launchd 에서 내린 뒤 .bak 으로 이름 변경
                Self.runLaunchctl(load: false, plistPath: targetURL.path)
                try fileManager.moveItem(at: targetURL, to: destinationURL)
            } else {
                // 활성화: .plist 로 복원한 뒤 launchd 에 등록
                try fileManager.moveItem(at: targetURL, to: destinationURL)
                Self.runLaunchctl(load: true, plistPath: destinationURL.path)
            }

            scanStartupItems() // 리로드
            alertMessage = "'\(item.name)'" + (currentStatus ? t("startup.disabledMsg") : t("startup.enabledMsg"))
            showSuccessAlert = true
        } catch {
            print("시작 프로그램 변경 에러: \(error.localizedDescription)")
            alertMessage = t("startup.changeFailPrefix") + "'\(item.name)'" + t("startup.changeFailSuffix") + " (\(error.localizedDescription))"
            showSuccessAlert = true
        }
    }

    /// 사용자 LaunchAgent 를 launchd 에 즉시 반영 (root 불필요). 실패해도 rename 자체는 유효.
    nonisolated private static func runLaunchctl(load: Bool, plistPath: String) {
        let p = Process()
        p.launchPath = "/bin/launchctl"
        p.arguments = [load ? "load" : "unload", plistPath]
        p.standardError = FileHandle.nullDevice
        p.standardOutput = FileHandle.nullDevice
        try? p.run()
        p.waitUntilExit()
    }
}
