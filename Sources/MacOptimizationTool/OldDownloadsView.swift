import SwiftUI
import MacOptimizationCore

struct OldDownloadsView: View {
    @ObservedObject private var viewModel = OldDownloadsViewModel.shared
    @State private var showConfirm = false

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                PageHeader(
                    title: t("old.title"),
                    subtitle: t("old.subtitle"),
                    icon: "archivebox.circle.fill"
                )
                .padding(.horizontal, Theme.pagePadding)
                .padding(.top, Theme.pagePadding)
                .padding(.bottom, 20)

                if !viewModel.hasScanned && !viewModel.isScanning {
                    emptyScanStateView
                } else {
                    scannedContentView
                }
            }

            // 실시간 스캔 프로그레스 카드 오버레이
            if viewModel.isScanning {
                ZStack {
                    Theme.bgCardHover.opacity(0.88)
                        .edgesIgnoringSafeArea(.all)

                    VStack(spacing: 18) {
                        Image(systemName: "archivebox.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(Theme.accent)

                        Text(viewModel.scanStatusText)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Theme.textPrimary)

                        ProgressView(value: viewModel.scanProgress)
                            .progressViewStyle(.linear)
                            .tint(Theme.accent)
                            .frame(width: 320)

                        VStack(spacing: 4) {
                            Text(String(format: t("old.scan.current"), viewModel.currentScanPath))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Theme.textSecondary)

                            Text(String(format: t("old.scan.progress"), viewModel.scannedCount, viewModel.matchedCount))
                                .font(.system(size: 11))
                                .foregroundColor(Theme.textSecondary)
                        }

                        Button(action: {
                            viewModel.cancelScan()
                        }) {
                            Text(t("common.cancelScan"))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Theme.textSecondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(Theme.bgCardHover)
                                .cornerRadius(Theme.radiusControl)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(28)
                    .glassCard(padding: 28, radius: Theme.radiusCard)
                }
            }


            if viewModel.isCleaning {
                ProgressOverlay(message: t("old.cleaning"))
            }
        }
        .confirmationDialog(
            t("old.confirm.title"),
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {
            Button(String(format: t("common.moveToTrashWithSize"), ByteCountFormatter.string(fromByteCount: viewModel.selectedSize, countStyle: .file)), role: .destructive) {
                viewModel.deleteSelectedItems()
            }
            Button(t("common.cancel"), role: .cancel) {}
        } message: {
            Text(String(format: t("old.confirm.message"), viewModel.selectedCount))
        }
        .alert(isPresented: $viewModel.showCleanSuccess) {
            Alert(
                title: Text(t("common.cleanupDone")),
                message: Text(String(format: t("old.done.message"), ByteCountFormatter.string(fromByteCount: viewModel.cleanedSize, countStyle: .file))),
                dismissButton: .default(Text(t("common.ok")))
            )
        }
    }

    private var emptyScanStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "archivebox.circle.fill")
                .font(.system(size: 70))
                .foregroundStyle(Theme.accentGradient)
                .padding(.bottom, 10)
                .shadow(color: Theme.accent.opacity(0.25), radius: 12)

            Text(t("old.empty.title"))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(Theme.textPrimary)

            Text(t("old.empty.subtitle"))
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .frame(maxWidth: 480)
                .padding(.horizontal, 20)

            HStack(spacing: 12) {
                Picker(t("old.picker.age"), selection: $viewModel.selectedAgeThreshold) {
                    ForEach(AgeThreshold.allCases) { threshold in
                        Text(threshold.displayName).tag(threshold)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 280)

                Button(action: {
                    viewModel.scanOldDownloads()
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text(t("old.startScan"))
                    }
                }
                .buttonStyle(PrimaryActionButtonStyle())
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var scannedContentView: some View {
        VStack(spacing: 16) {
            // 상단 대시바
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(format: t("old.selectedCount"), viewModel.selectedCount))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    Text(String(format: t("old.reclaimable"), ByteCountFormatter.string(fromByteCount: viewModel.selectedSize, countStyle: .file)))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.accentGradient)
                }
                Spacer()

                Picker(t("old.picker.criteria"), selection: $viewModel.selectedAgeThreshold) {
                    ForEach(AgeThreshold.allCases) { threshold in
                        Text(threshold.displayName).tag(threshold)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 240)
                // 2-파라미터 onChange 는 macOS 14+. 앱은 13.0 을 지원하므로 버전별로 분기한다.
                .modifier(ValueChangeModifier(value: viewModel.selectedAgeThreshold) {
                    viewModel.scanOldDownloads()
                })


                Button(action: {
                    viewModel.scanOldDownloads()
                }) {
                    Label(t("common.rescan"), systemImage: "arrow.clockwise")
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .glassCard(padding: 20)

            // 파일 목록 리스트
            ScrollView {
                VStack(spacing: 8) {
                    ForEach($viewModel.items) { $item in
                        downloadRow(for: $item)
                    }
                }
                .padding(.vertical, 4)
            }

            // 하단 이동 버튼
            HStack {
                Spacer()
                Button(action: {
                    showConfirm = true
                }) {
                    HStack {
                        Image(systemName: "trash.fill")
                        Text(String(format: t("old.moveSelected"), ByteCountFormatter.string(fromByteCount: viewModel.selectedSize, countStyle: .file)))
                    }
                }
                .buttonStyle(DangerActionButtonStyle(enabled: viewModel.selectedCount > 0))
                .disabled(viewModel.selectedCount == 0)
            }
        }
        .padding(.horizontal, Theme.pagePadding)
        .padding(.bottom, Theme.pagePadding)
    }

    private func downloadRow(for item: Binding<OldDownloadItem>) -> some View {
        HStack(spacing: 12) {
            Toggle(isOn: item.isSelected) {
                HStack(spacing: 10) {
                    Image(systemName: item.wrappedValue.category.iconName)
                        .foregroundColor(Theme.accent)
                        .font(.title3)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.wrappedValue.name)
                            .fontWeight(.bold)
                            .foregroundColor(Theme.textPrimary)
                            .lineLimit(1)
                        Text(String(format: t("old.itemDetail"), item.wrappedValue.daysOld, item.wrappedValue.path))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Theme.textSecondary)
                            .lineLimit(1)
                    }
                }
            }
            .toggleStyle(CheckboxToggleStyle())

            Spacer()

            Text(item.wrappedValue.readableSize)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(Theme.textPrimary)
        }
        .padding(12)
        .glassCard(padding: 0, radius: Theme.radiusControl)
    }
}

/// `onChange(of:initial:_:)` 는 macOS 14 이상 API 다.
/// 앱의 최소 지원 버전(13.0)에서도 동작하도록 버전별 오버로드를 감싼다.
private struct ValueChangeModifier<Value: Equatable>: ViewModifier {
    let value: Value
    let action: () -> Void

    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            content.onChange(of: value) { _, _ in action() }
        } else {
            content.onChange(of: value) { _ in action() }
        }
    }
}
