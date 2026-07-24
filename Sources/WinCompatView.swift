import SwiftUI

struct WinCompatView: View {
    @StateObject private var viewModel = DiskCleanViewModel()
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                // 상단 고정 헤더
                PageHeader(
                    title: "윈도우 이름 호환성",
                    subtitle: "macOS(NFD) 한글 자모 자음 풀어짐 현상을 Windows 표준(NFC) 형태로 정상 일괄 복구합니다.",
                    icon: "arrow.triangle.2.circlepath"
                )
                .padding(.horizontal, Theme.pagePadding)
                .padding(.top, Theme.pagePadding)
                .padding(.bottom, 20)

                // 본문 영역
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "questionmark.circle.fill")
                                    .foregroundColor(Theme.accent)
                                    .font(.title3)
                                Text("왜 Windows에서 한글 파일명이 깨지나요?")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                            }

                            Text("macOS와 Windows는 서로 한글 유니코드를 결합하는 방식(NFD vs NFC)이 다릅니다. macOS에서 생성한 파일/폴더를 외장 드라이브나 메신저로 Windows에 보낼 경우 자모가 풀어져 보이는 현상(예: '한글' -> 'ㅎㅏㄴㄱㅡㄹ')이 발생합니다.")
                                .font(.subheadline)
                                .foregroundColor(Theme.textSecondary)
                                .lineSpacing(4)

                            Text("본 도구는 선택한 파일 및 폴더 하위의 모든 파일명을 검사하여 자모가 분리된 형태를 Windows 표준 결합 방식으로 안전하게 실시간 일괄 변환(NFC Normalization) 처리합니다.")
                                .font(.subheadline)
                                .foregroundColor(Theme.textSecondary)
                                .lineSpacing(4)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard(highlighted: true)

                        // 실행 컨트롤 카드
                        VStack(spacing: 15) {
                            Text("Windows 호환성 파일/폴더 변환기")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(Theme.textPrimary)
                            Text("검사 및 변환을 실행할 대상 파일 및 폴더를 지정합니다. 폴더의 경우 하위 디렉토리까지 모두 재귀 탐색하여 정밀 처리합니다.")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                                .multilineTextAlignment(.center)

                            Button(action: {
                                viewModel.runWindowsFilenameFixer()
                            }) {
                                HStack {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                    Text("대상 파일/폴더 선택 및 변환 시작")
                                }
                            }
                            .buttonStyle(PrimaryActionButtonStyle())
                        }
                        .frame(maxWidth: .infinity)
                        .glassCard(padding: 25)

                        // 이름 변경 히스토리/로그 출력
                        if !viewModel.fixedHistory.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("최근 이름 변환 기록 (\(viewModel.fixedCount)건)")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)

                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(viewModel.fixedHistory.prefix(30), id: \.self) { log in
                                        Text(log)
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundColor(Theme.textSecondary)
                                            .lineLimit(1)
                                    }
                                    if viewModel.fixedHistory.count > 30 {
                                        Text("...외 \(viewModel.fixedHistory.count - 30)개의 항목이 정상 수정되었습니다.")
                                            .font(.caption)
                                            .foregroundColor(Theme.textSecondary)
                                            .padding(.top, 2)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassCard()
                        }
                    }
                    .padding(.horizontal, Theme.pagePadding)
                    .padding(.bottom, Theme.pagePadding)
                }
            }
            
            // 로딩 오버레이
            if viewModel.isFixingFilenames {
                ProgressOverlay(message: "파일명 NFD 자모 결합 정상화 진행 중...", progress: viewModel.fixProgress)
            }
        }
        .alert(isPresented: $viewModel.showFixSuccess) {
            Alert(
                title: Text("자모 자음 복구 완료"),
                message: Text("총 \(viewModel.fixedCount)개의 파일/폴더 이름을 Windows 표준(NFC) 형태로 정상 변환했습니다."),
                dismissButton: .default(Text("확인"))
            )
        }
    }
}
