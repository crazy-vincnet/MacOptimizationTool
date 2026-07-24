import SwiftUI

struct WinCompatView: View {
    @StateObject private var viewModel = DiskCleanViewModel()
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                // 상단 고정 헤더
                PageHeader(
                    title: t("wincompat.title"),
                    subtitle: t("wincompat.subtitle"),
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
                                Text(t("wincompat.why_title"))
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                            }

                            Text(t("wincompat.explain_issue"))
                                .font(.subheadline)
                                .foregroundColor(Theme.textSecondary)
                                .lineSpacing(4)

                            Text(t("wincompat.explain_tool"))
                                .font(.subheadline)
                                .foregroundColor(Theme.textSecondary)
                                .lineSpacing(4)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard(highlighted: true)

                        // 실행 컨트롤 카드
                        VStack(spacing: 15) {
                            Text(t("wincompat.converter_title"))
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(Theme.textPrimary)
                            Text(t("wincompat.converter_desc"))
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                                .multilineTextAlignment(.center)

                            Button(action: {
                                viewModel.runWindowsFilenameFixer()
                            }) {
                                HStack {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                    Text(t("wincompat.select_button"))
                                }
                            }
                            .buttonStyle(PrimaryActionButtonStyle())
                        }
                        .frame(maxWidth: .infinity)
                        .glassCard(padding: 25)

                        // 이름 변경 히스토리/로그 출력
                        if !viewModel.fixedHistory.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("\(t("wincompat.history_title")) (\(viewModel.fixedCount)\(t("wincompat.count_unit")))")
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
                                        Text("\(t("wincompat.more_items_prefix"))\(viewModel.fixedHistory.count - 30)\(t("wincompat.more_items_suffix"))")
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
                ProgressOverlay(message: t("wincompat.progress_message"), progress: viewModel.fixProgress)
            }
        }
        .alert(isPresented: $viewModel.showFixSuccess) {
            Alert(
                title: Text(t("wincompat.alert_success_title")),
                message: Text("\(t("wincompat.alert_success_prefix"))\(viewModel.fixedCount)\(t("wincompat.alert_success_suffix"))"),
                dismissButton: .default(Text(t("wincompat.confirm")))
            )
        }
    }
}
