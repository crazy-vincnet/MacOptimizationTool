import Foundation
import AppKit
import UserNotifications

@MainActor
final class PermissionManager: ObservableObject {
    static let shared = PermissionManager()

    @Published var hasFullDiskAccess: Bool = false
    @Published var isChecking: Bool = false
    @Published var notificationStatus: UNAuthorizationStatus = .notDetermined

    private init() {
        checkPermissions()
    }

    /// macOS 전체 디스크 접근 권한(Full Disk Access) 정밀 상태 검사
    static func checkFDA() -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser
        
        let protectedPaths = [
            "/Library/Preferences/com.apple.TimeMachine.plist",
            home.appendingPathComponent("Library/Safari/Bookmarks.plist").path,
            home.appendingPathComponent("Library/Safari/History.db").path,
            home.appendingPathComponent("Library/Messages/chat.db").path,
            home.appendingPathComponent("Library/Cookies/Cookies.binarycookies").path,
            home.appendingPathComponent("Library/Preferences/com.apple.TimeMachine.plist").path
        ]
        
        for path in protectedPaths {
            if FileManager.default.fileExists(atPath: path) && FileManager.default.isReadableFile(atPath: path) {
                return true
            }
        }

        // TCC 전용 보호 디렉토리 접근 시도
        let protectedDirs = [
            home.appendingPathComponent("Library/Safari").path,
            home.appendingPathComponent("Library/Mail").path,
            home.appendingPathComponent("Library/Application Support/com.apple.TCC").path
        ]
        
        for dir in protectedDirs {
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: dir), !contents.isEmpty {
                return true
            }
        }
        
        return false
    }

    func checkPermissions() {
        isChecking = true
        let fda = Self.checkFDA()
        self.hasFullDiskAccess = fda
        self.isChecking = false

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                self.notificationStatus = settings.authorizationStatus
            }
        }
    }

    /// 사용자가 수동으로 권한 확인 완료 후 바로 통과할 수 있도록 강제 허용
    func bypassPermissionCheck() {
        self.hasFullDiskAccess = true
    }

    /// TCC 권한 반영을 위한 앱 프로세스 자동 재실행
    func relaunchApp() {
        let bundlePath = Bundle.main.bundlePath
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-n", bundlePath]
        try? task.run()
        NSApplication.shared.terminate(nil)
    }

    /// macOS 시스템 설정 > 프라이버시 및 보안 > 전체 디스크 접근 권한 페이지 직접 오픈
    func openSystemFDASettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    /// 선택형 로컬 알림 권한 요청
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
            Task { @MainActor in
                self.checkPermissions()
            }
        }
    }
}
