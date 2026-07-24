import SwiftUI

struct DiskCleanerView: View {
    @StateObject private var viewModel = DiskCleanViewModel()
    @State private var showCleanConfirm = false

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                // 상단 고정 헤더
                PageHeader(
                    title: t("disk.pageTitle"),
                    subtitle: t("disk.pageSubtitle"),
                    icon: "opticaldisc.fill"
                )
                .padding(.horizontal, Theme.pagePadding)
                .padding(.top, Theme.pagePadding)
                .padding(.bottom, 20)
                
                // 디스크 최적화 본문
                if !viewModel.hasScanned && !viewModel.isScanning {
                    VStack(spacing: 20) {
                        Spacer()
                        Image(systemName: "opticaldisc.fill")
                            .font(.system(size: 70))
                            .foregroundStyle(Theme.accentGradient)
                            .padding(.bottom, 10)
                            .shadow(color: Theme.accent.opacity(0.25), radius: 12)

                        Text(t("disk.emptyTitle"))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.textPrimary)

                        Text(t("disk.emptyDesc"))
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .frame(maxWidth: 450)
                            .padding(.horizontal, 20)

                        Button(action: {
                            viewModel.scanJunk()
                        }) {
                            HStack {
                                Image(systemName: "play.fill")
                                Text(t("common.scanStart"))
                            }
                        }
                        .buttonStyle(PrimaryActionButtonStyle())

                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 20) {
                            // 총 용량 대시카드
                            HStack {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(t("disk.reclaimableSpace"))
                                        .font(.subheadline)
                                        .foregroundColor(Theme.textSecondary)
                                    Text(ByteCountFormatter.string(fromByteCount: viewModel.categories.reduce(0) { $0 + ($1.isSelected ? $1.size : 0) }, countStyle: .file))
                                        .font(.system(size: 36, weight: .bold, design: .rounded))
                                        .foregroundStyle(Theme.accentGradient)
                                }
                                Spacer()

                                Button(action: {
                                    viewModel.scanJunk()
                                }) {
                                    Label(t("common.scanRestart"), systemImage: "arrow.clockwise")
                                }
                                .buttonStyle(SecondaryButtonStyle())
                            }
                            .glassCard(padding: 25)
                            
                            // 카테고리별 목록
                            VStack(spacing: 12) {
                                ForEach(viewModel.categories.indices, id: \.self) { index in
                                    let cat = viewModel.categories[index]
                                    
                                    VStack(spacing: 0) {
                                        // 카테고리 메인 헤더 행
                                        HStack(spacing: 15) {
                                            Button(action: {
                                                viewModel.toggleCategorySelection(at: index)
                                            }) {
                                                Image(systemName: cat.isSelected ? "checkmark.square.fill" : "square")
                                                    .foregroundColor(cat.isSelected ? Theme.accent : Theme.textSecondary)
                                                    .font(.title3)
                                            }
                                            .buttonStyle(.plain)
                                            
                                            Button(action: {
                                                withAnimation(.spring()) {
                                                    viewModel.categories[index].isExpanded.toggle()
                                                }
                                            }) {
                                                HStack {
                                                    VStack(alignment: .leading, spacing: 4) {
                                                        Text(cat.name)
                                                            .fontWeight(.bold)
                                                            .foregroundColor(Theme.textPrimary)
                                                        Text(cat.description)
                                                            .font(.caption)
                                                            .foregroundColor(Theme.textSecondary)
                                                    }
                                                    Spacer()

                                                    Text(ByteCountFormatter.string(fromByteCount: cat.size, countStyle: .file))
                                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                                        .foregroundColor(Theme.textSecondary)
                                                        .padding(.trailing, 8)

                                                    Image(systemName: cat.isExpanded ? "chevron.down" : "chevron.right")
                                                        .foregroundColor(Theme.textSecondary)
                                                        .font(.system(size: 11, weight: .bold))
                                                }
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 16)
                                        
                                        // 펼쳐진 상태의 상세 파일/폴더 리스트
                                        if cat.isExpanded {
                                            Divider()
                                                .padding(.horizontal, 16)
                                            
                                            if !cat.subItems.isEmpty {
                                                VStack(spacing: 6) {
                                                    ForEach(cat.subItems.indices, id: \.self) { subIndex in
                                                        let item = cat.subItems[subIndex]
                                                        HStack {
                                                            Button(action: {
                                                                viewModel.toggleSubItemSelection(categoryIndex: index, subItemIndex: subIndex)
                                                            }) {
                                                                Image(systemName: item.isSelected ? "checkmark.square.fill" : "square")
                                                                    .foregroundColor(item.isSelected ? Theme.accent : Theme.textSecondary)
                                                            }
                                                            .buttonStyle(.plain)

                                                            Text(item.name)
                                                                .font(.subheadline)
                                                                .foregroundColor(Theme.textPrimary)
                                                                .lineLimit(1)
                                                                .help(item.id)

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
                                            } else {
                                                Text(t("disk.subItemsEmpty"))
                                                    .font(.caption)
                                                    .foregroundColor(Theme.textSecondary)
                                                    .padding(.vertical, 8)
                                                    .padding(.horizontal, 24)
                                            }
                                        }
                                    }
                                    .glassCard(padding: 0, radius: Theme.radiusControl)
                                }
                            }
                            
                            Spacer().frame(height: 10)
                            
                            // 하단 정리 실행 버튼
                            Button(action: {
                                showCleanConfirm = true
                            }) {
                                HStack(spacing: 8) {
                                    Spacer()
                                    Image(systemName: "sparkles")
                                    Text("\(t("disk.cleanExecute")) (\(t("disk.reclaimableLabel")): \(ByteCountFormatter.string(fromByteCount: viewModel.totalJunkSize, countStyle: .file)))")
                                    Spacer()
                                }
                            }
                            .buttonStyle(PrimaryActionButtonStyle(enabled: viewModel.totalJunkSize > 0))
                            .disabled(viewModel.totalJunkSize == 0)
                        }
                        .padding(.horizontal, 30)
                        .padding(.bottom, 30)
                    }
                }
            }
            
            // 로딩 오버레이
            if viewModel.isScanning {
                ProgressOverlay(message: t("disk.progressScanning"))
            }

            if viewModel.isCleaning {
                ProgressOverlay(message: t("disk.progressCleaning"))
            }
        }
        .confirmationDialog(
            t("disk.confirmTitle"),
            isPresented: $showCleanConfirm,
            titleVisibility: .visible
        ) {
            Button("\(t("disk.moveToTrash")) (\(ByteCountFormatter.string(fromByteCount: viewModel.totalJunkSize, countStyle: .file)))", role: .destructive) {
                viewModel.cleanJunk()
            }
            Button(t("disk.cancel"), role: .cancel) {}
        } message: {
            Text(t("disk.confirmMessage"))
        }
        .alert(isPresented: $viewModel.showCleanSuccess) {
            Alert(
                title: Text(t("disk.successTitle")),
                message: Text("\(t("disk.successMessagePrefix"))\(ByteCountFormatter.string(fromByteCount: viewModel.cleanedSize, countStyle: .file))\(t("disk.successMessageSuffix"))"),
                dismissButton: .default(Text(t("disk.ok")))
            )
        }
        .onAppear {
            // 자동 스캔 비활성화
        }
    }
}

// 공통 오버레이 컴포넌트
struct ProgressOverlay: View {
    let message: String
    var progress: Double? = nil
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.18)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(Theme.accent)

                Text(message)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)

                if let p = progress {
                    VStack(spacing: 4) {
                        ProgressView(value: p)
                            .progressViewStyle(.linear)
                            .tint(Theme.accent)
                            .frame(width: 200)
                        Text("\(Int(p * 100))%")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .glassCard(padding: 28, highlighted: true)
        }
    }
}
