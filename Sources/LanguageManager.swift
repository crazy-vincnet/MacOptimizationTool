import Foundation
import Combine

enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case korean = "ko"
    case english = "en"
    case chinese = "zh"
    case japanese = "ja"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .system:
            let systemLang = AppLanguage.detectSystemLanguage()
            switch systemLang {
            case .korean: return "시스템 기본값 (한국어)"
            case .chinese: return "System Default (简体中文)"
            case .japanese: return "System Default (日本語)"
            default: return "System Default (English)"
            }
        case .korean: return "한국어"
        case .english: return "English"
        case .chinese: return "简体中文"
        case .japanese: return "日本語"
        }
    }
    
    static func detectSystemLanguage() -> AppLanguage {
        guard let preferred = Locale.preferredLanguages.first?.lowercased() else {
            return .english
        }
        if preferred.hasPrefix("ko") {
            return .korean
        } else if preferred.hasPrefix("zh") {
            return .chinese
        } else if preferred.hasPrefix("ja") {
            return .japanese
        } else {
            return .english
        }
    }
}

class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    @Published var currentLanguage: AppLanguage = .system {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "appLanguage")
            objectWillChange.send()
        }
    }
    
    var effectiveLanguage: AppLanguage {
        if currentLanguage == .system {
            return AppLanguage.detectSystemLanguage()
        }
        return currentLanguage
    }
    
    private init() {
        if let raw = UserDefaults.standard.string(forKey: "appLanguage"),
           let lang = AppLanguage(rawValue: raw) {
            self.currentLanguage = lang
        } else {
            self.currentLanguage = .system
        }
    }
    
    func t(_ key: String) -> String {
        let lang = effectiveLanguage
        return Self.translations[lang]?[key] ?? Self.translations[.english]?[key] ?? key
    }

    /// 기본 사전 + 뷰별 생성 사전(GeneratedTranslations) 병합 결과.
    private static let translations: [AppLanguage: [String: String]] = {
        var merged = baseTranslations
        for (lang, dict) in GeneratedTranslations.all {
            merged[lang, default: [:]].merge(dict) { _, new in new }
        }
        return merged
    }()

    private static let baseTranslations: [AppLanguage: [String: String]] = [
        .korean: [
            "menu.dashboard": "대시보드",
            "menu.uninstaller": "앱 완전 삭제기",
            "menu.diskCleaner": "디스크 정리",
            "menu.largeFiles": "대용량 파일 정리",
            "menu.duplicateFinder": "중복 파일 정리",
            "menu.startupManager": "시작 프로그램",
            "menu.winCompat": "윈도우 이름 호환",
            "menu.maintenance": "시각적 디스크 맵",

            "menu.settings": "설정",
            "menu.operational": "정상 가동 중",
            
            "dash.title": "시스템 대시보드",
            "dash.subtitle": "실시간 시스템 자원 모니터링",
            "dash.cpu": "CPU 사용량",
            "dash.memory": "메모리 사용량",
            "dash.disk": "디스크 공간",
            "dash.free": "여유 공간",
            "dash.temp": "시스템 온도",
            "dash.battery": "배터리 건강",
            "dash.optimize": "메모리 즉시 최적화",
            "dash.appMem": "앱 메모리",
            "dash.wiredMem": "고정 메모리",
            "dash.compressedMem": "압축 메모리",
            
            "common.scanStart": "스캔 시작",
            "common.scanRestart": "재스캔",
            "common.delete": "삭제",
            "common.folder": "폴더 선택",
            "common.allowed": "허용됨",
            "common.actionRequired": "권한 필요",
            
            "settings.title": "설정 및 선호도",
            "settings.subtitle": "Mac Clean Optimizer의 백그라운드 작업, 시스템 권한, 스캔 규칙 등을 세부 설정합니다.",
            "settings.permissions": "macOS 시스템 접근 권한",
            "settings.fda": "전체 디스크 접근 권한 (Full Disk Access)",
            "settings.fdaDesc": "시스템 캐시 정리 및 대용량/중복 파일 탐색기가 Mac 전체 영역을 안전하고 완전하게 스캔하기 위해 필요합니다.",
            "settings.notifications": "알림 서비스 권한",
            "settings.notificationsDesc": "메모리 최적화 및 디스크 공간 청소 완료 상태 알림을 시스템 배너로 수신합니다.",
            "settings.sysSettings": "시스템 설정 열기",
            "settings.reqPerm": "권한 허용 요청",
            "settings.refresh": "권한 상태 갱신",
            "settings.autoOpt": "자동 최적화 및 알림",
            "settings.autoMem": "여유 메모리 부족 시 자동 해제 가동",
            "settings.autoMemDesc": "여유 메모리가 임계값 아래로 내려가면 시스템 캐시를 비워 물리 메모리를 추가 확보합니다.",
            "settings.memThresh": "자동 해제 메모리 임계값:",
            "settings.optNotif": "최적화 완료 알림 수신",
            "settings.optNotifDesc": "디스크 정리 완료 및 자동 메모리 복구가 수행되면 macOS 알림 배너로 알려줍니다.",
            "settings.scanSettings": "디스크 스캔 설정",
            "settings.defaultPath": "기본 스캔 타겟 경로",
            "settings.defaultPathDesc": "대용량 파일 탐색기와 중복 파일 찾기의 최초 타겟 기본 디렉토리 경로입니다.",
            "settings.selectPath": "경로 지정...",
            "settings.themeSettings": "테마 및 스킨 설정 (Appearance)",
            "settings.themeSelect": "앱 화면 테마",
            "settings.themeDesc": "라이트 모드(기본값), 다크 모드, 또는 macOS 시스템 설정 자동 동기화를 선택할 수 있습니다.",
            "theme.light": "라이트 모드",
            "theme.dark": "다크 모드",
            "theme.system": "시스템 설정 맞춤",
            "settings.langSettings": "언어 설정 (Language)",
            "settings.langSelect": "기본 표시 언어",
            "settings.langDesc": "Mac Clean Optimizer의 모든 화면 및 설명 언어를 설정합니다.",
            "settings.appStartup": "앱 시작 및 버전 정보",
            "settings.loginStart": "사용자 로그인 시 자동 시작",
            "settings.loginStartDesc": "Mac 부팅 및 로그인 완료 시 Mac Clean Optimizer를 자동 실행하여 백그라운드 보호 기능을 활성화합니다.",
            "settings.version": "현재 버전",
            "settings.buildDate": "빌드 일자",
            "settings.checkUpdate": "업데이트 확인",
            "settings.updateAlert": "현재 최신 버전(v%@)을 사용하고 있습니다.",

            "settings.testNotif": "테스트 알림"
        ],

        .english: [
            "menu.dashboard": "Dashboard",
            "menu.uninstaller": "App Uninstaller",
            "menu.diskCleaner": "Disk Cleaner",
            "menu.largeFiles": "Large Files Finder",
            "menu.duplicateFinder": "Duplicate Finder",
            "menu.startupManager": "Startup Items",
            "menu.winCompat": "Win Compatibility",
            "menu.maintenance": "System Maintenance",
            "menu.settings": "Settings",
            "menu.operational": "Operational",
            
            "dash.title": "System Dashboard",
            "dash.subtitle": "Real-time System Resource Monitoring",
            "dash.cpu": "CPU Usage",
            "dash.memory": "Memory Usage",
            "dash.disk": "Disk Space",
            "dash.free": "Free Space",
            "dash.temp": "System Temp",
            "dash.battery": "Battery Health",
            "dash.optimize": "Optimize Memory Now",
            "dash.appMem": "App Memory",
            "dash.wiredMem": "Wired Memory",
            "dash.compressedMem": "Compressed",
            
            "common.scanStart": "Start Scan",
            "common.scanRestart": "Rescan",
            "common.delete": "Delete",
            "common.folder": "Select Folder",
            "common.allowed": "Allowed",
            "common.actionRequired": "Action Required",
            
            "settings.title": "Settings & Preferences",
            "settings.subtitle": "Configure background tasks, system permissions, scan rules, and preferences for Mac Clean Optimizer.",
            "settings.permissions": "macOS System Access Permissions",
            "settings.fda": "Full Disk Access",
            "settings.fdaDesc": "Required for system cache cleaning, large file finders, and duplicate scanners to safely search your Mac.",
            "settings.notifications": "Notification Service",
            "settings.notificationsDesc": "Receive system banners for memory optimization and disk clean completion status.",
            "settings.sysSettings": "Open System Settings",
            "settings.reqPerm": "Request Permission",
            "settings.refresh": "Refresh Status",
            "settings.autoOpt": "Auto-Optimization & Alerts",
            "settings.autoMem": "Auto Purge Memory on Low Free RAM",
            "settings.autoMemDesc": "Purges inactive caches and memory when free RAM falls below threshold.",
            "settings.memThresh": "Auto Purge Threshold:",
            "settings.optNotif": "Receive Optimization Notifications",
            "settings.optNotifDesc": "Notifies via macOS banners when memory or disk optimization finishes.",
            "settings.scanSettings": "Disk Scanning Rules",
            "settings.defaultPath": "Default Target Folder",
            "settings.defaultPathDesc": "Default folder path targeted by Large Files and Duplicate Finder.",
            "settings.selectPath": "Choose Folder...",
            "settings.themeSettings": "Theme & Appearance",
            "settings.themeSelect": "App Theme",
            "settings.themeDesc": "Choose Light Mode (Default), Dark Mode, or Sync with System Preferences.",
            "theme.light": "Light Mode",
            "theme.dark": "Dark Mode",
            "theme.system": "Match System",
            "settings.langSettings": "Language Settings",
            "settings.langSelect": "Display Language",
            "settings.langDesc": "Set the display language for all screens and descriptions in Mac Clean Optimizer.",
            "settings.appStartup": "App Startup & Version",
            "settings.loginStart": "Launch Automatically at Login",
            "settings.loginStartDesc": "Automatically start Mac Clean Optimizer at login to enable background protection.",
            "settings.version": "Current Version",
            "settings.buildDate": "Build Date",
            "settings.checkUpdate": "Check for Updates",
            "settings.updateAlert": "You are currently running the latest version (v%@).",

            "settings.testNotif": "Test Notification"
        ],

        .chinese: [
            "menu.dashboard": "仪表板",
            "menu.uninstaller": "应用完全卸载",
            "menu.diskCleaner": "磁盘清理",
            "menu.largeFiles": "大文件清理",
            "menu.duplicateFinder": "重复文件清理",
            "menu.startupManager": "启动项管理",
            "menu.winCompat": "Windows兼容",
            "menu.maintenance": "系统维护",
            "menu.settings": "设置",
            "menu.operational": "运行正常",
            
            "dash.title": "系统仪表板",
            "dash.subtitle": "实时系统资源监控",
            "dash.cpu": "CPU 使用率",
            "dash.memory": "内存使用率",
            "dash.disk": "磁盘空间",
            "dash.free": "可用空间",
            "dash.temp": "系统温度",
            "dash.battery": "电池健康",
            "dash.optimize": "立即优化内存",
            "dash.appMem": "应用内存",
            "dash.wiredMem": "联动内存",
            "dash.compressedMem": "已压缩",
            
            "common.scanStart": "开始扫描",
            "common.scanRestart": "重新扫描",
            "common.delete": "删除",
            "common.folder": "选择文件夹",
            "common.allowed": "已允许",
            "common.actionRequired": "需要权限",
            
            "settings.title": "设置与偏好",
            "settings.subtitle": "详细配置 Mac Clean Optimizer 的后台任务、系统权限、扫描规则等。",
            "settings.permissions": "macOS 系统访问权限",
            "settings.fda": "完全磁盘访问权限 (Full Disk Access)",
            "settings.fdaDesc": "系统缓存清理和大文件/重复文件扫描器需要此权限以安全、完整地扫描您的 Mac 驱动器。",
            "settings.notifications": "通知服务权限",
            "settings.notificationsDesc": "通过系统横幅接收内存优化和磁盘空间清理完成的状态通知。",
            "settings.sysSettings": "打开系统设置",
            "settings.reqPerm": "请求允许权限",
            "settings.refresh": "刷新权限状态",
            "settings.autoOpt": "自动优化与通知",
            "settings.autoMem": "低内存时自动清理",
            "settings.autoMemDesc": "当可用内存低于阈值时，自动清理系统缓存以释放物理内存。",
            "settings.memThresh": "自动清理内存阈值:",
            "settings.optNotif": "接收优化完成通知",
            "settings.optNotifDesc": "当磁盘清理完成或自动内存恢复执行时，通过 macOS 通知横幅告知您。",
            "settings.scanSettings": "磁盘扫描设置",
            "settings.defaultPath": "默认扫描目标路径",
            "settings.defaultPathDesc": "大文件资源管理器和重复文件查找器的初始默认目录路径。",
            "settings.selectPath": "指定路径...",
            "settings.themeSettings": "主题与外观",
            "settings.themeSelect": "应用主题",
            "settings.themeDesc": "选择浅色模式(默认)、深色模式或跟随系统设置。",
            "theme.light": "浅色模式",
            "theme.dark": "深色模式",
            "theme.system": "跟随系统",
            "settings.langSettings": "语言设置",
            "settings.langSelect": "默认显示语言",
            "settings.langDesc": "设置 Mac Clean Optimizer 所有界面和说明的显示语言。",
            "settings.appStartup": "应用启动与版本信息",
            "settings.loginStart": "用户登录时自动启动",
            "settings.loginStartDesc": "在 Mac 启动并完成登录时自动运行 Mac Clean Optimizer 以激活后台保护功能。",
            "settings.version": "当前版本",
            "settings.buildDate": "构建日期",
            "settings.checkUpdate": "检查更新",
            "settings.updateAlert": "您当前使用的是最新版本 (v%@)。",

            "settings.testNotif": "测试通知"
        ],

        .japanese: [
            "menu.dashboard": "ダッシュボード",
            "menu.uninstaller": "アプリ完全削除",
            "menu.diskCleaner": "ディスククリーン",
            "menu.largeFiles": "大容量ファイル整理",
            "menu.duplicateFinder": "重複ファイル整理",
            "menu.startupManager": "スタートアップ管理",
            "menu.winCompat": "Windows名互換性",
            "menu.maintenance": "システムメンテナンス",
            "menu.settings": "設定",
            "menu.operational": "正常稼働中",
            
            "dash.title": "システムダッシュボード",
            "dash.subtitle": "リアルタイムシステムリソース監視",
            "dash.cpu": "CPU使用率",
            "dash.memory": "メモリ使用率",
            "dash.disk": "ディスク領域",
            "dash.free": "空き容量",
            "dash.temp": "システム温度",
            "dash.battery": "バッテリー状態",
            "dash.optimize": "メモリを今すぐ最適化",
            "dash.appMem": "Appメモリ",
            "dash.wiredMem": "確保中メモリ",
            "dash.compressedMem": "圧縮済み",
            
            "common.scanStart": "スキャン開始",
            "common.scanRestart": "再スキャン",
            "common.delete": "削除",
            "common.folder": "フォルダ選択",
            "common.allowed": "許可済み",
            "common.actionRequired": "権限が必要",
            
            "settings.title": "設定と環境設定",
            "settings.subtitle": "Mac Clean Optimizer のバックグラウンド処理、システム権限、スキャン規則などを詳細に設定します。",
            "settings.permissions": "macOS システムアクセス権限",
            "settings.fda": "フルディスクアクセス権限 (Full Disk Access)",
            "settings.fdaDesc": "システムキャッシュのクリーンアップや大容量/重複ファイルのスキャナーが Mac 全体を安全かつ完全にスキャンするために必要です。",
            "settings.notifications": "通知サービス権限",
            "settings.notificationsDesc": "メモリ最適化やディスク領域クリーンアップ完了時のステータス通知をシステムバナーで受信します。",
            "settings.sysSettings": "システム設定を開く",
            "settings.reqPerm": "権限の許可を要求",
            "settings.refresh": "権限ステータス更新",
            "settings.autoOpt": "自動最適化と通知",
            "settings.autoMem": "メモリ不足時の自動解放を有効化",
            "settings.autoMemDesc": "空きメモリがしきい値を下回ると、システムキャッシュをクリアして物理メモリをさらに確保します。",
            "settings.memThresh": "自動解放メモリしきい値:",
            "settings.optNotif": "最適化完了通知を受信",
            "settings.optNotifDesc": "ディスククリーンアップの完了や自動メモリ回復が実行された際に、macOS 通知バナーでお知らせします。",
            "settings.scanSettings": "ディスクスキャン設定",
            "settings.defaultPath": "デフォルトスキャン対象パス",
            "settings.defaultPathDesc": "大容量ファイル探索と重複ファイル検索の初回対象デフォルトディレクトリパスです。",
            "settings.selectPath": "パス指定...",
            "settings.langSettings": "言語設定 (Language)",
            "settings.langSelect": "デフォルトの表示言語",
            "settings.langDesc": "Mac Clean Optimizer のすべての画面と説明の表示言語を設定します。",
            "settings.appStartup": "アプリ起動とバージョン情報",
            "settings.loginStart": "ログイン時に自動起動",
            "settings.loginStartDesc": "Mac 起動およびログイン完了時に Mac Clean Optimizer を自動実行し、バックグラウンド保護機能を有効にします。",
            "settings.version": "現在のバージョン",
            "settings.buildDate": "ビルド日付",
            "settings.checkUpdate": "アップデートを確認",
            "settings.updateAlert": "現在、最新バージョン (v%@) を使用しています。",

            "settings.testNotif": "テスト通知"
        ]
    ]
}

/// 전역 번역 단축 헬퍼 함수
func t(_ key: String) -> String {
    return LanguageManager.shared.t(key)
}
