import Foundation
import SwiftUI

struct MaintenanceTask: Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let color: Color
    var isRunning: Bool = false
    var isCompleted: Bool = false
    var statusMessage: String = "대기 중"
}

@MainActor
class MaintenanceViewModel: ObservableObject {
    @Published var tasks: [MaintenanceTask] = [
        MaintenanceTask(
            id: "dns",
            name: "DNS 캐시 초기화",
            description: "네트워크 접속이 느려지거나 웹페이지가 열리지 않을 때 로컬 DNS 주소 캐시를 비웁니다.",
            icon: "network",
            color: .blue
        ),
        MaintenanceTask(
            id: "launchServices",
            name: "연결 프로그램 데이터베이스 재구성",
            description: "우클릭 '다음으로 열기' 목록에 중복 앱이 나오거나 파일 연결 오류를 복구합니다.",
            icon: "doc.badge.gearshape",
            color: .purple
        ),
        MaintenanceTask(
            id: "fontCache",
            name: "시스템 폰트 캐시 정리",
            description: "화면의 텍스트가 깨져 보이거나 폰트 렌더링 에러가 있을 때 폰트 캐시를 청소합니다.",
            icon: "textformat",
            color: .orange
        ),
        MaintenanceTask(
            id: "spotlight",
            name: "Spotlight 검색 인덱스 재빌드",
            description: "Finder나 Spotlight에서 파일 검색이 정상 작동하지 않거나 느릴 때 인덱싱을 강제 재수행합니다.",
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
        tasks[index].statusMessage = "작업 진행 중..."
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
            self.tasks[index].statusMessage = success ? "완료됨" : "오류"
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
