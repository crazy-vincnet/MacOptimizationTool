import SwiftUI

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
            return [.diskCleaner, .largeFiles, .duplicateFinder, .uninstaller]
        case .tools:
            return [.startupManager, .winCompat, .maintenance]
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
    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.light.rawValue

    
    private var currentColorScheme: ColorScheme? {
        (AppTheme(rawValue: appThemeRaw) ?? .light).colorScheme
    }

    var body: some View {
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
        .frame(minWidth: 960, minHeight: 640)
        .preferredColorScheme(currentColorScheme)
        .alert(isPresented: $processGuard.showAlertModal) {
            if let proc = processGuard.alertProcess {
                return Alert(
                    title: Text("⚠️ 프로세스 자원 폭주 감지"),
                    message: Text("프로세스 '\(proc.name)'(PID: \(proc.pid))가 \(proc.reason.rawValue) 상태입니다.\n(CPU: \(Int(proc.cpuPercent))%, RAM: \(Int(proc.memoryMB)) MB)\n\n지금 강제 종료하시겠습니까?"),
                    primaryButton: .destructive(Text("프로세스 강제 종료"), action: {
                        processGuard.killAlertProcess()
                    }),
                    secondaryButton: .cancel(Text("무시하기"))
                )
            } else {
                return Alert(title: Text("알림"), message: Text(""), dismissButton: .default(Text("확인")))
            }
        }
    }



    // Top Global Header Bar
    private var topGlobalBar: some View {
        HStack(spacing: 12) {
            // Breadcrumb navigation
            HStack(spacing: 6) {
                Text("Lab98 Studio")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(Theme.textSecondary)

                Text("/")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Theme.hairline)
                Text(selectedTab.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
            }

            Spacer()

            // System Status Pill Badge
            HStack(spacing: 6) {
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 7, height: 7)
                Text(t("menu.operational"))

                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Theme.accent)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Theme.accentGlow)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Theme.accent.opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(12)

            // Environment badge
            Text("macOS Studio")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(Theme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.bgCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(Theme.hairline, lineWidth: 1)
                )
                .cornerRadius(4)
        }
        .padding(.horizontal, 24)
    }
    
    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 앱 타이틀 & 뱃지
            HStack(spacing: 12) {
                Image(systemName: "bolt.shield.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Theme.textOnAccent)
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Theme.accent)
                    )
                    .shadow(color: Theme.accent.opacity(0.35), radius: 8, y: 2)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Mac Clean")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    Text("Lab98 Studio")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(Theme.accent)
                }

            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 16)

            Divider()
                .background(Theme.hairline)

            // 카테고리별 사이드바 목록
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(MenuCategory.allCases) { category in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(category.rawValue)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(Theme.textSecondary.opacity(0.7))
                                .padding(.horizontal, 16)
                                .padding(.bottom, 2)

                            ForEach(category.tabs) { tab in
                                Button(action: {
                                    selectedTab = tab
                                }) {
                                    sidebarItem(for: tab, isSelected: selectedTab == tab)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 8)
            }

            Spacer(minLength: 0)

            Divider()
                .background(Theme.hairline)
            
            // 하단 상태 표시
            HStack(spacing: 8) {
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mac Clean Optimizer")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                    Text("© 2026 Lab98 Studio. All rights reserved.")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(Theme.textSecondary)
                }

            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }
    
    // 사이드바 개별 로우 뷰 디자인 (Supabase active item indicator)
    private func sidebarItem(for tab: MenuTab, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: tab.iconName)
                .font(.system(size: 14))
                .foregroundColor(isSelected ? Theme.accent : Theme.textSecondary)
                .frame(width: 18)
            
            Text(tab.displayName)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? Theme.textPrimary : Theme.textSecondary)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusControl, style: .continuous)
                .fill(
                    isSelected ? Theme.accentGlow :
                    (hoveredTab == tab ? Theme.bgCardHover : Color.clear)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusControl, style: .continuous)
                .stroke(isSelected ? Theme.accent.opacity(0.4) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { isHovered in
            if tab.isEnabled {
                hoveredTab = isHovered ? tab : nil
            }
        }
    }
}
