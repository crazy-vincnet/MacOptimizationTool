import SwiftUI
import MacOptimizationCore

struct DiskHealthView: View {
    @ObservedObject private var viewModel = DiskHealthViewModel.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            PageHeader(
                title: t("health.title"),
                subtitle: t("health.subtitle"),
                icon: "waveform.path.ecg"
            )
            .padding(.horizontal, Theme.pagePadding)
            .padding(.top, Theme.pagePadding)
            .padding(.bottom, 20)

            if viewModel.isLoading {
                VStack(spacing: 16) {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(Theme.accent)
                    Text(t("health.scanning"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        // 상단 진단 요약 바
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(String(format: t("health.mountedCount"), viewModel.disks.count))
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(Theme.textPrimary)
                                Text(String(format: t("health.lastRefreshed"), formatDate(viewModel.lastRefreshed)))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(Theme.textSecondary)
                            }
                            Spacer()

                            Button(action: {
                                viewModel.fetchDiskHealth()
                            }) {
                                Label(t("health.refreshNow"), systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(SecondaryButtonStyle())
                        }
                        .glassCard(padding: 20)

                        // 디스크별 헬스 진단 카드 목록
                        ForEach(viewModel.disks) { disk in
                            diskHealthCard(for: disk)
                        }
                    }
                    .padding(.horizontal, Theme.pagePadding)
                    .padding(.bottom, Theme.pagePadding)
                }
            }
        }
        .background(Theme.appBackground)
    }

    private func diskHealthCard(for disk: DiskHealthInfo) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // 메인 헤더
            HStack {
                Image(systemName: disk.isSSD ? "internaldrive.fill" : "externaldrive.fill")
                    .font(.system(size: 28))
                    .foregroundColor(Theme.accent)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(disk.volumeName)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                        Text("(\(disk.fileSystem))")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                    Text(String(format: t("health.mountPath"), disk.mountPath))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()

                // Health Badge
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(Theme.accent)
                    Text(String(format: t("health.rating"), disk.healthRatingPercent))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.accent)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Theme.accentGlow)
                .cornerRadius(Theme.radiusChip)
            }

            Divider()

            // 4개 주요 진단 지표 그리드
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                metricItem(title: t("health.metric.smart"), value: disk.smartStatus, icon: "checkmark.circle.fill", color: .green)
                metricItem(title: t("health.metric.temperature"), value: String(format: t("health.metric.temperatureValue"), disk.temperatureCelsius), icon: "thermometer.medium", color: .orange)
                metricItem(title: t("health.metric.freeSpace"), value: ByteCountFormatter.string(fromByteCount: disk.freeBytes, countStyle: .file), icon: "internaldrive", color: Theme.accent)
                metricItem(title: t("health.metric.totalSpace"), value: ByteCountFormatter.string(fromByteCount: disk.totalBytes, countStyle: .file), icon: "square.stack.fill", color: Theme.textSecondary)
            }

            // 용량 점유 프로그레스 바
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(t("health.usageRatio"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    Text("\(String(format: "%.1f", disk.usagePercent))%")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(disk.usagePercent > 90 ? Theme.danger : Theme.accent)
                }

                ProgressView(value: disk.usagePercent / 100.0)
                    .progressViewStyle(.linear)
                    .tint(disk.usagePercent > 90 ? Theme.danger : Theme.accent)
            }
        }
        .glassCard(padding: 20, radius: Theme.radiusCard)
    }

    private func metricItem(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
            }
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
        }
        .padding(10)
        .background(Theme.bgCardHover)
        .cornerRadius(Theme.radiusControl)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}
