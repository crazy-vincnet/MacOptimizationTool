import SwiftUI

struct MaintenanceView: View {
    @StateObject private var viewModel = MaintenanceViewModel()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 상단 고정 헤더
            HStack(alignment: .center, spacing: 16) {
                PageHeader(
                    title: t("maint.header.title"),
                    subtitle: t("maint.header.subtitle"),
                    icon: "wrench.and.screwdriver.fill"
                )

                Button(action: {
                    viewModel.runAllTasks()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                        Text(t("maint.runAll"))
                    }
                }
                .buttonStyle(PrimaryActionButtonStyle(enabled: !viewModel.isAnyTaskRunning))
                .disabled(viewModel.isAnyTaskRunning)
            }
            .padding(.horizontal, Theme.pagePadding)
            .padding(.top, Theme.pagePadding)
            .padding(.bottom, 25)
            
            // 본문 영역
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 16) {
                    ForEach(viewModel.tasks) { task in
                        HStack(spacing: 20) {
                            // 아이콘 영역
                            ZStack {
                                Circle()
                                    .fill(task.color.opacity(0.12))
                                    .frame(width: 48, height: 48)
                                Image(systemName: task.icon)
                                    .foregroundColor(task.color)
                                    .font(.title3)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(task.name)
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                                Text(task.description)
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.textSecondary)
                                    .lineLimit(2)
                            }
                            
                            Spacer()
                            
                            // 작업 상태 표시 및 개별 실행 버튼
                            HStack(spacing: 12) {
                                if task.isRunning {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .frame(width: 20, height: 20)
                                } else if task.isCompleted {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(Theme.accent)
                                        .font(.title3)
                                }

                                Text(task.statusMessage)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(task.isCompleted ? Theme.accent : Theme.textSecondary)

                                Button(action: {
                                    viewModel.runTask(id: task.id)
                                }) {
                                    Text(t("maint.run"))
                                }
                                .buttonStyle(PrimaryActionButtonStyle(enabled: !viewModel.isAnyTaskRunning))
                                .disabled(viewModel.isAnyTaskRunning)
                            }
                        }
                        .glassCard(padding: 18, radius: Theme.radiusCard, highlighted: task.isCompleted)
                    }
                }
                .padding(.horizontal, Theme.pagePadding)
                .padding(.bottom, Theme.pagePadding)
            }
        }
    }
}
