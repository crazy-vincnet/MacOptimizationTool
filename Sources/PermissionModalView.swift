import SwiftUI

struct PermissionModalView: View {
    @ObservedObject var permissionManager = PermissionManager.shared

    var body: some View {
        ZStack {
            PermissionVisualEffectView()
                .ignoresSafeArea()

            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                headerView
                
                VStack(spacing: 16) {
                    fdaCardView
                    notificationCardView
                }
            }
            .padding(32)
            .frame(width: 540)
            .glassCard(padding: 0, radius: 24, highlighted: true)
            .shadow(color: Color.black.opacity(0.5), radius: 30, x: 0, y: 15)
        }
    }

    private var headerView: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Theme.accent, Theme.accentDeep], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 64, height: 64)
                    .shadow(color: Theme.accent.opacity(0.4), radius: 12, x: 0, y: 6)

                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)
            }

            Text("시스템 접근 권한 승인 안내")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(Theme.textPrimary)

            Text("MacOptimizationTool을 사용하기 위해 필요한 시스템 권한을 확인해 주세요.")
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
        }
    }

    private var fdaCardView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("전체 디스크 접근 권한 (Full Disk Access)", systemImage: "externaldrive.fill.badge.checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.textPrimary)

                Spacer()

                Text("필수 권한")
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.red.opacity(0.2))
                    .foregroundColor(.red)
                    .cornerRadius(6)
            }

            Text("시스템 전체 정크 파일, 중복 파일, 방치된 다운로드 및 브라우저 데이터를 정밀 탐색하기 위해 전체 디스크 접근 권한이 반드시 필요합니다.")
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
                .lineSpacing(3)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Button(action: {
                        permissionManager.openSystemFDASettings()
                    }) {
                        HStack {
                            Image(systemName: "gearshape.fill")
                            Text("1. macOS 시스템 설정 열기")
                        }
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Theme.accent)
                        .foregroundColor(.white)
                        .cornerRadius(Theme.radiusControl)
                    }
                    .buttonStyle(.plain)

                    Text("➔ 'MacOptimizationTool' 스위치를 [켜기]로 변경")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                }

                Button(action: {
                    permissionManager.checkPermissions()
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise.circle.fill")
                        Text(permissionManager.isChecking ? "권한 확인 중..." : "2. 권한 승인 완료 및 시작하기")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Theme.accent)
                    .foregroundColor(.white)
                    .cornerRadius(Theme.radiusControl)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.06))
        .cornerRadius(Theme.radiusCard)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusCard)
                .stroke(Theme.accent.opacity(0.4), lineWidth: 1.5)
        )
    }

    private var notificationCardView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("실시간 시스템 알림 서비스", systemImage: "bell.badge.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.textPrimary)

                Spacer()

                Text("선택 권한")
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(6)
            }

            Text("메모리 최적화 완료 안내 및 시스템 자원 폭주 실시간 배너 알림을 수신합니다.")
                .font(.system(size: 11))
                .foregroundColor(Theme.textSecondary)

            HStack {
                if permissionManager.notificationStatus == .authorized {
                    Label("알림 권한 승인됨", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.accent)

                } else {
                    Button(action: {
                        permissionManager.requestNotificationPermission()
                    }) {
                        HStack {
                            Image(systemName: "bell.fill")
                            Text("알림 서비스 허용하기")
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Theme.bgCardHover)
                        .foregroundColor(Theme.textPrimary)
                        .cornerRadius(Theme.radiusControl)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .cornerRadius(Theme.radiusCard)
    }
}

struct PermissionVisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .hudWindow
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
