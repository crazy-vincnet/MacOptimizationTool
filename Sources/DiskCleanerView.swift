import SwiftUI

struct DiskCleanerView: View {
    @StateObject private var viewModel = DiskCleanViewModel()
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                // 상단 고정 헤더
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("디스크 정리")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text("사용하지 않는 시스템 캐시, 임시 파일, 로그를 삭제하여 디스크 공간을 확보합니다.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 30)
                .padding(.top, 30)
                .padding(.bottom, 20)
                
                // 디스크 최적화 본문
                if !viewModel.hasScanned && !viewModel.isScanning {
                    VStack(spacing: 20) {
                        Spacer()
                        Image(systemName: "opticaldisc.fill")
                            .font(.system(size: 70))
                            .foregroundColor(.green.opacity(0.8))
                            .padding(.bottom, 10)
                            .shadow(color: .green.opacity(0.2), radius: 10)
                        
                        Text("디스크 스캔 준비 완료")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text("시스템 캐시, 사용자 로그, 임시 보관 파일 및 휴지통을 스캔하여\n불필요하게 낭비되는 공간을 찾아냅니다.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .frame(maxWidth: 450)
                            .padding(.horizontal, 20)
                        
                        Button(action: {
                            viewModel.scanJunk()
                        }) {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("스캔 시작")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 12)
                            .background(Color.green)
                            .cornerRadius(10)
                            .shadow(color: .green.opacity(0.3), radius: 8)
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 20) {
                            // 총 용량 대시카드
                            HStack {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("정리 가능 공간")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text(ByteCountFormatter.string(fromByteCount: viewModel.categories.reduce(0) { $0 + ($1.isSelected ? $1.size : 0) }, countStyle: .file))
                                        .font(.system(size: 36, weight: .bold, design: .rounded))
                                        .foregroundColor(.green)
                                }
                                Spacer()
                                
                                Button(action: {
                                    viewModel.scanJunk()
                                }) {
                                    Label("재스캔", systemImage: "arrow.clockwise")
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 15)
                                        .padding(.vertical, 8)
                                        .background(Color(NSColor.controlBackgroundColor))
                                        .cornerRadius(8)
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(25)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Color(NSColor.controlBackgroundColor).opacity(0.6)))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.1), lineWidth: 1))
                            
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
                                                    .foregroundColor(cat.isSelected ? .green : .secondary)
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
                                                            .foregroundColor(.primary)
                                                        Text(cat.description)
                                                            .font(.caption)
                                                            .foregroundColor(.secondary)
                                                    }
                                                    Spacer()
                                                    
                                                    Text(ByteCountFormatter.string(fromByteCount: cat.size, countStyle: .file))
                                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                                        .foregroundColor(.secondary)
                                                        .padding(.trailing, 8)
                                                    
                                                    Image(systemName: cat.isExpanded ? "chevron.down" : "chevron.right")
                                                        .foregroundColor(.secondary)
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
                                                                    .foregroundColor(item.isSelected ? .green : .secondary)
                                                            }
                                                            .buttonStyle(.plain)
                                                            
                                                            Text(item.name)
                                                                .font(.subheadline)
                                                                .foregroundColor(.primary)
                                                                .lineLimit(1)
                                                                .help(item.id)
                                                            
                                                            Spacer()
                                                            
                                                            Text(ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file))
                                                                .font(.system(size: 11, design: .rounded))
                                                                .foregroundColor(.secondary)
                                                        }
                                                        .padding(.vertical, 4)
                                                        .padding(.horizontal, 24)
                                                    }
                                                }
                                                .padding(.vertical, 8)
                                                .background(Color.gray.opacity(0.03))
                                            } else {
                                                Text("비어 있음")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                    .padding(.vertical, 8)
                                                    .padding(.horizontal, 24)
                                            }
                                        }
                                    }
                                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.controlBackgroundColor).opacity(0.4)))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.08), lineWidth: 1))
                                }
                            }
                            
                            Spacer().frame(height: 10)
                            
                            // 하단 정리 실행 버튼
                            Button(action: {
                                viewModel.cleanJunk()
                            }) {
                                HStack {
                                    Spacer()
                                    Image(systemName: "sparkles")
                                    Text("선택 항목 안전하게 청소 실행 (정리 가능: \(ByteCountFormatter.string(fromByteCount: viewModel.totalJunkSize, countStyle: .file)))")
                                        .fontWeight(.bold)
                                    Spacer()
                                }
                                .foregroundColor(.white)
                                .padding(.vertical, 14)
                                .background(viewModel.totalJunkSize > 0 ? Color.green : Color.gray.opacity(0.3))
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                            .disabled(viewModel.totalJunkSize == 0)
                            .shadow(color: viewModel.totalJunkSize > 0 ? .green.opacity(0.2) : .clear, radius: 8)
                        }
                        .padding(.horizontal, 30)
                        .padding(.bottom, 30)
                    }
                }
            }
            
            // 로딩 오버레이
            if viewModel.isScanning {
                ProgressOverlay(message: "디스크 내 불필요 파일 스캔 중...")
            }
            
            if viewModel.isCleaning {
                ProgressOverlay(message: "불필요 캐시 및 로그 파일 삭제 중...")
            }
        }
        .alert(isPresented: $viewModel.showCleanSuccess) {
            Alert(
                title: Text("디스크 정리 완료"),
                message: Text("성공적으로 \(ByteCountFormatter.string(fromByteCount: viewModel.cleanedSize, countStyle: .file))의 디스크 공간을 확보했습니다!"),
                dismissButton: .default(Text("확인"))
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
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 15) {
                ProgressView()
                    .scaleEffect(1.2)
                
                Text(message)
                    .font(.system(size: 13, weight: .semibold))
                
                if let p = progress {
                    VStack(spacing: 4) {
                        ProgressView(value: p)
                            .progressViewStyle(.linear)
                            .frame(width: 200)
                        Text("\(Int(p * 100))%")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(25)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(NSColor.windowBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.15), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.15), radius: 20)
        }
    }
}
