import SwiftUI

struct DuplicateView: View {
    @StateObject private var viewModel = DuplicateViewModel()
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
                            Text("현재 경로: \(viewModel.currentScanPath)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Theme.textSecondary)
                                .lineLimit(1)
                                .frame(maxWidth: 380)

                            Text("수집 완료: \(viewModel.scannedCount)개 파일 탐색 완료")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.textSecondary)
                        }

                        Button(action: {
                            viewModel.isCancelled = true
                        }) {
                            Text("스캔 취소")
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
}
