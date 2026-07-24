import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @ObservedObject private var langManager = LanguageManager.shared
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                // 상단 고정 헤더
                PageHeader(title: t("settings.title"),
                           subtitle: t("settings.subtitle"),
                           icon: "gearshape.fill")
                    .padding(.horizontal, Theme.pagePadding)
                    .padding(.top, Theme.pagePadding)
                    .padding(.bottom, 20)

                // 설정 내용 스크롤뷰
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 24) {

                        // Section 1: macOS 시스템 권한 설정
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Image(systemName: "lock.shield.fill")
                                    .foregroundColor(Theme.danger)
                                    .font(.title3)
                                Text(t("settings.permissions"))
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)

                                Spacer()

                                Button(action: {
                                    viewModel.checkFullDiskAccess()
                                    viewModel.checkNotificationPermission()
                                }) {
                                    Label(t("settings.refresh"), systemImage: "arrow.clockwise.circle")
                                        .font(.caption)
                                        .foregroundColor(Theme.accent)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.bottom, 5)
                            
                            // 1. 전체 디스크 접근 권한 (Full Disk Access)
                            HStack(alignment: .top, spacing: 15) {
                                Image(systemName: "opticaldisc")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 8) {
                                        Text(t("settings.fda"))
                                            .fontWeight(.semibold)

                                        HStack(spacing: 4) {
                                            Circle()
                                                .fill(viewModel.hasFullDiskAccess ? Theme.accent : Theme.danger)
                                                .frame(width: 8, height: 8)
                                            Text(viewModel.hasFullDiskAccess ? t("common.allowed") : t("common.actionRequired"))
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .foregroundColor(viewModel.hasFullDiskAccess ? Theme.accent : Theme.danger)
                                        }
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(viewModel.hasFullDiskAccess ? Theme.accent.opacity(0.12) : Theme.danger.opacity(0.12))
                                        .cornerRadius(6)
                                    }

                                    Text(t("settings.fdaDesc"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Button(action: {
                                    viewModel.openSystemSettingsForFDA()
                                }) {
                                    Text(t("settings.sysSettings"))
                                }
                                .buttonStyle(PrimaryActionButtonStyle())
                            }
                            
                            Divider()
                            
                            // 2. 알림 권한
                            HStack(alignment: .top, spacing: 15) {
                                Image(systemName: "bell.badge")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 8) {
                                        Text(t("settings.notifications"))
                                            .fontWeight(.semibold)
                                        
                                        HStack(spacing: 4) {
                                            Circle()
                                                .fill(viewModel.notificationPermissionGranted ? Theme.accent : Theme.danger)
                                                .frame(width: 8, height: 8)
                                            Text(viewModel.notificationPermissionGranted ? t("common.allowed") : t("common.actionRequired"))
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .foregroundColor(viewModel.notificationPermissionGranted ? Theme.accent : Theme.danger)
                                        }
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(viewModel.notificationPermissionGranted ? Theme.accent.opacity(0.12) : Theme.danger.opacity(0.12))
                                        .cornerRadius(6)
                                    }

                                    Text(t("settings.notificationsDesc"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                if !viewModel.notificationPermissionGranted {
                                    Button(action: {
                                        viewModel.requestNotificationPermission()
                                    }) {
                                        Text(t("settings.reqPerm"))
                                    }
                                    .buttonStyle(PrimaryActionButtonStyle())
                                }
                            }
                        }
                        .glassCard()

                        // Section 2: 자동 최적화 및 알림
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Image(systemName: "cpu")
                                    .foregroundColor(Theme.accent)
                                    .font(.title3)
                                Text(t("settings.autoOpt"))
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                            }
                            .padding(.bottom, 5)
                            
                            Toggle(isOn: $viewModel.autoPurgeMemory) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(t("settings.autoMem"))
                                        .fontWeight(.semibold)
                                    Text(t("settings.autoMemDesc"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .toggleStyle(.switch)
                            
                            if viewModel.autoPurgeMemory {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(t("settings.memThresh"))
                                            .font(.subheadline)
                                        Text("\(Int(viewModel.memoryThreshold))%")
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundColor(Theme.accent)
                                    }

                                    Slider(value: $viewModel.memoryThreshold, in: 10...40, step: 5)
                                        .tint(Theme.accent)
                                }
                                .padding(.leading, 15)
                                .transition(.opacity)
                            }
                            
                            Divider()
                            
                            Toggle(isOn: $viewModel.enableNotifications) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(t("settings.optNotif"))
                                        .fontWeight(.semibold)
                                    Text(t("settings.optNotifDesc"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .toggleStyle(.switch)
                        }
                        .glassCard()

                        // Section 3: 디스크 스캔 설정
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Image(systemName: "folder.badge.gearshape")
                                    .foregroundColor(Theme.accent)
                                    .font(.title3)
                                Text(t("settings.scanSettings"))
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                            }
                            .padding(.bottom, 5)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text(t("settings.defaultPath"))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text(t("settings.defaultPathDesc"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.bottom, 5)
                                
                                HStack {
                                    Text(viewModel.defaultScanFolderPath)
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(
                                            RoundedRectangle(cornerRadius: Theme.radiusControl, style: .continuous)
                                                .fill(.ultraThinMaterial)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: Theme.radiusControl, style: .continuous)
                                                .stroke(Theme.hairlineSoft, lineWidth: 1)
                                        )

                                    Button(t("settings.selectPath")) {
                                        viewModel.selectDefaultFolder()
                                    }
                                    .buttonStyle(SecondaryButtonStyle())
                                }
                            }
                        }
                        .glassCard()

                        // Section 4: 언어 설정 (Language Settings)
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Image(systemName: "globe")
                                    .foregroundColor(Theme.accent)
                                    .font(.title3)
                                Text(t("settings.langSettings"))
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                            }
                            .padding(.bottom, 5)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text(t("settings.langSelect"))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                Picker("", selection: $viewModel.selectedLanguage) {
                                    ForEach(AppLanguage.allCases) { lang in
                                        Text(lang.displayName).tag(lang)
                                    }
                                }
                                .pickerStyle(.radioGroup)
                                .horizontalRadioGroupLayout()
                            }
                        }
                        .glassCard()

                        // Section 5: 시작 설정 및 버전 정보
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(Theme.accent)
                                    .font(.title3)
                                Text(t("settings.appStartup"))
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                            }
                            .padding(.bottom, 5)
                            
                            Toggle(isOn: $viewModel.runAtLogin) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(t("settings.loginStart"))
                                        .fontWeight(.semibold)
                                    Text(t("settings.loginStartDesc"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .toggleStyle(.switch)
                            
                            Divider()
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(t("settings.version")): v1.0.0")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text("\(t("settings.buildDate")): 2026-07-25")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    viewModel.checkForUpdates()
                                }) {
                                    if viewModel.isCheckingUpdate {
                                        ProgressView()
                                            .controlSize(.small)
                                            .padding(.horizontal, 15)
                                    } else {
                                        Text(t("settings.checkUpdate"))
                                    }
                                }
                                .buttonStyle(PrimaryActionButtonStyle())
                                .disabled(viewModel.isCheckingUpdate)
                            }
                        }
                        .glassCard()
                    }
                    .padding(.horizontal, Theme.pagePadding)
                    .padding(.bottom, Theme.pagePadding)
                }
            }
        }
        .alert(isPresented: $viewModel.showUpdateAlert) {
            Alert(
                title: Text(t("settings.checkUpdate")),
                message: Text(viewModel.updateAlertMessage),
                dismissButton: .default(Text(t("common.ok")))
            )
        }
    }
}
