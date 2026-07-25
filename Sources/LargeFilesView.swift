import SwiftUI

struct LargeFilesView: View {
    @ObservedObject private var viewModel = LargeFilesViewModel.shared
    @State private var showDeleteConfirm = false

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                // 상단 고정 헤더
                PageHeader(
                    title: t("large.title"),
                    subtitle: t("large.subtitle"),
                    icon: "externaldrive.badge.timemachine"
                )
                .padding(.horizontal, Theme.pagePadding)
                .padding(.top, Theme.pagePadding)
                .padding(.bottom, 20)
                
                // 검색 조건 카드 (Supabase Studio Clean Layout)
                VStack(spacing: 14) {
                    targetFolderPicker

                    HStack(alignment: .bottom, spacing: 16) {
                        sizePicker
                        agePicker

                        Button(action: {
                            viewModel.scanFiles()
                        }) {
                            Label(t("large.scanButton"), systemImage: "magnifyingglass")
                        }
                        .buttonStyle(PrimaryActionButtonStyle(enabled: !viewModel.isScanning))
                        .disabled(viewModel.isScanning)
                    }
                }
                .glassCard(padding: 14, radius: Theme.radiusControl)
                .padding(.horizontal, Theme.pagePadding)
                .padding(.bottom, 20)

                
                // 파일 리스트 테이블 영역 또는 스캔 준비 화면
                if !viewModel.hasScanned && !viewModel.isScanning {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "folder.badge.gearshape")
                            .font(.system(size: 55))
                            .foregroundStyle(Theme.accentGradient)
                            .padding(.bottom, 5)
                            .shadow(color: Theme.accent.opacity(0.2), radius: 8)

                        Text(t("large.readyTitle"))
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(Theme.textPrimary)

                        Text(t("large.readyDesc"))
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .frame(maxWidth: 450)
                            .padding(.horizontal, 20)
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.files.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundColor(Theme.textSecondary.opacity(0.6))
                        Text(viewModel.isScanning ? t("large.analyzing") : t("large.noResults"))
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        // 클릭 가능한 정렬 테이블 헤더 셀
                        HStack {
                            Text("")
                                .frame(width: 24)

                            Button(action: { viewModel.toggleSort(column: .name) }) {
                                HStack(spacing: 4) {
                                    Text(t("large.colName") + (viewModel.currentSortColumn == .name ? viewModel.currentSortDirection.arrow : ""))
                                        .fontWeight(viewModel.currentSortColumn == .name ? .bold : .semibold)
                                        .foregroundColor(viewModel.currentSortColumn == .name ? Theme.accent : Theme.textSecondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .frame(width: 200, alignment: .leading)

                            Button(action: { viewModel.toggleSort(column: .modifiedDate) }) {
                                HStack(spacing: 4) {
                                    Text(t("large.colModified") + (viewModel.currentSortColumn == .modifiedDate ? viewModel.currentSortDirection.arrow : ""))
                                        .fontWeight(viewModel.currentSortColumn == .modifiedDate ? .bold : .semibold)
                                        .foregroundColor(viewModel.currentSortColumn == .modifiedDate ? Theme.accent : Theme.textSecondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .frame(width: 140, alignment: .leading)

                            Button(action: { viewModel.toggleSort(column: .path) }) {
                                HStack(spacing: 4) {
                                    Text(t("large.colPath") + (viewModel.currentSortColumn == .path ? viewModel.currentSortDirection.arrow : ""))
                                        .fontWeight(viewModel.currentSortColumn == .path ? .bold : .semibold)
                                        .foregroundColor(viewModel.currentSortColumn == .path ? Theme.accent : Theme.textSecondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Button(action: { viewModel.toggleSort(column: .size) }) {
                                HStack(spacing: 4) {
                                    Spacer()
                                    Text(t("large.colSize") + (viewModel.currentSortColumn == .size ? viewModel.currentSortDirection.arrow : ""))
                                        .fontWeight(viewModel.currentSortColumn == .size ? .bold : .semibold)
                                        .foregroundColor(viewModel.currentSortColumn == .size ? Theme.accent : Theme.textSecondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .frame(width: 100, alignment: .trailing)
                        }
                        .font(.system(size: 12))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Theme.accent.opacity(0.08))
                        .cornerRadius(Theme.radiusChip)
                        
                        // 리스트 본문 (정렬된 결과)
                        List {
                            ForEach(viewModel.sortedFiles) { file in
                                HStack {
                                    Button(action: {
                                        if let idx = viewModel.files.firstIndex(where: { $0.id == file.id }) {
                                            viewModel.files[idx].isSelected.toggle()
                                        }
                                    }) {
                                        Image(systemName: file.isSelected ? "checkmark.square.fill" : "square")
                                            .foregroundColor(file.isSelected ? Theme.accent : Theme.textSecondary)
                                    }
                                    .buttonStyle(.plain)
                                    .frame(width: 24)
                                    
                                    Text(file.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .frame(width: 200, alignment: .leading)
                                        .lineLimit(1)
                                        .help(file.name)
                                    
                                    Text(file.lastModified.formatted(date: .numeric, time: .omitted))
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                        .frame(width: 140, alignment: .leading)

                                    Text(file.url.path)
                                        .font(.caption2)
                                        .foregroundColor(Theme.textSecondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .help(file.url.path)
                                    
                                    Text(ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file))
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        .foregroundColor(Theme.textPrimary)
                                        .frame(width: 100, alignment: .trailing)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .listStyle(.plain)

                        
                        // 삭제 실행 하단 바
                        let selectedCount = viewModel.files.filter { $0.isSelected }.count
                        let selectedSize = viewModel.files.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
                        
                        HStack {
                            Text("\(t("large.selectedPrefix"))\(selectedCount)\(t("large.selectedUnit")) (\(ByteCountFormatter.string(fromByteCount: selectedSize, countStyle: .file)))")
                                .font(.subheadline)
                                .foregroundColor(Theme.textSecondary)

                            Spacer()

                            Button(action: {
                                showDeleteConfirm = true
                            }) {
                                Label(t("large.moveToTrashButton"), systemImage: "trash.fill")
                            }
                            .buttonStyle(DangerActionButtonStyle(enabled: selectedCount > 0))
                            .disabled(selectedCount == 0)
                        }
                        .padding(16)
                        .background(Theme.bgCardHover)
                    }
                    .glassCard(padding: 0, radius: Theme.radiusControl)
                    .padding(.horizontal, Theme.pagePadding)
                    .padding(.bottom, Theme.pagePadding)
                }
            }
            
            // 실시간 대용량 스캔 프로그레스 오버레이
            if viewModel.isScanning {
                ZStack {
                    Theme.bgCardHover.opacity(0.88)
                        .edgesIgnoringSafeArea(.all)

                    VStack(spacing: 18) {
                        Image(systemName: "doc.text.magnifyingglass")
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

                            Text("탐색 진행: \(viewModel.scannedCount)개 파일 스캔 완료 (\(viewModel.matchedCount)개 조건 부합)")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.textSecondary)
                        }

                        Button(action: {
                            viewModel.cancelScan()
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
                ProgressOverlay(message: t("large.deletingOverlay"))
            }
        }
        .confirmationDialog(
            "\(t("large.confirmMovePrefix"))\(viewModel.files.filter { $0.isSelected }.count)\(t("large.confirmMoveSuffix"))",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(t("large.moveToTrash"), role: .destructive) {
                viewModel.deleteSelectedFiles()
            }
            Button(t("large.cancel"), role: .cancel) {}
        } message: {
            Text(t("large.confirmMessage"))
        }
        .alert(isPresented: $viewModel.showDeleteSuccess) {
            Alert(
                title: Text(t("large.successTitle")),
                message: Text("\(t("large.successMsgPrefix"))\(viewModel.deletedCount)\(t("large.successMsgMid"))(\(ByteCountFormatter.string(fromByteCount: viewModel.deletedSize, countStyle: .file)))\(t("large.successMsgSuffix"))"),
                dismissButton: .default(Text(t("large.ok")))
            )
        }
        .onAppear {
            // 자동 스캔 비활성화
        }
    }

    @ViewBuilder private var targetFolderPicker: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(t("large.targetFolder"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
            HStack {
                Text(viewModel.targetFolderPath)
                    .font(.system(size: 12, design: .monospaced))
                    .lineLimit(1)
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Button(t("large.changeFolder")) {
                    viewModel.selectFolder()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: Theme.radiusChip).fill(Theme.bgCardHover))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusChip).stroke(Theme.hairline, lineWidth: 1))
        }
    }


    @ViewBuilder private var sizePicker: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(t("large.minSize"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
            Picker("", selection: $viewModel.sizeThresholdMB) {
                Text("100 MB").tag(100.0)
                Text("500 MB").tag(500.0)
                Text("1 GB").tag(1024.0)
                Text("5 GB").tag(5120.0)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder private var agePicker: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(t("large.ageFilter"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
            Picker("", selection: $viewModel.ageThresholdMonths) {
                Text(t("large.ageAny")).tag(0)
                Text(t("large.age3Months")).tag(3)
                Text(t("large.age6Months")).tag(6)
                Text(t("large.age1Year")).tag(12)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: .infinity)
        }
    }
}
