import SwiftUI

struct DuplicateView: View {
    @StateObject private var viewModel = DuplicateViewModel()
    @State private var showDeleteConfirm = false

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                // 상단 고정 헤더
                PageHeader(
                    title: "중복 파일 정리",
                    subtitle: "디스크 크기 및 바이너리 해시 비교를 기반으로 완벽히 일치하는 복제 파일을 스캔하여 안전하게 정리합니다.",
                    icon: "doc.on.doc.fill"
                )
                .padding(.horizontal, 30)
                .padding(.top, 30)
                .padding(.bottom, 20)
                
                // 검색 조건 카드
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("스캔 대상 폴더")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text(viewModel.targetFolderPath)
                                .font(.system(size: 12, design: .monospaced))
                                .lineLimit(1)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Button("폴더 변경") {
                                viewModel.selectFolder()
                            }
                            .buttonStyle(SecondaryButtonStyle())
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: Theme.radiusChip).fill(.ultraThinMaterial))
                    }

                    Button(action: {
                        viewModel.scanDuplicates()
                    }) {
                        Label("중복 파일 탐색 시작", systemImage: "doc.on.doc.fill")
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(viewModel.isScanning)
                }
                .glassCard()
                .padding(.horizontal, 30)
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
                        
                        Text("중복 파일 정리 준비 완료")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Text("상단의 폴더를 지정하신 후\n'중복 파일 탐색 시작' 버튼을 눌러 스캔을 시작하세요.")
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
                        Text(viewModel.isScanning ? "파일 크기 및 이진 해시 비교 중..." : "감지된 중복 파일 그룹이 없습니다.")
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

                                            Text("개당 크기: \(ByteCountFormatter.string(fromByteCount: group.size, countStyle: .file))")
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
                                                        
                                                        Text("수정일: \(inst.lastModified.formatted(date: .numeric, time: .shortened))")
                                                            .font(.caption2)
                                                            .foregroundColor(.secondary)
                                                    }
                                                    
                                                    Spacer()
                                                    
                                                    if instIndex == 0 {
                                                        Text("원본 보존")
                                                            .font(.system(size: 10, weight: .bold))
                                                            .foregroundColor(Theme.accentDeep)
                                                            .padding(.horizontal, 6)
                                                            .padding(.vertical, 2)
                                                            .background(Theme.accent.opacity(0.14))
                                                            .cornerRadius(4)
                                                    } else {
                                                        Text("복제본")
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
                            Text("삭제할 복제 파일: \(selectedCount)개 (\(ByteCountFormatter.string(fromByteCount: totalReclaimedSize, countStyle: .file)))")
                                .font(.subheadline)
                                .foregroundColor(Theme.textSecondary)

                            Spacer()

                            Button(action: {
                                showDeleteConfirm = true
                            }) {
                                HStack {
                                    Image(systemName: "trash.fill")
                                    Text("선택한 중복 복사본 휴지통으로 이동")
                                }
                            }
                            .buttonStyle(DangerActionButtonStyle(enabled: selectedCount > 0))
                            .disabled(selectedCount == 0)
                        }
                        .padding(16)
                    }
                    .glassCard(padding: 0, radius: Theme.radiusControl)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 30)
                }
            }
            
            // 로딩 오버레이
            if viewModel.isScanning {
                ProgressOverlay(message: "폴더 내 고속 중복 해시 스캔 중...")
            }
            if viewModel.isDeleting {
                ProgressOverlay(message: "중복 복사본 파일 안전 제거 중...")
            }
        }
        .confirmationDialog(
            "선택한 \(viewModel.groups.flatMap({ $0.instances }).filter({ $0.isSelected }).count)개 중복 복사본을 휴지통으로 이동합니다",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("휴지통으로 이동", role: .destructive) {
                viewModel.deleteSelectedDuplicates()
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("각 그룹당 원본 1개는 보존됩니다. 이동된 파일은 휴지통에서 복구할 수 있습니다.")
        }
        .alert(isPresented: $viewModel.showDeleteSuccess) {
            Alert(
                title: Text("중복 파일 정리 완료"),
                message: Text("총 \(viewModel.deletedCount)개의 중복 복제본 파일 (\(ByteCountFormatter.string(fromByteCount: viewModel.deletedSize, countStyle: .file)))을 휴지통으로 이동했습니다."),
                dismissButton: .default(Text("확인"))
            )
        }
        .onAppear {
            // 자동 스캔 비활성화
        }
    }
}
