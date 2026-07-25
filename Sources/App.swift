import SwiftUI
import AppKit
import UserNotifications

/// macOS 네이티브 앱 라이프사이클 및 윈도우 관리를 위한 델리게이트
class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    var statusItem: NSStatusItem?
    var telemetryTask: Task<Void, Never>?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 수동 컴파일 앱을 macOS GUI 앱으로 확실하게 활성화하여 도크(Dock)에 노출시키고 화면 전면으로 가져옵니다.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // UNUserNotificationCenter 델리게이트 설정 (포그라운드 알림 노출에 필수)
        UNUserNotificationCenter.current().delegate = self
        
        // 로컬 푸시 알림 권한 획득 요청
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, error in
            if let error = error {
                print("알림 권한 요청 중 에러 발생: \(error.localizedDescription)")
            }
        }
        
        setupMenuBar()
        Task { @MainActor in
            ProcessGuardManager.shared.startGuard()
        }

    }

    // 포그라운드(앱이 화면에 켜져있을 때) 알림도 배너, 리스트, 소리로 즉시 노출
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    
    // 메인 창을 닫아도 메뉴바 상태 아이콘이 살아있으므로 프로세스를 계속 유지시킵니다.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "bolt.shield.fill", accessibilityDescription: "Optimizer")
            button.imagePosition = .imageLeading
        }
        
        let menu = NSMenu()
        
        let headerItem = NSMenuItem(title: "Mac Clean Optimizer", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 실시간 정보 표시 아이템
        let cpuItem = NSMenuItem(title: "\(t("dash.cpu")): \(t("menu.scanning"))", action: nil, keyEquivalent: "")
        cpuItem.isEnabled = false
        let ramItem = NSMenuItem(title: "\(t("dash.memory")): \(t("menu.scanning"))", action: nil, keyEquivalent: "")
        ramItem.isEnabled = false
        
        menu.addItem(cpuItem)
        menu.addItem(ramItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 빠른 청소 및 메인 실행 제어
        let purgeItem = NSMenuItem(title: t("dash.optimize"), action: #selector(purgeMemoryFromMenuBar), keyEquivalent: "m")
        purgeItem.target = self
        menu.addItem(purgeItem)

        let openAppItem = NSMenuItem(title: t("menu.openMain"), action: #selector(openMainWindow), keyEquivalent: "o")
        openAppItem.target = self
        menu.addItem(openAppItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: t("menu.quit"), action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
        
        // AsyncStream 기반 비동기 텔레메트리 모니터링 가동 (Timer 대비 CPU 오버헤드 최소화)
        telemetryTask = Task { @MainActor in
            for await data in HardwareStatsHelper.startTelemetryStream() {
                cpuItem.title = String(format: "\(t("dash.cpu")): %.1f%%", data.cpuUsage)
                ramItem.title = String(format: "\(t("dash.memory")): %.1f%% (%@ / %@)",
                                       data.ramStats.percent,
                                       ByteCountFormatter.string(fromByteCount: data.ramStats.used, countStyle: .file),
                                       ByteCountFormatter.string(fromByteCount: data.ramStats.total, countStyle: .file))
            }
        }
    }
    
    @objc func purgeMemoryFromMenuBar() {
        Task(priority: .userInitiated) {
            let sizeBefore = HardwareStatsHelper.getRAMStats().free

            // macOS 빌트인 purge 로 비활성 메모리 회수 (임의 버퍼 할당 트릭 제거)
            let p = Process()
            p.launchPath = "/usr/sbin/purge"
            try? p.run()
            p.waitUntilExit()

            let sizeAfter = HardwareStatsHelper.getRAMStats().free
            let reclaimed = max(0, sizeAfter - sizeBefore)
            
            // 현대적인 UNUserNotificationCenter 알림 전송 (Async/Await 표준 사용)
            let content = UNMutableNotificationContent()
            content.title = t("menu.notif.title")
            content.body = "\(t("menu.notif.bodyPrefix"))\(ByteCountFormatter.string(fromByteCount: reclaimed, countStyle: .file))\(t("menu.notif.bodySuffix"))"
            content.sound = .default
            
            let request = UNNotificationRequest(
                identifier: "com.cleanoptimizer.ram_reclaimed",
                content: content,
                trigger: nil
            )
            do {
                try await UNUserNotificationCenter.current().add(request)
            } catch {
                print("메모리 최적화 완료 알림 전송 에러: \(error.localizedDescription)")
            }
        }
    }
    
    @objc func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    @objc func quitApp() {
        telemetryTask?.cancel()
        NSApplication.shared.terminate(nil)
    }
}

@main
struct MacCleanOptimizerApp: App {
    // AppDelegate 어댑터 장착
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unifiedCompact)
    }
}
