import SwiftUI

struct LargeFilesView: View {
    @StateObject private var viewModel = LargeFilesViewModel()
    @State private var showDeleteConfirm = false

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                // 상단 고정 헤더
                PageHeader(
                    title: "대용량 & 오래된 파일",
                    subtitle: "디스크를 낭비하는 대용량 동영상, 빌드 파일 및 수개월 동안 열어보지 않은 오래된 자료를 안전하게 추출합니다.",
                    icon: "externaldrive.badge.timemachine"
                )
                .padding(.horizontal, Theme.pagePadding)
                .padding(.top, Theme.pagePadding)
                .padding(.bottom, 20)
                
                // 검색 조건 카드
                VStack(spacing: 16) {
                    HStack(spacing: 20) {
                        // 스캔 대상 폴더 선택
                        VStack(alignment: .leading, spacing: 5) {
                            Text("스캔 대상 폴더")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Theme.textSecondary)

                            HStack {
                                Text(viewModel.targetFolderPath)
                                    .font(.system(size: 12, design: .monospaced))
                                    .lineLimit(1)
                                    .foregroundColor(Theme.textPrimary)

                                Spacer()

                                Button("폴더 변경") {
                                    viewModel.selectFolder()
                                }
                                .buttonStyle(SecondaryButtonStyle())
                            }
                            .glassCard(padding: 10, radius: Theme.radiusControl)
                        }
                        .frame(maxWidth: .infinity)
                        
                        // 크기 기준 선택
                        VStack(alignment: .leading, spacing: 5) {
                            Text("최소 파일 크기")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Theme.textSecondary)
                            
                            Picker("", selection: $viewModel.sizeThresholdMB) {
                                Text("100 MB").tag(100.0)
                                Text("500 MB").tag(500.0)
                                Text("1 GB").tag(1024.0)
                                Text("5 GB").tag(5120.0)
                            }
                            .pickerStyle(.segmented)
                        }
                        .frame(width: 250)
                        
                        // 기간 기준 선택
                        VStack(alignment: .leading, spacing: 5) {
                            Text("방치 기간")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Theme.textSecondary)
                            
                            Picker("", selection: $viewModel.ageThresholdMonths) {
                                Text("기간 무관").tag(0)
                                Text("3개월 이상").tag(3)
                                Text("6개월 이상").tag(6)
                                Text("1년 이상").tag(12)
                            }
                            .pickerStyle(.segmented)
                        }
                        .frame(width: 250)
                    }
                    
                    Button(action: {
                        viewModel.scanFiles()
                    }) {
                        Label("대용량 파일 검색 시작", systemImage: "magnifyingglass")
                    }
                    .buttonStyle(PrimaryActionButtonStyle(enabled: !viewModel.isScanning))
                    .disabled(viewModel.isScanning)
                }
                .glassCard()
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

                        Text("대용량 & 오래된 파일 탐색 준비 완료")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(Theme.textPrimary)

                        Text("상단의 폴더와 파일 크기, 방치 기간을 지정하신 후\n'대용량 파일 검색 시작' 버튼을 눌러 스캔을 시작하세요.")
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
                        Text(viewModel.isScanning ? "대용량 파일을 분석하고 있습니다..." : "탐색 조건에 맞는 대용량 파일이 없습니다.")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        // 헤더
                        HStack {
                            Text("파일명")
                                .fontWeight(.bold)
                                .frame(width: 220, alignment: .leading)
                            Text("수정일")
                                .fontWeight(.bold)
                                .frame(width: 140, alignment: .leading)
                            Text("경로")
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("크기")
                                .fontWeight(.bold)
                                .frame(width: 100, alignment: .trailing)
                        }
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Theme.accent.opacity(0.06))
                        
                        // 리스트 본문
                        List {
                            ForEach(viewModel.files.indices, id: \.self) { index in
                                let file = viewModel.files[index]
                                HStack {
                                    Button(action: {
                                        viewModel.files[index].isSelected.toggle()
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
                            Text("선택됨: \(selectedCount)개 (\(ByteCountFormatter.string(fromByteCount: selectedSize, countStyle: .file)))")
                                .font(.subheadline)
                                .foregroundColor(Theme.textSecondary)

                            Spacer()

                            Button(action: {
                                showDeleteConfirm = true
                            }) {
                                Label("선택 파일 휴지통으로 이동", systemImage: "trash.fill")
                            }
                            .buttonStyle(DangerActionButtonStyle(enabled: selectedCount > 0))
                            .disabled(selectedCount == 0)
                        }
                        .padding(16)
                        .background(.ultraThinMaterial)
                    }
                    .glassCard(padding: 0, radius: Theme.radiusControl)
                    .padding(.horizontal, Theme.pagePadding)
                    .padding(.bottom, Theme.pagePadding)
                }
            }
            
            // 로딩 오버레이
            if viewModel.isScanning {
                ProgressOverlay(message: "대상 경로에서 대용량 파일 색인 중...")
            }
            if viewModel.isDeleting {
                ProgressOverlay(message: "선택한 대용량 파일 삭제 진행 중...")
            }
        }
        .confirmationDialog(
            "선택한 \(viewModel.files.filter { $0.isSelected }.count)개 파일을 휴지통으로 이동합니다",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("휴지통으로 이동", role: .destructive) {
                viewModel.deleteSelectedFiles()
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("삭제된 파일은 휴지통에서 복구할 수 있습니다.")
        }
        .alert(isPresented: $viewModel.showDeleteSuccess) {
            Alert(
                title: Text("파일 정리 완료"),
                message: Text("총 \(viewModel.deletedCount)개의 파일 (\(ByteCountFormatter.string(fromByteCount: viewModel.deletedSize, countStyle: .file)))을 휴지통으로 이동했습니다."),
                dismissButton: .default(Text("확인"))
            )
        }
        .onAppear {
            // 자동 스캔 비활성화
        }
    }
}
