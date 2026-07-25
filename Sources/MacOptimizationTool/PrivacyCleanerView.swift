import SwiftUI
import MacOptimizationCore

struct PrivacyCleanerView: View {
    @ObservedObject private var viewModel = PrivacyCleanerViewModel.shared
    @State private var showConfirm = false
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                PageHeader(
                    title: t("priv.title"),
                    subtitle: t("priv.subtitle"),
                    icon: "lock.shield.fill"
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
                        Image(systemName: "lock.shield.fill")
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
                            Text(String(format: t("priv.scan.current"), viewModel.currentScanBrowser))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Theme.textSecondary)

                            Text(String(format: t("priv.scan.progress"), viewModel.scannedItemCount))
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

            
            // 정리 작업 오버레이
            if viewModel.isCleaning {
                ProgressOverlay(message: t("priv.cleaning"))
            }
        }
        .confirmationDialog(
            t("priv.confirm.title"),
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {
            Button(String(format: t("common.moveToTrashWithSize"), ByteCountFormatter.string(fromByteCount: viewModel.totalReclaimableSize, countStyle: .file)), role: .destructive) {
                viewModel.cleanPrivacyData()
            }
            Button(t("common.cancel"), role: .cancel) {}
        } message: {
            Text(t("priv.confirm.message"))
        }
        .alert(isPresented: $viewModel.showCleanSuccess) {
            Alert(
                title: Text(t("priv.done.title")),
                message: Text(String(format: t("priv.done.message"), ByteCountFormatter.string(fromByteCount: viewModel.cleanedSize, countStyle: .file))),
                dismissButton: .default(Text(t("common.ok")))
            )
        }
    }
    
    private var emptyScanStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 70))
                .foregroundStyle(Theme.accentGradient)
                .padding(.bottom, 10)
                .shadow(color: Theme.accent.opacity(0.25), radius: 12)

            Text(t("priv.empty.title"))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(Theme.textPrimary)

            Text(t("priv.empty.subtitle"))
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .frame(maxWidth: 460)
                .padding(.horizontal, 20)

            Button(action: {
                viewModel.scanPrivacyData()
            }) {
                HStack {
                    Image(systemName: "play.fill")
                    Text(t("priv.startScan"))
                }
            }
            .buttonStyle(PrimaryActionButtonStyle())

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var scannedContentView: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 20) {
                // 요약 대시카드
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(t("priv.reclaimable.title"))
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                        Text(ByteCountFormatter.string(fromByteCount: viewModel.totalReclaimableSize, countStyle: .file))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.accentGradient)
                    }
                    Spacer()

                    Button(action: {
                        viewModel.scanPrivacyData()
                    }) {
                        Label(t("common.rescan"), systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                .glassCard(padding: 25)
                
                // 브라우저별 카테고리
                VStack(spacing: 12) {
                    ForEach(viewModel.categories.indices, id: \.self) { catIdx in
                        let cat = viewModel.categories[catIdx]
                        
                        VStack(spacing: 0) {
                            HStack(spacing: 14) {
                                Toggle(isOn: Binding(
                                    get: { viewModel.categories[catIdx].isSelected },
                                    set: { viewModel.categories[catIdx].isSelected = $0 }
                                )) {
                                    EmptyView()
                                }
                                .toggleStyle(CheckboxToggleStyle())
                                
                                Image(systemName: cat.iconName)
                                    .font(.title2)
                                    .foregroundColor(Theme.accent)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cat.browserName)
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(Theme.textPrimary)
                                    Text(cat.description)
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                }
                                
                                Spacer()
                                
                                Text(ByteCountFormatter.string(fromByteCount: cat.totalSize, countStyle: .file))
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(Theme.textSecondary)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            
                            Divider()
                                .padding(.horizontal, 16)
                            
                            // 세부 항목 리스트
                            VStack(spacing: 6) {
                                ForEach(cat.items.indices, id: \.self) { subIdx in
                                    let item = cat.items[subIdx]
                                    HStack {
                                        Toggle(isOn: Binding(
                                            get: { viewModel.categories[catIdx].items[subIdx].isSelected },
                                            set: { viewModel.categories[catIdx].items[subIdx].isSelected = $0 }
                                        )) {
                                            Text(item.name)
                                                .font(.subheadline)
                                                .foregroundColor(Theme.textPrimary)
                                                .lineLimit(1)
                                        }
                                        .toggleStyle(CheckboxToggleStyle())
                                        
                                        Spacer()
                                        
                                        Text(ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file))
                                            .font(.system(size: 11, design: .rounded))
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 24)
                                }
                            }
                            .padding(.vertical, 8)
                            .background(Theme.accent.opacity(0.04))
                        }
                        .glassCard(padding: 0, radius: Theme.radiusControl)
                    }
                }
                
                Spacer().frame(height: 10)
                
                // 실행 버튼
                Button(action: {
                    showConfirm = true
                }) {
                    HStack(spacing: 8) {
                        Spacer()
                        Image(systemName: "sparkles")
                        Text(String(format: t("priv.cleanSelected"), ByteCountFormatter.string(fromByteCount: viewModel.totalReclaimableSize, countStyle: .file)))
                        Spacer()
                    }
                }
                .buttonStyle(PrimaryActionButtonStyle(enabled: viewModel.totalReclaimableSize > 0))
                .disabled(viewModel.totalReclaimableSize == 0)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 30)
        }
    }
}
