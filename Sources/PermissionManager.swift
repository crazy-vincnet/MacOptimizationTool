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

    /// macOS 전체 디스크 접근 권한(Full Disk Access) 정밀 TCC 하드웨어 상태 검사
    /// isReadableFile(POSIX chmod) 대신 실시간 FileHandle open/read 테스트를 통해 TCC 차단 여부를 정밀 확인합니다.
    static func checkFDA() -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser
        
        let targetPaths = [
            "/Library/Preferences/com.apple.TimeMachine.plist",
            home.appendingPathComponent("Library/Safari/Bookmarks.plist").path,
            home.appendingPathComponent("Library/Safari/History.db").path,
            home.appendingPathComponent("Library/Messages/chat.db").path,
            home.appendingPathComponent("Library/Cookies/Cookies.binarycookies").path,
            home.appendingPathComponent("Library/Preferences/com.apple.TimeMachine.plist").path
        ]

        for path in targetPaths {
            if FileManager.default.fileExists(atPath: path) {
                let url = URL(fileURLWithPath: path)
                if let handle = try? FileHandle(forReadingFrom: url) {
                    try? handle.close()
                    return true
                }
            }
        }

        // TCC 디렉터리 열람 카운트 시도
        let targetDirs = [
            home.appendingPathComponent("Library/Safari").path,
            home.appendingPathComponent("Library/Mail").path
        ]

        for dir in targetDirs {
            if let enumerator = FileManager.default.enumerator(atPath: dir) {
                if enumerator.nextObject() != nil {
                    return true
                }
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
