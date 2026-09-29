import Foundation
import SwiftUI
import MacOptimizationCore

struct MaintenanceTask: Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let color: Color
    var isRunning: Bool = false
    var isCompleted: Bool = false
    var statusMessage: String = t("maint.status.idle")
}

@MainActor
class MaintenanceViewModel: ObservableObject {
    @Published var tasks: [MaintenanceTask] = [
        MaintenanceTask(
            id: "dns",
            name: t("maint.task.dns.name"),
            description: t("maint.task.dns.desc"),
            icon: "network",
            color: .blue
        ),
        MaintenanceTask(
            id: "launchServices",
            name: t("maint.task.launchServices.name"),
            description: t("maint.task.launchServices.desc"),
            icon: "doc.badge.gearshape",
            color: .purple
        ),
        MaintenanceTask(
            id: "fontCache",
            name: t("maint.task.fontCache.name"),
            description: t("maint.task.fontCache.desc"),
            icon: "textformat",
            color: .orange
        ),
        MaintenanceTask(
            id: "spotlight",
            name: t("maint.task.spotlight.name"),
            description: t("maint.task.spotlight.desc"),
            icon: "magnifyingglass",
            color: .green
        )
    ]
    
    @Published var isAnyTaskRunning = false
    
    func runTask(id: String) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        guard !tasks[index].isRunning else { return }
        
        tasks[index].isRunning = true
        tasks[index].isCompleted = false
        tasks[index].statusMessage = t("maint.status.running")
        isAnyTaskRunning = true
        
        Task {
            let success = await Task.detached(priority: .userInitiated) { () -> Bool in
                switch id {
                case "dns":
                    return Self.flushDNS()
                case "launchServices":
                    return Self.rebuildLaunchServices()
                case "fontCache":
                    return Self.cleanFontCache()
                case "spotlight":
                    return Self.rebuildSpotlight()
                default:
                    return false
                }
            }.value
            
            self.tasks[index].isRunning = false
            self.tasks[index].isCompleted = true
            self.tasks[index].statusMessage = success ? t("maint.status.done") : t("maint.status.error")
            self.isAnyTaskRunning = self.tasks.contains(where: { $0.isRunning })
        }
    }
    
    func runAllTasks() {
        for task in tasks {
            runTask(id: task.id)
        }
    }
    
    // 1. DNS 캐시 플러시
    nonisolated private static func flushDNS() -> Bool {
        let cacheFlushed = SystemProcessRunner.run(
            executableURL: URL(fileURLWithPath: "/usr/bin/dscacheutil"),
            arguments: ["-flushcache"]
        )
        let responderReloaded = SystemProcessRunner.run(
            executableURL: URL(fileURLWithPath: "/usr/bin/killall"),
            arguments: ["-HUP", "mDNSResponder"]
        )
        return cacheFlushed && responderReloaded
    }
    
    // 2. LaunchServices DB 재구성
    nonisolated private static func rebuildLaunchServices() -> Bool {
        SystemProcessRunner.run(
            executableURL: URL(fileURLWithPath: "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"),
            arguments: ["-kill", "-r", "-domain", "local", "-domain", "system", "-domain", "user"]
        )
    }
    
    // 3. 폰트 캐시 지우기
    nonisolated private static func cleanFontCache() -> Bool {
        SystemProcessRunner.run(
            executableURL: URL(fileURLWithPath: "/usr/bin/atsutil"),
            arguments: ["databases", "-removeUser"]
        )
    }
    
    // 4. Spotlight 인덱스 재빌드
    nonisolated private static func rebuildSpotlight() -> Bool {
        SystemProcessRunner.run(
            executableURL: URL(fileURLWithPath: "/usr/bin/mdutil"),
            arguments: ["-E", FileManager.default.homeDirectoryForCurrentUser.path]
        )
    }
}
