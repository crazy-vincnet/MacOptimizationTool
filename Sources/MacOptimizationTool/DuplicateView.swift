import SwiftUI
import MacOptimizationCore

struct DuplicateView: View {
    @ObservedObject private var viewModel = DuplicateViewModel.shared
    @State private var showDeleteConfirm = false


    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                // 상단 고정 헤더
                PageHeader(
                    title: t("dup.title"),
                    subtitle: t("dup.subtitle"),
                    icon: "doc.on.doc.fill"
                )
                .padding(.horizontal, Theme.pagePadding)
                .padding(.top, Theme.pagePadding)
                .padding(.bottom, 20)
                
                // 검색 조건 카드
                HStack(alignment: .bottom, spacing: 20) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(t("dup.target_folder"))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Theme.textSecondary)
                        
                        HStack {
                            Text(viewModel.targetFolderPath)
                                .font(.system(size: 12, design: .monospaced))
                                .lineLimit(1)
                                .foregroundColor(Theme.textPrimary)
                            
                            Spacer()
                            
                            Button(t("dup.change_folder")) {
                                viewModel.selectFolder()
                            }
                            .buttonStyle(SecondaryButtonStyle())
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.radiusChip)
                                .fill(Theme.bgCardHover)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.radiusChip)
                                .stroke(Theme.hairline, lineWidth: 1)
                        )
                    }

                    Button(action: {
                        viewModel.scanDuplicates()
                    }) {
                        Label(t("dup.scan_start"), systemImage: "doc.on.doc.fill")
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(viewModel.isScanning)
                }
                .glassCard(padding: 14, radius: Theme.radiusControl)
                .padding(.horizontal, Theme.pagePadding)
                .padding(.bottom, 12)

                // 스캔 범위·조건 카드. 전체 디스크를 훑지 않게 하는 가장 직접적인 수단이다.
                scanOptionsCard
                    .padding(.horizontal, Theme.pagePadding)
                    .padding(.bottom, 20)

                
                // 중복 그룹 목록 영역 또는 스캔 준비 화면
                if !viewModel.hasScanned && !viewModel.isScanning {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "square.split.2x2")
                            .font(.system(size: 55))
                            .foregroundStyle(Theme.accentGradient)
                            .padding(.bottom, 5)
                            .shadow(color: Theme.accent.opacity(0.2), radius: 8)
                        
                        Text(t("dup.ready_title"))
                            .font(.headline)
                            .fontWeight(.bold)

                        Text(t("dup.ready_desc"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .frame(maxWidth: 450)
                            .padding(.horizontal, 20)
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.groups.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "square.split.2x2")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary.opacity(0.6))
                        Text(viewModel.isScanning ? t("dup.comparing") : t("dup.no_groups"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        // 중복 리스트 스크롤 영역
                        ScrollView(.vertical, showsIndicators: true) {
                            VStack(spacing: 16) {
                                ForEach(viewModel.groups.indices, id: \.self) { groupIndex in
                                    let group = viewModel.groups[groupIndex]
                                    
                                    VStack(alignment: .leading, spacing: 10) {
                                        // 그룹 헤더 정보
                                        HStack {
                                            Image(systemName: "doc.on.doc.fill")
                                                .foregroundColor(Theme.accent)
                                            Text(group.name)
                                                .font(.subheadline)
                                                .fontWeight(.bold)
                                                .lineLimit(1)

                                            Spacer()

                                            Text("\(t("dup.size_each")): \(ByteCountFormatter.string(fromByteCount: group.size, countStyle: .file))")
                                                .font(.caption)
                                                .foregroundColor(Theme.textSecondary)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Theme.accent.opacity(0.10))
                                        .cornerRadius(Theme.radiusChip)
                                        
                                        // 그룹 하위 개별 인스턴스 파일들
                                        VStack(spacing: 8) {
                                            ForEach(group.instances.indices, id: \.self) { instIndex in
                                                let inst = group.instances[instIndex]
                                                HStack {
                                                    Button(action: {
                                                        viewModel.groups[groupIndex].instances[instIndex].isSelected.toggle()
                                                    }) {
                                                        Image(systemName: inst.isSelected ? "checkmark.square.fill" : "square")
                                                            .foregroundColor(inst.isSelected ? Theme.accent : Theme.textSecondary)
                                                    }
                                                    .buttonStyle(.plain)
                                                    
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text(inst.url.path)
                                                            .font(.system(size: 11, design: .monospaced))
                                                            .foregroundColor(.primary)
                                                            .lineLimit(1)
                                                            .help(inst.url.path)
                                                        
                                                        Text("\(t("dup.modified")): \(inst.lastModified.formatted(date: .numeric, time: .shortened))")
                                                            .font(.caption2)
                                                            .foregroundColor(.secondary)
                                                    }
                                                    
                                                    Spacer()
                                                    
                                                    if instIndex == 0 {
                                                        Text(t("dup.original"))
                                                            .font(.system(size: 10, weight: .bold))
                                                            .foregroundColor(Theme.accentDeep)
                                                            .padding(.horizontal, 6)
                                                            .padding(.vertical, 2)
                                                            .background(Theme.accent.opacity(0.14))
                                                            .cornerRadius(4)
                                                    } else {
                                                        Text(t("dup.copy"))
                                                            .font(.system(size: 10))
                                                            .foregroundColor(Theme.warning)
                                                            .padding(.horizontal, 6)
                                                            .padding(.vertical, 2)
                                                            .background(Theme.warning.opacity(0.14))
                                                            .cornerRadius(4)
                                                    }
                                                }
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                            }
                                        }
                                    }
                                    .glassCard(padding: 12, radius: Theme.radiusControl)
                                }
                            }
                            .padding(20)
                        }
                        
                        // 하단 정리 바
                        let selectedCount = viewModel.groups.flatMap({ $0.instances }).filter({ $0.isSelected }).count
                        let totalReclaimedSize = viewModel.groups.reduce(0) { (accum, group) -> Int64 in
                            let selectedInGroup = group.instances.filter({ $0.isSelected }).count
                            return accum + (Int64(selectedInGroup) * group.size)
                        }
                        
                        HStack {
                            Text("\(t("dup.to_delete_prefix"))\(selectedCount)\(t("dup.to_delete_mid"))\(ByteCountFormatter.string(fromByteCount: totalReclaimedSize, countStyle: .file))\(t("dup.to_delete_suffix"))")
                                .font(.subheadline)
                                .foregroundColor(Theme.textSecondary)

                            Spacer()

                            Button(action: {
                                showDeleteConfirm = true
                            }) {
                                HStack {
                                    Image(systemName: "trash.fill")
                                    Text(t("dup.delete_button"))
                                }
                            }
                            .buttonStyle(DangerActionButtonStyle(enabled: selectedCount > 0))
                            .disabled(selectedCount == 0)
                        }
                        .padding(16)
                    }
                    .glassCard(padding: 0, radius: Theme.radiusControl)
                    .padding(.horizontal, Theme.pagePadding)
                    .padding(.bottom, Theme.pagePadding)

                }
            }
            
            // 실시간 스캔 프로그레스 오버레이
            if viewModel.isScanning {
                ZStack {
                    Theme.bgCardHover.opacity(0.88)
                        .edgesIgnoringSafeArea(.all)

                    VStack(spacing: 18) {
                        Image(systemName: "doc.on.doc.fill")
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
                            Text(String(format: t("dup.scan.currentPath"), viewModel.currentScanPath))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Theme.textSecondary)
                                .lineLimit(1)
                                .frame(maxWidth: 380)

                            Text(String(format: t("dup.scan.collected"), viewModel.scannedCount))
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

            if viewModel.isDeleting {
                ProgressOverlay(message: t("dup.deleting_overlay"))
            }
        }
        .confirmationDialog(
            "\(t("dup.confirm_title_prefix"))\(viewModel.groups.flatMap({ $0.instances }).filter({ $0.isSelected }).count)\(t("dup.confirm_title_suffix"))",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(t("dup.move_to_trash"), role: .destructive) {
                viewModel.deleteSelectedDuplicates()
            }
            Button(t("dup.cancel"), role: .cancel) {}
        } message: {
            Text(t("dup.confirm_message"))
        }
        .alert(isPresented: $viewModel.showDeleteSuccess) {
            Alert(
                title: Text(t("dup.success_title")),
                message: Text("\(t("dup.success_msg_prefix"))\(viewModel.deletedCount)\(t("dup.success_msg_mid"))\(ByteCountFormatter.string(fromByteCount: viewModel.deletedSize, countStyle: .file))\(t("dup.success_msg_suffix"))"),
                dismissButton: .default(Text(t("dup.ok")))
            )
        }
        .onAppear {
            // 자동 스캔 비활성화
        }
    }

    // MARK: - 스캔 범위 및 조건

    private var scanOptionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 20) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(t("dup.scope"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)

                    Picker("", selection: Binding(
                        get: { viewModel.scanScope },
                        set: { viewModel.applyScope($0) }
                    )) {
                        Text(t("dup.scope.downloads")).tag(DuplicateScanScope.downloads)
                        Text(t("dup.scope.desktop")).tag(DuplicateScanScope.desktop)
                        Text(t("dup.scope.documents")).tag(DuplicateScanScope.documents)
                        Text(t("dup.scope.home")).tag(DuplicateScanScope.home)
                        Text(t("dup.scope.custom")).tag(DuplicateScanScope.custom)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .disabled(viewModel.isScanning)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(t("dup.minSize"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)

                    Picker("", selection: $viewModel.minimumSize) {
                        ForEach(DuplicateMinimumSize.allCases) { size in
                            Text(size.displayName).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 190)
                    .disabled(viewModel.isScanning)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(t("dup.mode"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)

                    Picker("", selection: $viewModel.scanMode) {
                        Text(t("dup.mode.fast")).tag(DuplicateScanMode.fast)
                        Text(t("dup.mode.thorough")).tag(DuplicateScanMode.thorough)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 190)
                    .disabled(viewModel.isScanning)
                }
            }

            Text(viewModel.scanMode == .fast ? t("dup.mode.fastDesc") : t("dup.mode.thoroughDesc"))
                .font(.system(size: 11))
                .foregroundColor(Theme.textSecondary)

            if viewModel.hasScanned && (viewModel.prunedDirectoryCount > 0 || viewModel.hardLinkSkippedCount > 0) {
                Text(String(format: t("dup.scanSummary"), viewModel.prunedDirectoryCount, viewModel.hardLinkSkippedCount))
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .glassCard(padding: 14, radius: Theme.radiusControl)
    }
}
