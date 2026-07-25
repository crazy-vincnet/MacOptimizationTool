import SwiftUI
import AppKit
import UserNotifications
import MacOptimizationCore

/// macOS 네이티브 앱 라이프사이클 및 윈도우 관리를 위한 델리게이트
class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 수동 컴파일 앱을 macOS GUI 앱으로 확실하게 활성화하여 도크(Dock)에 노출시키고 화면 전면으로 가져옵니다.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // 초기 윈도우 크기를 권장 기본 크기(1100x720)로 정밀 조정 및 화면 중앙 배치
        DispatchQueue.main.async {
            if let window = NSApp.windows.first(where: { $0.isVisible || $0.canBecomeMain }) {
                window.setContentSize(NSSize(width: 1100, height: 720))
                window.center()
                window.makeKeyAndOrderFront(nil)
            }
        }

        // UNUserNotificationCenter 델리게이트 설정 (포그라운드 알림 노출에 필수)
        UNUserNotificationCenter.current().delegate = self
        
        // 로컬 푸시 알림 권한 획득 요청
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, error in
            if let error = error {
                print("알림 권한 요청 중 에러 발생: \(error.localizedDescription)")
            }
        }
        
        Task { @MainActor in
            MenuBarManager.shared.setupMenuBar()
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
    
}

@main
struct MacCleanOptimizerApp: App {
    // AppDelegate 어댑터 장착
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(minWidth: 960, idealWidth: 1100, maxWidth: .infinity, minHeight: 650, idealHeight: 720, maxHeight: .infinity)
        }
        .defaultSize(width: 1100, height: 720)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unifiedCompact)
    }
}
