import SwiftUI
import MacOptimizationCore

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
            .frame(width: 560)
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

            Text(t("perm.title"))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(Theme.textPrimary)

            Text(t("perm.subtitle"))
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
        }
    }

    private var fdaCardView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(t("perm.fda.label"), systemImage: "externaldrive.fill.badge.checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.textPrimary)

                Spacer()

                Text(t("perm.required"))
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.red.opacity(0.2))
                    .foregroundColor(.red)
                    .cornerRadius(6)
            }

            Text(t("perm.fda.description"))
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
                            Text(t("perm.step1"))
                        }
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Theme.accent)
                        .foregroundColor(.white)
                        .cornerRadius(Theme.radiusControl)
                    }
                    .buttonStyle(.plain)

                    Text(t("perm.step2"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                }

                Text(t("perm.hint"))
                    .font(.system(size: 11))
                    .foregroundColor(Theme.accent)
                    .padding(.vertical, 2)

                HStack(spacing: 10) {
                    Button(action: {
                        permissionManager.relaunchApp()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise.circle.fill")
                            Text(t("perm.relaunch"))
                        }
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Theme.bgCardHover)
                        .foregroundColor(Theme.textPrimary)
                        .cornerRadius(Theme.radiusControl)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        permissionManager.bypassPermissionCheck()
                    }) {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                            Text(t("perm.continue"))
                        }
                        .font(.system(size: 12, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(LinearGradient(colors: [Theme.accent, Theme.accentDeep], startPoint: .leading, endPoint: .trailing))
                        .foregroundColor(.white)
                        .cornerRadius(Theme.radiusControl)
                        .shadow(color: Theme.accent.opacity(0.3), radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                }
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
                Label(t("perm.notif.label"), systemImage: "bell.badge.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.textPrimary)

                Spacer()

                Text(t("perm.optional"))
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(6)
            }

            Text(t("perm.notif.description"))
                .font(.system(size: 11))
                .foregroundColor(Theme.textSecondary)

            HStack {
                if permissionManager.notificationStatus == .authorized {
                    Label(t("perm.notif.granted"), systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.accent)
                } else {
                    Button(action: {
                        permissionManager.requestNotificationPermission()
                    }) {
                        HStack {
                            Image(systemName: "bell.fill")
                            Text(t("perm.notif.request"))
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
