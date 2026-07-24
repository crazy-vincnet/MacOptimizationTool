import SwiftUI

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
    
    var body: some View {
        HStack(spacing: 0) {
            // 사이드바 영역 (글래스)
            sidebarView
                .frame(width: 236)
                .background(.regularMaterial)
                .overlay(alignment: .trailing) {
                    Rectangle().fill(Theme.hairlineSoft).frame(width: 1)
                }

            // 메인 콘텐츠 영역
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
                        StartupView()
                    case .winCompat:
                        WinCompatView()
                    case .maintenance:
                        MaintenanceView()
                    case .settings:
                        SettingsView()
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .trailing)))
                .id(selectedTab)
            }
            .animation(.easeInOut(duration: 0.2), value: selectedTab)
        }
        .frame(minWidth: 900, minHeight: 600)
        .preferredColorScheme(.light)
    }
    
    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 앱 타이틀
            HStack(spacing: 12) {
                Image(systemName: "bolt.shield.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.textOnAccent)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(Theme.accentGradient)
                    )
                    .shadow(color: Theme.accent.opacity(0.3), radius: 6, y: 3)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Mac Clean Optimizer")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    Text("v1.0.0")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 30)
            .padding(.bottom, 10)
            
            // 사이드바 항목 목록
            VStack(spacing: 6) {
                ForEach(MenuTab.allCases) { tab in
                    if tab.isEnabled {
                        Button(action: {
                            selectedTab = tab
                        }) {
                            sidebarItem(for: tab, isSelected: selectedTab == tab)
                        }
                        .buttonStyle(.plain)
                    } else {
                        // 비활성화된 탭 (추후 확장용)
                        sidebarItem(for: tab, isSelected: false)
                            .opacity(0.4)
                            .help("준비 중인 기능입니다 (다음 업데이트 예정)")
                    }
                }
            }
            .padding(.horizontal, 10)
            
            Spacer()
            
            // 하단 상태 표시 또는 회사정보
            VStack(alignment: .leading, spacing: 5) {
                Text(t("main.footer.title"))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Theme.accent)
                Text(t("main.footer.sub"))
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 25)
        }
    }
    
    // 사이드바 개별 로우 뷰 디자인
    private func sidebarItem(for tab: MenuTab, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: tab.iconName)
                .font(.system(size: 16))
                .foregroundColor(isSelected ? .white : .secondary)
                .frame(width: 20)
            
            Text(tab.displayName)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : .primary)
            
            Spacer()
            
            if !tab.isEnabled {
                Text("곧 추가됨")
                    .font(.system(size: 9, weight: .semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(5)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusControl, style: .continuous)
                .fill(
                    isSelected ?
                    AnyShapeStyle(Theme.accentGradient) :
                    AnyShapeStyle(hoveredTab == tab ? Color.primary.opacity(0.06) : Color.clear)
                )
                .shadow(color: isSelected ? Theme.accent.opacity(0.28) : .clear, radius: 8, y: 3)
        )
        .contentShape(Rectangle())
        .onHover { isHovered in
            if tab.isEnabled {
                hoveredTab = isHovered ? tab : nil
            }
        }
    }
}
