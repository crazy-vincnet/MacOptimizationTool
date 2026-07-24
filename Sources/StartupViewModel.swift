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
        let currentStatus = items[index].isEnabled
        let targetURL = item.url
        
        var destinationURL: URL
        if currentStatus {
            destinationURL = targetURL.deletingPathExtension().appendingPathExtension("plist.bak")
        } else {
            destinationURL = targetURL.deletingPathExtension().deletingPathExtension().appendingPathExtension("plist")
        }
        
        let isAccessed = targetURL.startAccessingSecurityScopedResource()
        defer {
            if isAccessed {
                targetURL.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            try fileManager.moveItem(at: targetURL, to: destinationURL)
            items[index].isEnabled = !currentStatus
            scanStartupItems() // 리로드
            
            alertMessage = "'\(item.name)' 항목의 자동 실행 설정을 \(currentStatus ? "비활성화" : "활성화")했습니다."
            showSuccessAlert = true
        } catch {
            print("시작 프로그램 변경 에러: \(error.localizedDescription)")
            alertMessage = "상태 변경 실패: 시스템 영역 (/Library) 수정을 위해서는 권한이 필요할 수 있습니다."
            showSuccessAlert = true
        }
    }
}
