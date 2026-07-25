import Foundation
import SwiftUI
import AppKit
import UserNotifications
import ServiceManagement

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var autoPurgeMemory: Bool {
        didSet {
            UserDefaults.standard.set(autoPurgeMemory, forKey: "autoPurgeMemory")
        }
    }
    
    @Published var memoryThreshold: Double {
        didSet {
            UserDefaults.standard.set(memoryThreshold, forKey: "memoryThreshold")
        }
    }
    
    @Published var enableNotifications: Bool {
        didSet {
            UserDefaults.standard.set(enableNotifications, forKey: "enableNotifications")
        }
    }
    
    @Published var runAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(runAtLogin, forKey: "runAtLogin")
            applyLoginItemState()
        }
    }

    /// UserDefaults 저장에 그치지 않고 실제 macOS 로그인 항목으로 등록/해제한다. (이전에는 no-op 버그)
    private func applyLoginItemState() {
        let service = SMAppService.mainApp
        do {
            if runAtLogin {
                if service.status != .enabled {
                    try service.register()
                }
            } else {
                if service.status == .enabled {
                    try service.unregister()
                }
            }
        } catch {
            // 서명되지 않은 수동 빌드에서는 실패할 수 있음 -> 상태를 실제 시스템 값으로 되돌린다.
            print("로그인 항목 등록/해제 실패: \(error.localizedDescription)")
            let actuallyEnabled = (SMAppService.mainApp.status == .enabled)
            if runAtLogin != actuallyEnabled {
                runAtLogin = actuallyEnabled
            }
        }
    }
    
    @Published var defaultScanFolderPath: String = ""
    @Published var defaultScanFolderURL: URL? = nil
    
    @Published var hasFullDiskAccess: Bool = false
    @Published var notificationPermissionGranted: Bool = false
    @Published var appTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(appTheme.rawValue, forKey: "appTheme")
        }
    }

    @Published var selectedLanguage: AppLanguage {
        didSet {
            LanguageManager.shared.currentLanguage = selectedLanguage
        }
    }
    
    @Published var isCheckingUpdate = false
    @Published var showUpdateAlert = false
    @Published var updateAlertMessage = ""
    @Published var updateURL: URL? = nil
    @Published var hasNewVersion: Bool = false

    
    private let fileManager = FileManager.default
    
    nonisolated static func getSavedDefaultScanURL() -> URL {
        if let bookmarkData = UserDefaults.standard.data(forKey: "defaultScanFolderBookmark") {
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) {
                _ = url.startAccessingSecurityScopedResource()
                return url
            }
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }
    
    init() {
        // 기본값 로드 및 UserDefaults 등록 (라이트 모드를 기본값으로 지정)
        let savedThemeRaw = UserDefaults.standard.string(forKey: "appTheme") ?? AppTheme.light.rawValue
        self.appTheme = AppTheme(rawValue: savedThemeRaw) ?? .light

        self.autoPurgeMemory = UserDefaults.standard.bool(forKey: "autoPurgeMemory")
        
        let savedThreshold = UserDefaults.standard.double(forKey: "memoryThreshold")
        self.memoryThreshold = savedThreshold > 0 ? savedThreshold : 20.0
        
        if UserDefaults.standard.object(forKey: "enableNotifications") == nil {
            self.enableNotifications = true
            UserDefaults.standard.set(true, forKey: "enableNotifications")
        } else {
            self.enableNotifications = UserDefaults.standard.bool(forKey: "enableNotifications")
        }
        
        // 실제 시스템 로그인 항목 등록 상태를 신뢰 소스로 사용 (UserDefaults 와 어긋날 수 있음)
        self.runAtLogin = (SMAppService.mainApp.status == .enabled)

        self.selectedLanguage = LanguageManager.shared.currentLanguage
        
        loadDefaultScanFolder()
        checkFullDiskAccess()
        checkNotificationPermission()
    }

    
    /// 저장된 보안 스코프 북마크를 기반으로 기본 스캔 경로 로드
    func loadDefaultScanFolder() {
        if let bookmarkData = UserDefaults.standard.data(forKey: "defaultScanFolderBookmark") {
            var isStale = false
            do {
                let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
                _ = url.startAccessingSecurityScopedResource()
                self.defaultScanFolderURL = url
                self.defaultScanFolderPath = url.path
                return
            } catch {
                print("보안 스코프 북마크 해석 실패: \(error.localizedDescription)")
            }
        }
        
        // 북마크가 없거나 실패 시 사용자 홈 디렉토리를 기본값으로 지정
        let home = fileManager.homeDirectoryForCurrentUser
        self.defaultScanFolderURL = home
        self.defaultScanFolderPath = home.path
    }
    
    /// 기본 스캔 경로 폴더 대화상자 선택 및 북마크 저장
    func selectDefaultFolder() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = false
        openPanel.title = t("settings.panelTitle")
        
        openPanel.begin { [weak self] response in
            guard let self = self else { return }
            if response == .OK, let url = openPanel.url {
                Task {
                    await self.saveDefaultFolder(url)
                }
            }
        }
    }
    
    private func saveDefaultFolder(_ url: URL) async {
        let isAccessed = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessed {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            // App Sandbox 환경에서 영구 유지를 위해 보안 지정 북마크 생성
            let bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmarkData, forKey: "defaultScanFolderBookmark")
            
            self.defaultScanFolderURL = url
            self.defaultScanFolderPath = url.path
        } catch {
            print("보안 북마크 데이터 생성 실패: \(error.localizedDescription)")
            self.defaultScanFolderURL = url
            self.defaultScanFolderPath = url.path
        }
    }
    
    /// 전체 디스크 접근 권한(FDA) 감지
    func checkFullDiskAccess() {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let safariURL = home.appendingPathComponent("Library/Safari")
        let mailURL = home.appendingPathComponent("Library/Mail")
        
        do {
            _ = try fm.contentsOfDirectory(at: safariURL, includingPropertiesForKeys: nil, options: [])
            self.hasFullDiskAccess = true
            return
        } catch {}
        
        do {
            _ = try fm.contentsOfDirectory(at: mailURL, includingPropertiesForKeys: nil, options: [])
            self.hasFullDiskAccess = true
            return
        } catch {}
        
        self.hasFullDiskAccess = false
    }
    
    /// 전체 디스크 접근 권한 설정을 위해 macOS 시스템 설정 열기
    func openSystemSettingsForFDA() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
    
    /// 알림 권한 체크 (Async/Await)
    func checkNotificationPermission() {
        Task { @MainActor in
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            self.notificationPermissionGranted = (settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional)
        }
    }
    
    /// 알림 권한 요청 및 시스템 설정 연결
    func requestNotificationPermission() {
        Task { @MainActor in
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            if settings.authorizationStatus == .denied {
                self.openSystemSettingsForNotifications()
                return
            }
            
            do {
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                self.notificationPermissionGranted = granted
                if !granted {
                    self.openSystemSettingsForNotifications()
                }
            } catch {
                print("알림 권한 요청 예외: \(error.localizedDescription)")
                self.openSystemSettingsForNotifications()
            }
        }
    }


    /// macOS 시스템 설정 (알림 설정) 열기
    func openSystemSettingsForNotifications() {
        let urlStrings = [
            "x-apple.systempreferences:com.apple.preference.notifications",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Notifications",
            "x-apple.systempreferences:com.apple.preference.security"
        ]
        for urlStr in urlStrings {
            if let url = URL(string: urlStr), NSWorkspace.shared.open(url) {
                break
            }
        }
    }

    /// 테스트 알림 직접 발송
    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Lab98 Studio 알림 서비스"
        content.body = "알림 권한 및 로컬 푸시 알림 서비스가 정상 작동 중입니다."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "com.cleanoptimizer.test_notification",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("테스트 알림 발송 실패: \(error.localizedDescription)")
            } else {
                print("테스트 알림 발송 성공")
            }
        }
    }

    
    /// Sparkle 2 / GitHub Release 기반 자동 업데이트 확인
    func checkForUpdates() {
        isCheckingUpdate = true
        
        SparkleUpdaterManager.shared.checkForUpdates { [weak self] result in
            Task { @MainActor in
                self?.updateAlertMessage = result.message
                self?.updateURL = result.downloadURL
                self?.hasNewVersion = result.hasNewVersion
                self?.isCheckingUpdate = false
                self?.showUpdateAlert = true
            }
        }
    }

    /// 웹 브라우저 이동 없이 인앱 직접 다운로드 및 .dmg 디스크 마운트 실행
    func startInAppUpdate() {
        guard let url = updateURL else { return }
        SparkleUpdaterManager.shared.startDirectDownloadAndInstall(from: url)
    }



}
