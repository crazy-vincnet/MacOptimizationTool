import Foundation
import SwiftUI
import AppKit
import UserNotifications
import ServiceManagement
import MacOptimizationCore

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
    /// 릴리스 API 가 알려준 자산 SHA-256. 없으면 자동 마운트하지 않는다.
    @Published var updateExpectedSHA256: String? = nil
    @Published var hasNewVersion: Bool = false
    /// 확인 실패와 "최신 버전"은 서로 다른 결과다. 같은 문구로 묶으면 사용자가 오해한다.
    @Published var updateCheckFailed: Bool = false
    /// 다운로드·검증·마운트의 최종 결과. 오버레이가 사라진 뒤에도 남는다.
    @Published var updateResultMessage: String = ""
    /// 버튼을 누른 결과를 화면에 계속 표시하기 위한 상태.
    @Published var updateStatus: UpdateStatus = .idle

    enum UpdateStatus: Equatable {
        case idle
        case upToDate
        case newVersion
        case failed
        /// 다운로드·검증·마운트 결과 (성공/실패 문구는 updateResultMessage 에 담긴다).
        case installFinished
    }

    
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
    
    /// 현재 알림 권한 상태. `UNNotificationSettings` 는 Sendable 이 아니므로
    /// 완료 핸들러 안에서 필요한 값만 뽑아 액터 경계를 넘긴다.
    private static func currentAuthorizationStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    /// 알림 권한 체크
    func checkNotificationPermission() {
        Task { @MainActor in
            let status = await Self.currentAuthorizationStatus()
            self.notificationPermissionGranted = (status == .authorized || status == .provisional)
        }
    }
    
    /// 알림 권한 요청 및 시스템 설정 연결
    func requestNotificationPermission() {
        Task { @MainActor in
            let status = await Self.currentAuthorizationStatus()
            if status == .denied {
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
        content.title = t("notif.test.title")
        content.body = t("notif.test.body")
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
        // 누른 즉시 이전 결과를 지우고 진행 중임을 표시한다.
        updateStatus = .idle
        updateResultMessage = t("update.inline.checking")

        SparkleUpdaterManager.shared.checkForUpdates { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                self.updateAlertMessage = result.message
                self.updateURL = result.downloadURL
                self.updateExpectedSHA256 = result.expectedSHA256
                self.hasNewVersion = result.hasNewVersion
                self.updateCheckFailed = result.checkFailed
                self.isCheckingUpdate = false

                // 결과는 화면에 항상 남긴다. 알림 시트만으로는 사용자가 놓칠 수 있고,
                // 놓치면 "버튼이 아무 반응도 없다" 로 보인다.
                if result.checkFailed {
                    self.updateStatus = .failed
                    self.updateResultMessage = result.message
                } else if result.hasNewVersion {
                    self.updateStatus = .newVersion
                    self.updateResultMessage = String(format: t("update.inline.newVersion"), result.latestVersion)
                } else {
                    self.updateStatus = .upToDate
                    self.updateResultMessage = result.message
                }

                self.showUpdateAlert = true
            }
        }
    }

    /// 웹 브라우저 이동 없이 인앱 직접 다운로드 및 .dmg 디스크 마운트 실행.
    /// 릴리스 다이제스트와 해시가 일치할 때만 마운트된다.
    func startInAppUpdate() {
        guard let url = updateURL else { return }
        SparkleUpdaterManager.shared.startDirectDownloadAndInstall(from: url, expectedSHA256: updateExpectedSHA256)
    }



}
