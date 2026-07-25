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
            let success = await Task.detached(priority: .userInitiated) { [weak self] () -> Bool in
                guard let self = self else { return false }
                switch id {
                case "dns":
                    return self.flushDNS()
                case "launchServices":
                    return self.rebuildLaunchServices()
                case "fontCache":
                    return self.cleanFontCache()
                case "spotlight":
                    return self.rebuildSpotlight()
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
    nonisolated private func flushDNS() -> Bool {
        let p1 = Process()
        p1.launchPath = "/usr/bin/dscacheutil"
        p1.arguments = ["-flushcache"]
        try? p1.run()
        p1.waitUntilExit()
        
        let p2 = Process()
        p2.launchPath = "/usr/bin/killall"
        p2.arguments = ["-HUP", "mDNSResponder"]
        try? p2.run()
        p2.waitUntilExit()
        
        return true
    }
    
    // 2. LaunchServices DB 재구성
    nonisolated private func rebuildLaunchServices() -> Bool {
        let p = Process()
        p.launchPath = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
        p.arguments = ["-kill", "-r", "-domain", "local", "-domain", "system", "-domain", "user"]
        try? p.run()
        p.waitUntilExit()
        return p.terminationStatus == 0
    }
    
    // 3. 폰트 캐시 지우기
    nonisolated private func cleanFontCache() -> Bool {
        let p = Process()
        p.launchPath = "/usr/bin/atsutil"
        p.arguments = ["databases", "-removeUser"]
        try? p.run()
        p.waitUntilExit()
        return p.terminationStatus == 0
    }
    
    // 4. Spotlight 인덱스 재빌드
    nonisolated private func rebuildSpotlight() -> Bool {
        let p = Process()
        p.launchPath = "/usr/bin/mdutil"
        let homePath = FileManager.default.homeDirectoryForCurrentUser.path
        p.arguments = ["-E", homePath]
        try? p.run()
        p.waitUntilExit()
        return p.terminationStatus == 0
    }
}
