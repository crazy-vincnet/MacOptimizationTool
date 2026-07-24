import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @ObservedObject private var langManager = LanguageManager.shared
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                // 상단 고정 헤더
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(t("settings.title"))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text(t("settings.subtitle"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 30)
                .padding(.top, 30)
                .padding(.bottom, 20)
                
                // 설정 내용 스크롤뷰
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 24) {
                        
                        // Section 1: macOS 시스템 권한 설정
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Image(systemName: "lock.shield.fill")
                                    .foregroundColor(.red)
                                    .font(.title3)
                                Text(t("settings.permissions"))
                                    .font(.headline)
                                    .fontWeight(.bold)
                                
                                Spacer()
                                
                                Button(action: {
                                    viewModel.checkFullDiskAccess()
                                    viewModel.checkNotificationPermission()
                                }) {
                                    Label(t("settings.refresh"), systemImage: "arrow.clockwise.circle")
                                        .font(.caption)
                                        .foregroundColor(.green)
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
                                                .fill(viewModel.hasFullDiskAccess ? Color.green : Color.red)
                                                .frame(width: 8, height: 8)
                                            Text(viewModel.hasFullDiskAccess ? (langManager.currentLanguage == .korean ? "허용됨" : "Allowed") : (langManager.currentLanguage == .korean ? "권한 필요" : "Action Required"))
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .foregroundColor(viewModel.hasFullDiskAccess ? .green : .red)
                                        }
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(viewModel.hasFullDiskAccess ? Color.green.opacity(0.12) : Color.red.opacity(0.12))
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
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.green)
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
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
                                                .fill(viewModel.notificationPermissionGranted ? Color.green : Color.red)
                                                .frame(width: 8, height: 8)
                                            Text(viewModel.notificationPermissionGranted ? (langManager.currentLanguage == .korean ? "허용됨" : "Allowed") : (langManager.currentLanguage == .korean ? "권한 필요" : "Action Required"))
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .foregroundColor(viewModel.notificationPermissionGranted ? .green : .red)
                                        }
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(viewModel.notificationPermissionGranted ? Color.green.opacity(0.12) : Color.red.opacity(0.12))
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
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.green)
                                            .cornerRadius(6)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(20)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color(NSColor.controlBackgroundColor).opacity(0.5)))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.1), lineWidth: 1))
                        
                        // Section 2: 자동 최적화 및 알림
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Image(systemName: "cpu")
                                    .foregroundColor(.green)
                                    .font(.title3)
                                Text(t("settings.autoOpt"))
                                    .font(.headline)
                                    .fontWeight(.bold)
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
                                            .foregroundColor(.green)
                                    }
                                    
                                    Slider(value: $viewModel.memoryThreshold, in: 10...40, step: 5)
                                        .tint(.green)
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
                        .padding(20)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color(NSColor.controlBackgroundColor).opacity(0.5)))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.1), lineWidth: 1))
                        
                        // Section 3: 디스크 스캔 설정
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Image(systemName: "folder.badge.gearshape")
                                    .foregroundColor(.purple)
                                    .font(.title3)
                                Text(t("settings.scanSettings"))
                                    .font(.headline)
                                    .fontWeight(.bold)
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
                                        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                                        .cornerRadius(8)
                                    
                                    Button(t("settings.selectPath")) {
                                        viewModel.selectDefaultFolder()
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, 15)
                                    .padding(.vertical, 8)
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                }
                            }
                        }
                        .padding(20)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color(NSColor.controlBackgroundColor).opacity(0.5)))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.1), lineWidth: 1))
                        
                        // Section 4: 언어 설정 (Language Settings)
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Image(systemName: "globe")
                                    .foregroundColor(.teal)
                                    .font(.title3)
                                Text(t("settings.langSettings"))
                                    .font(.headline)
                                    .fontWeight(.bold)
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
                        .padding(20)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color(NSColor.controlBackgroundColor).opacity(0.5)))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.1), lineWidth: 1))
                        
                        // Section 5: 시작 설정 및 버전 정보
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.green)
                                    .font(.title3)
                                Text(t("settings.appStartup"))
                                    .font(.headline)
                                    .fontWeight(.bold)
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
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(Color.green)
                                            .cornerRadius(8)
                                    }
                                }
                                .buttonStyle(.plain)
                                .disabled(viewModel.isCheckingUpdate)
                            }
                        }
                        .padding(20)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color(NSColor.controlBackgroundColor).opacity(0.5)))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.1), lineWidth: 1))
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 30)
                }
            }
        }
        .alert(isPresented: $viewModel.showUpdateAlert) {
            Alert(
                title: Text(t("settings.checkUpdate")),
                message: Text(viewModel.updateAlertMessage),
                dismissButton: .default(Text("확인"))
            )
        }
    }
}
