import SwiftUI
import MacOptimizationCore

enum SettingsSection: String, CaseIterable, Identifiable {
    case permissions
    case autoOpt
    case scanPaths
    case theme
    case language
    case about

    var id: String { self.rawValue }

    var title: String {
        switch self {
        case .permissions: return t("settings.permissions")
        case .autoOpt: return t("settings.autoOpt")
        case .scanPaths: return t("settings.scanSettings")
        case .theme: return t("settings.themeSettings")
        case .language: return t("settings.langSettings")
        case .about: return t("settings.appStartup")
        }
    }

    var icon: String {
        switch self {
        case .permissions: return "lock.shield.fill"
        case .autoOpt: return "cpu.fill"
        case .scanPaths: return "folder.badge.gearshape.fill"
        case .theme: return "sun.max.fill"
        case .language: return "globe"
        case .about: return "info.circle.fill"
        }
    }
}

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @ObservedObject private var langManager = LanguageManager.shared
    @State private var selectedSection: SettingsSection = .permissions
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Page Header
            PageHeader(
                title: t("settings.title"),
                subtitle: t("settings.subtitle"),
                icon: "gearshape.fill"
            )
            .padding(.horizontal, Theme.pagePadding)
            .padding(.top, Theme.pagePadding)
            .padding(.bottom, 20)

            // Studio 2-Column Layout
            HStack(alignment: .top, spacing: 20) {
                // Left Sub-category Menu
                leftSidebarMenu

                // Right Content Area
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        switch selectedSection {
                        case .permissions:
                            permissionsCard
                        case .autoOpt:
                            autoOptCard
                        case .scanPaths:
                            scanPathsCard
                        case .theme:
                            themeCard
                        case .language:
                            languageCard
                        case .about:
                            aboutCard
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            .padding(.horizontal, Theme.pagePadding)
            .padding(.bottom, Theme.pagePadding)
        }
        .alert(isPresented: $viewModel.showUpdateAlert) {
            if viewModel.hasNewVersion {
                Alert(
                    title: Text(t("update.alert.newTitle")),
                    message: Text(viewModel.updateAlertMessage),
                    primaryButton: .default(Text(t("update.alert.installNow")), action: {
                        viewModel.startInAppUpdate()
                    }),
                    secondaryButton: .cancel(Text(t("disk.cancel")))
                )
            } else {
                Alert(
                    title: Text(t("settings.checkUpdate")),
                    message: Text(String(format: t("update.alert.redownloadMessage"), viewModel.updateAlertMessage)),
                    primaryButton: .default(Text(t("update.alert.redownload")), action: {
                        viewModel.startInAppUpdate()
                    }),
                    secondaryButton: .cancel(Text(t("common.ok")))
                )
            }
        }

        .overlay {
            if SparkleUpdaterManager.shared.isDownloading {
                ZStack {
                    Theme.bgCardHover.opacity(0.85)
                        .edgesIgnoringSafeArea(.all)

                    VStack(spacing: 16) {
                        ProgressView(value: SparkleUpdaterManager.shared.downloadProgress)
                            .progressViewStyle(.linear)
                            .tint(Theme.accent)
                            .frame(width: 260)

                        Text(SparkleUpdaterManager.shared.statusMessage)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.textPrimary)
                    }
                    .padding(24)
                    .glassCard(padding: 24, radius: Theme.radiusCard)
                }
            }
        }


    }

    // MARK: - Left Sidebar Navigation Menu
    private var leftSidebarMenu: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(SettingsSection.allCases) { section in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedSection = section
                    }
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: section.icon)
                            .font(.system(size: 13))
                            .foregroundColor(selectedSection == section ? Theme.accent : Theme.textSecondary)
                            .frame(width: 18)

                        Text(section.title)
                            .font(.system(size: 12, weight: selectedSection == section ? .semibold : .regular))
                            .foregroundColor(selectedSection == section ? Theme.textPrimary : Theme.textSecondary)

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.radiusControl)
                            .fill(selectedSection == section ? Theme.accentGlow : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusControl)
                            .stroke(selectedSection == section ? Theme.accent.opacity(0.35) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .frame(width: 200)
        .glassCard(padding: 10, radius: Theme.radiusCard)
    }

    // MARK: - Reusable Card Components

    private func settingsCardHeader(title: String, icon: String, action: (() -> Void)? = nil, actionTitle: String? = nil) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(Theme.accent)
                .font(.system(size: 16, weight: .bold))

            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Theme.textPrimary)

            Spacer()

            if let action, let actionTitle {
                Button(action: action) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10, weight: .bold))
                        Text(actionTitle)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(Theme.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 6)
    }

    private func statusBadge(isAllowed: Bool) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isAllowed ? Theme.accent : Theme.danger)
                .frame(width: 6, height: 6)
            Text(isAllowed ? t("common.allowed") : t("common.actionRequired"))
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(isAllowed ? Theme.accent : Theme.danger)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(isAllowed ? Theme.accentGlow : Theme.dangerBg)
        .cornerRadius(6)
    }

    // MARK: - 1. Permissions Card
    private var permissionsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            settingsCardHeader(
                title: t("settings.permissions"),
                icon: "lock.shield.fill",
                action: {
                    viewModel.checkFullDiskAccess()
                    viewModel.checkNotificationPermission()
                },
                actionTitle: t("settings.refresh")
            )

            // FDA Row
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: "opticaldisc")
                    .font(.title3)
                    .foregroundColor(Theme.textSecondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(t("settings.fda"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.textPrimary)

                        statusBadge(isAllowed: viewModel.hasFullDiskAccess)
                    }

                    Text(t("settings.fdaDesc"))
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()

                Button(action: {
                    viewModel.openSystemSettingsForFDA()
                }) {
                    Text(t("settings.sysSettings"))
                }
                .buttonStyle(PrimaryActionButtonStyle())
            }

            Divider().background(Theme.hairline)

            // Notification Row
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: "bell.badge")
                    .font(.title3)
                    .foregroundColor(Theme.textSecondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(t("settings.notifications"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.textPrimary)

                        statusBadge(isAllowed: viewModel.notificationPermissionGranted)
                    }

                    Text(t("settings.notificationsDesc"))
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    Button(action: {
                        viewModel.requestNotificationPermission()
                    }) {
                        Text(viewModel.notificationPermissionGranted ? t("settings.sysSettings") : t("settings.reqPerm"))
                    }
                    .buttonStyle(PrimaryActionButtonStyle())

                    Button(action: {
                        viewModel.sendTestNotification()
                    }) {
                        Text(t("settings.testNotifButton"))
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
        }
        .glassCard()
    }

    // MARK: - 2. Auto Optimization Card
    private var autoOptCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            settingsCardHeader(title: t("settings.autoOpt"), icon: "cpu.fill")

            HStack(alignment: .center, spacing: 14) {
                Image(systemName: "memorychip")
                    .font(.title3)
                    .foregroundColor(Theme.textSecondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 3) {
                    Text(t("settings.autoMem"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                    Text(t("settings.autoMemDesc"))
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()

                Toggle("", isOn: $viewModel.autoPurgeMemory)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            if viewModel.autoPurgeMemory {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(t("settings.memThresh"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Theme.textSecondary)
                        Text("\(Int(viewModel.memoryThreshold))%")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Theme.accent)
                    }

                    Slider(value: $viewModel.memoryThreshold, in: 10...40, step: 5)
                        .tint(Theme.accent)
                }
                .padding(.leading, 38)
                .transition(.opacity)
            }

            Divider().background(Theme.hairline)

            HStack(alignment: .center, spacing: 14) {
                Image(systemName: "app.badge")
                    .font(.title3)
                    .foregroundColor(Theme.textSecondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 3) {
                    Text(t("settings.optNotif"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                    Text(t("settings.optNotifDesc"))
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()

                Toggle("", isOn: $viewModel.enableNotifications)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
        }
        .glassCard()
    }

    // MARK: - 3. Scan Paths Card
    private var scanPathsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            settingsCardHeader(title: t("settings.scanSettings"), icon: "folder.badge.gearshape.fill")

            HStack(alignment: .center, spacing: 14) {
                Image(systemName: "folder")
                    .font(.title3)
                    .foregroundColor(Theme.textSecondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 3) {
                    Text(t("settings.defaultPath"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                    Text(t("settings.defaultPathDesc"))
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()
            }

            HStack(spacing: 12) {
                Text(viewModel.defaultScanFolderPath)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.bgCardHover)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusControl)
                            .stroke(Theme.hairline, lineWidth: 1)
                    )
                    .cornerRadius(Theme.radiusControl)

                Button(t("settings.selectPath")) {
                    viewModel.selectDefaultFolder()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .padding(.leading, 38)
        }
        .glassCard()
    }

    // MARK: - 4. Theme Card
    private var themeCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            settingsCardHeader(title: t("settings.themeSettings"), icon: "sun.max.fill")

            HStack(alignment: .center, spacing: 14) {
                Image(systemName: "paintpalette")
                    .font(.title3)
                    .foregroundColor(Theme.textSecondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 3) {
                    Text(t("settings.themeSelect"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                    Text(t("settings.themeDesc"))
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()

                Picker("", selection: $viewModel.appTheme) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 300)
            }
        }
        .glassCard()
    }

    // MARK: - 5. Language Card
    private var languageCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            settingsCardHeader(title: t("settings.langSettings"), icon: "globe")

            HStack(alignment: .center, spacing: 14) {
                Image(systemName: "character.bubble")
                    .font(.title3)
                    .foregroundColor(Theme.textSecondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 3) {
                    Text(t("settings.langSelect"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                    Text(t("settings.languageDescription"))
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()

                Picker("", selection: $viewModel.selectedLanguage) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 220)
            }
        }
        .glassCard()
    }

    // MARK: - 6. About Card
    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            settingsCardHeader(title: t("settings.appStartup"), icon: "info.circle.fill")

            HStack(alignment: .center, spacing: 14) {
                Image(systemName: "bolt.fill")
                    .font(.title3)
                    .foregroundColor(Theme.textSecondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 3) {
                    Text(t("settings.loginStart"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                    Text(t("settings.loginStartDesc"))
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()

                Toggle("", isOn: $viewModel.runAtLogin)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            Divider().background(Theme.hairline)

            HStack(alignment: .center, spacing: 14) {
                Image(systemName: "cube.box")
                    .font(.title3)
                    .foregroundColor(Theme.textSecondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(t("settings.version")): v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.1") • Lab98 Studio Edition")

                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                    Text("\(t("settings.buildDate")): 2026-07-25")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()

                Button(action: {
                    viewModel.checkForUpdates()
                }) {
                    if viewModel.isCheckingUpdate {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.horizontal, 14)
                    } else {
                        Text(t("settings.checkUpdate"))
                    }
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(viewModel.isCheckingUpdate)
            }

            Divider().background(Theme.hairline)

            HStack(alignment: .center, spacing: 14) {
                Image(systemName: "c.circle.fill")
                    .font(.title3)
                    .foregroundColor(Theme.accent)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Copyright © 2026 Lab98 Studio. All rights reserved.")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                    Text("Designed & Engineered for macOS by Vincent Jeon @ Lab98 Studio")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()
            }
        }
        .glassCard()

    }
}
