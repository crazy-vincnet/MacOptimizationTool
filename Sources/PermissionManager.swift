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
        
        // TCC로 보호되는 대표적인 사유 경로 검사
        let protectedPaths = [
            home.appendingPathComponent("Library/Safari/Bookmarks.plist").path,
            home.appendingPathComponent("Library/Messages/chat.db").path,
            home.appendingPathComponent("Library/Preferences/com.apple.TimeMachine.plist").path,
            "/Library/Preferences/com.apple.TimeMachine.plist"
        ]
        
        for path in protectedPaths {
            if FileManager.default.isReadableFile(atPath: path) {
                return true
            }
        }
        
        // 추가 TCC 폴더 열림 검사
        let testDir = home.appendingPathComponent("Library/Safari").path
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: testDir), !contents.isEmpty {
            return true
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
