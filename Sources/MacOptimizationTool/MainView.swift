import SwiftUI
import UserNotifications
import MacOptimizationCore


/// 사이드바 카테고리 그룹
enum MenuCategory: String, CaseIterable, Identifiable {
    case overview = "OVERVIEW"
    case storage = "STORAGE & CLEANUP"
    case tools = "SYSTEM TOOLS"
    case preferences = "PREFERENCES"

    var id: String { self.rawValue }

    var tabs: [MenuTab] {
        switch self {
        case .overview:
            return [.dashboard]
        case .storage:
            return [.diskCleaner, .largeFiles, .duplicateFinder, .privacyCleaner, .oldDownloads, .uninstaller]
        case .tools:
            return [.diskHealth, .startupManager, .winCompat, .maintenance]
        case .preferences:
            return [.settings]
        }
    }
}

/// 사이드바 메뉴 정의
enum MenuTab: String, CaseIterable, Identifiable {
    case dashboard
    case uninstaller
    case diskCleaner
    case largeFiles
    case duplicateFinder
    case privacyCleaner
    case oldDownloads
    case diskHealth
    case startupManager
    case winCompat
    case maintenance
    case settings
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .dashboard: return t("menu.dashboard")
        case .uninstaller: return t("menu.uninstaller")
        case .diskCleaner: return t("menu.diskCleaner")
        case .largeFiles: return t("menu.largeFiles")
        case .duplicateFinder: return t("menu.duplicateFinder")
        case .privacyCleaner: return t("menu.privacyCleaner")
        case .oldDownloads: return t("menu.oldDownloads")
        case .diskHealth: return t("menu.diskHealth")
        case .startupManager: return t("menu.startupManager")
        case .winCompat: return t("menu.winCompat")
        case .maintenance: return t("menu.maintenance")
        case .settings: return t("menu.settings")
        }
    }
    
    var iconName: String {
        switch self {
        case .dashboard: return "square.grid.2x2.fill"
        case .uninstaller: return "trash.fill"
        case .diskCleaner: return "leaf.fill"
        case .largeFiles: return "doc.text.magnifyingglass"
        case .duplicateFinder: return "doc.on.doc.fill"
        case .privacyCleaner: return "lock.shield.fill"
        case .oldDownloads: return "archivebox.circle.fill"
        case .diskHealth: return "waveform.path.ecg"
        case .startupManager: return "cpu.fill"
        case .winCompat: return "arrow.triangle.2.circlepath"
        case .maintenance: return "wrench.and.screwdriver.fill"
        case .settings: return "gearshape.fill"
        }
    }
    
    var isEnabled: Bool {
        return true
    }
}

struct MainView: View {
    @State private var selectedTab: MenuTab = .dashboard
    @State private var hoveredTab: MenuTab? = nil
    @ObservedObject private var langManager = LanguageManager.shared
    @ObservedObject private var processGuard = ProcessGuardManager.shared
    @ObservedObject private var duplicateVM = DuplicateViewModel.shared
    @ObservedObject private var largeVM = LargeFilesViewModel.shared
    @ObservedObject private var diskCleanVM = DiskCleanViewModel.shared
    @ObservedObject private var uninstallerVM = UninstallerViewModel.shared
    @ObservedObject private var privacyVM = PrivacyCleanerViewModel.shared
    @ObservedObject private var oldDownloadsVM = OldDownloadsViewModel.shared
    @ObservedObject private var diskHealthVM = DiskHealthViewModel.shared
    @ObservedObject private var permissionManager = PermissionManager.shared
    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.light.rawValue

    private var currentColorScheme: ColorScheme? {
        (AppTheme(rawValue: appThemeRaw) ?? .light).colorScheme
    }

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                // 사이드바 영역 (Supabase Studio)
                sidebarView
                    .frame(width: 240)
                    .background(Theme.bgSidebar)
                    .overlay(alignment: .trailing) {
                        Rectangle().fill(Theme.hairline).frame(width: 1)
                    }

                // 메인 콘텐츠 영역 (상단 헤더 바 + 탭 영역)
                VStack(spacing: 0) {
                    // Top Global Bar
                    topGlobalBar
                        .frame(height: 48)
                        .background(Theme.bgSidebar)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(Theme.hairline).frame(height: 1)
                        }

                    ZStack {
                        Theme.appBackground.ignoresSafeArea()

                        Group {
                            switch selectedTab {
                            case .dashboard:
                                DashboardView()
                            case .uninstaller:
                                UninstallerView()
                            case .diskCleaner:
                                DiskCleanerView()
                            case .largeFiles:
                                LargeFilesView()
                            case .duplicateFinder:
                                DuplicateView()
                            case .privacyCleaner:
                                PrivacyCleanerView()
                            case .oldDownloads:
                                OldDownloadsView()
                            case .diskHealth:
                                DiskHealthView()
                            case .startupManager:
                                StartupManagerView()
                            case .winCompat:
                                WinCompatView()
                            case .maintenance:
                                DiskSunburstView()
                            case .settings:
                                SettingsView()
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                        .id(selectedTab)
                    }
                    .animation(.easeInOut(duration: 0.18), value: selectedTab)
                }
            }

            // 필수 시스템 전체 디스크 접근 권한 미승인 시 앱 접근 차단 모달 노출
            if !permissionManager.hasFullDiskAccess {
                PermissionModalView()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: permissionManager.hasFullDiskAccess)
        .onAppear {
            permissionManager.checkPermissions()
        }
        .frame(minWidth: 960, minHeight: 640)
        .preferredColorScheme(currentColorScheme)
        .alert(isPresented: $processGuard.showAlertModal) {
            if let proc = processGuard.alertProcess {
                return Alert(
                    title: Text(t("guard.alert.title")),
                    message: Text(String(format: t("guard.alert.message"),
                                         proc.name,
                                         String(proc.pid),
                                         proc.reason.localizedDescription,
                                         Int(proc.cpuPercent),
                                         Int(proc.memoryMB))),
                    primaryButton: .destructive(Text(t("guard.alert.kill")), action: {
                        processGuard.killAlertProcess()
                    }),
                    secondaryButton: .cancel(Text(t("guard.alert.ignore")), action: {
                        processGuard.dismissAlert()
                    })
                )
            } else {
                return Alert(title: Text(t("common.notice")))
            }
        }
    }

    // Top Global Bar Component
    private var topGlobalBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: selectedTab.iconName)
                    .foregroundColor(Theme.accent)
                    .font(.system(size: 13, weight: .bold))
                Text(selectedTab.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
            }
            .padding(.leading, 18)

            Spacer()

            // 언어 선택 드롭다운 피커
            Picker("", selection: $langManager.currentLanguage) {
                ForEach(AppLanguage.allCases) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 140)
            .tint(Theme.accent)

            // 글로벌 테마 토글 (Dark / Light)
            Button(action: {
                let current = AppTheme(rawValue: appThemeRaw) ?? .light
                let next: AppTheme = (current == .dark) ? .light : .dark
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    appThemeRaw = next.rawValue
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: (AppTheme(rawValue: appThemeRaw) ?? .light) == .dark ? "sun.max.fill" : "moon.fill")
                        .foregroundColor((AppTheme(rawValue: appThemeRaw) ?? .light) == .dark ? .orange : Theme.accent)
                    Text((AppTheme(rawValue: appThemeRaw) ?? .light) == .dark ? "Light" : "Dark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: Theme.radiusChip, style: .continuous)
                        .fill(Theme.bgCardHover)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusChip, style: .continuous)
                        .stroke(Theme.hairline, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .help(t("common.toggleTheme"))

            // 글로벌 메모리 퍼지 버튼
            Button(action: {
                Task {
                    let before = HardwareStatsHelper.getRAMStats()?.free
                    await Task.detached(priority: .userInitiated) {
                        let p = Process()
                        p.executableURL = URL(fileURLWithPath: "/usr/sbin/purge")
                        try? p.run()
                        p.waitUntilExit()
                    }.value
                    let after = HardwareStatsHelper.getRAMStats()?.free
                    // 측정 실패 시 0 으로 표기해 회수량을 지어내지 않는다.
                    let reclaimed: Int64 = {
                        guard let before, let after else { return 0 }
                        return max(0, after - before)
                    }()

                    let content = UNMutableNotificationContent()
                    content.title = t("menu.notif.title")
                    content.body = "\(t("menu.notif.bodyPrefix"))\(ByteCountFormatter.string(fromByteCount: reclaimed, countStyle: .file))\(t("menu.notif.bodySuffix"))"
                    content.sound = .default
                    let req = UNNotificationRequest(identifier: "quick_purge_\(Date().timeIntervalSince1970)", content: content, trigger: nil)
                    try? await UNUserNotificationCenter.current().add(req)
                }
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(Theme.accent)
                        .font(.system(size: 11))
                    Text(t("dash.optimize"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: Theme.radiusChip, style: .continuous)
                        .fill(Theme.accent.opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusChip, style: .continuous)
                        .stroke(Theme.accent.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .padding(.trailing, 18)
        }
    }

    // Sidebar Component
    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header / App Title
            HStack(spacing: 10) {
                Image(systemName: "bolt.shield.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.accentGradient)

                VStack(alignment: .leading, spacing: 1) {
                    Text("MacOptimizationTool")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                    // 번들 버전을 그대로 읽어 릴리스마다 문자열이 어긋나지 않게 한다.
                    Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0") • Studio Edition")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 16)

            Divider()
                .background(Theme.hairline)

            // Navigation Item Groups
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(MenuCategory.allCases) { category in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(category.rawValue)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Theme.textSecondary.opacity(0.6))
                                .padding(.horizontal, 16)
                                .padding(.top, 4)

                            ForEach(category.tabs) { tab in
                                sidebarItem(for: tab)
                            }
                        }
                    }
                }
                .padding(.vertical, 12)
            }

            Spacer(minLength: 10)

            Divider()
                .background(Theme.hairline)

            // Footer Status Indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text("MacOptimizationTool")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                    Text("© 2026 Lab98 Studio. All rights reserved.")
                        .font(.system(size: 8))
                        .foregroundColor(Theme.textSecondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private func sidebarItem(for tab: MenuTab) -> some View {
        let isSelected = (selectedTab == tab)
        let isHovered = (hoveredTab == tab)

        return Button(action: {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                selectedTab = tab
            }
        }) {
            HStack(spacing: 10) {
                Image(systemName: tab.iconName)
                    .font(.system(size: 13, weight: isSelected ? .bold : .regular))
                    .foregroundColor(isSelected ? Theme.accent : (isHovered ? Theme.textPrimary : Theme.textSecondary))
                    .frame(width: 18)

                Text(tab.displayName)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? Theme.textPrimary : Theme.textSecondary)
                
                Spacer()

                let isScanningTab = (tab == .duplicateFinder && duplicateVM.isScanning) ||
                                    (tab == .largeFiles && largeVM.isScanning) ||
                                    (tab == .diskCleaner && diskCleanVM.isScanning) ||
                                    (tab == .uninstaller && (uninstallerVM.isScanning || uninstallerVM.isSearchingApps)) ||
                                    (tab == .privacyCleaner && privacyVM.isScanning) ||
                                    (tab == .oldDownloads && oldDownloadsVM.isScanning)

                if isScanningTab {
                    ProgressView()
                        .scaleEffect(0.55)
                        .frame(width: 14, height: 14)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusControl, style: .continuous)
                    .fill(isSelected ? Theme.bgCardHover : (isHovered ? Theme.bgCardHover.opacity(0.5) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusControl, style: .continuous)
                    .stroke(isSelected ? Theme.accent.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .padding(.horizontal, 10)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredTab = hovering ? tab : nil
        }
    }
}
