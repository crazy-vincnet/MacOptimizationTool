import SwiftUI

struct PrivacyCleanerView: View {
    @ObservedObject private var viewModel = PrivacyCleanerViewModel.shared
    @State private var showConfirm = false
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                PageHeader(
                    title: "브라우저 & 개인정보 정리",
                    subtitle: "Safari, Chrome, Edge, Firefox의 웹 캐시, 쿠키, 저장 데이터를 안전하게 제거합니다.",
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
                            Text("현재 감시 브라우저: \(viewModel.currentScanBrowser)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Theme.textSecondary)

                            Text("개인정보 찌꺼기 탐색: 총 \(viewModel.scannedItemCount)개 데이터 발견 완료")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                    .padding(28)
                    .glassCard(padding: 28, radius: Theme.radiusCard)
                }
            }
            
            // 정리 작업 오버레이
            if viewModel.isCleaning {
                ProgressOverlay(message: "선택한 브라우저 개인정보 데이터를 안전하게 정리 중...")
            }
        }
        .confirmationDialog(
            "브라우저 개인정보 데이터 정리",
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {
            Button("휴지통으로 이동 (\(ByteCountFormatter.string(fromByteCount: viewModel.totalReclaimableSize, countStyle: .file)))", role: .destructive) {
                viewModel.cleanPrivacyData()
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("선택한 웹 캐시 및 쿠키 데이터가 삭제됩니다. 계속하시겠습니까?")
        }
        .alert(isPresented: $viewModel.showCleanSuccess) {
            Alert(
                title: Text("개인정보 정리 완료"),
                message: Text("총 \(ByteCountFormatter.string(fromByteCount: viewModel.cleanedSize, countStyle: .file))의 개인정보 및 웹 캐시가 안전하게 회수되었습니다."),
                dismissButton: .default(Text("확인"))
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

            Text("브라우저 개인정보 데이터 검사")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(Theme.textPrimary)

            Text("웹 브라우징 중 쌓인 웹 캐시, 쿠키, 로컬 스토리지 데이터 및\n다운로드 이력을 정밀 검사하여 용량을 회수하고 개인정보를 보호합니다.")
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
                    Text("개인정보 스캔 시작")
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
                        Text("정리 가능한 개인정보 데이터")
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
                        Label("다시 스캔", systemImage: "arrow.clockwise")
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
                        Text("선택한 개인정보 데이터 정리 (\(ByteCountFormatter.string(fromByteCount: viewModel.totalReclaimableSize, countStyle: .file)))")
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
