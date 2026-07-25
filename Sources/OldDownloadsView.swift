import SwiftUI

struct OldDownloadsView: View {
    @ObservedObject private var viewModel = OldDownloadsViewModel.shared
    @State private var showConfirm = false

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                PageHeader(
                    title: "방치된 다운로드 / 미사용 파일 분류기",
                    subtitle: "다운로드 폴더에 방치된 오래된 설치 파일(.dmg/.pkg) 및 대용량 파일을 자동 분류합니다.",
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
                            Text("현재 스캔: \(viewModel.currentScanPath)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Theme.textSecondary)

                            Text("검사: \(viewModel.scannedCount)개 항목 | 방치 파일 발견: \(viewModel.matchedCount)개")
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


            if viewModel.isCleaning {
                ProgressOverlay(message: "선택한 방치 파일들을 휴지통으로 안전하게 이동 중...")
            }
        }
        .confirmationDialog(
            "방치된 다운로드 파일 휴지통 이동",
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {
            Button("휴지통으로 이동 (\(ByteCountFormatter.string(fromByteCount: viewModel.selectedSize, countStyle: .file)))", role: .destructive) {
                viewModel.deleteSelectedItems()
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("선택한 \(viewModel.selectedCount)개의 오래된 파일이 휴지통으로 이동됩니다.")
        }
        .alert(isPresented: $viewModel.showCleanSuccess) {
            Alert(
                title: Text("정리 완료"),
                message: Text("총 \(ByteCountFormatter.string(fromByteCount: viewModel.cleanedSize, countStyle: .file))의 용량이 회수되었습니다."),
                dismissButton: .default(Text("확인"))
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

            Text("방치된 다운로드 파일 검사")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(Theme.textPrimary)

            Text("Downloads 폴더에 방치된 오래된 압축 파일, 설치 디스크 이미지 및 미디어 파일을\n기간별로 자동 분류하여 낭비되는 용량을 수거합니다.")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .frame(maxWidth: 480)
                .padding(.horizontal, 20)

            HStack(spacing: 12) {
                Picker("방치 기간", selection: $viewModel.selectedAgeThreshold) {
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
                        Text("다운로드 검사 시작")
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
                    Text("선택된 방치 파일: \(viewModel.selectedCount)개")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    Text("정리 가능 용량: \(ByteCountFormatter.string(fromByteCount: viewModel.selectedSize, countStyle: .file))")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.accentGradient)
                }
                Spacer()

                Picker("방치 기준", selection: $viewModel.selectedAgeThreshold) {
                    ForEach(AgeThreshold.allCases) { threshold in
                        Text(threshold.displayName).tag(threshold)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 240)
                .onChange(of: viewModel.selectedAgeThreshold) { _ in
                    viewModel.scanOldDownloads()
                }

                Button(action: {
                    viewModel.scanOldDownloads()
                }) {
                    Label("다시 스캔", systemImage: "arrow.clockwise")
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
                        Text("선택한 방치 파일 휴지통으로 이동 (\(ByteCountFormatter.string(fromByteCount: viewModel.selectedSize, countStyle: .file)))")
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
                        Text("\(item.wrappedValue.daysOld)일 동안 방치됨 • \(item.wrappedValue.path)")
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
