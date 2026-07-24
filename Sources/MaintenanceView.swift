import SwiftUI

struct MaintenanceView: View {
    @StateObject private var viewModel = MaintenanceViewModel()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 상단 고정 헤더
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("시스템 유지보수")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("Mac 시스템 백그라운드 데이터베이스를 최적화하여 렌더링, 네트워크 및 반응 속도를 개선합니다.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                Button(action: {
                    viewModel.runAllTasks()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                        Text("전체 유지보수 실행")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isAnyTaskRunning)
                .opacity(viewModel.isAnyTaskRunning ? 0.6 : 1.0)
            }
            .padding(.horizontal, 30)
            .padding(.top, 30)
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
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.primary)
                                Text(task.description)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
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
                                        .foregroundColor(.green)
                                        .font(.title3)
                                }
                                
                                Text(task.statusMessage)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(task.isCompleted ? .green : .secondary)
                                
                                Button(action: {
                                    viewModel.runTask(id: task.id)
                                }) {
                                    Text("실행")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.primary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 6)
                                        .background(Color(NSColor.controlBackgroundColor))
                                        .cornerRadius(6)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                                .disabled(viewModel.isAnyTaskRunning)
                                .opacity(viewModel.isAnyTaskRunning ? 0.5 : 1.0)
                            }
                        }
                        .padding(18)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color(NSColor.controlBackgroundColor).opacity(0.3)))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.gray.opacity(0.08), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 30)
            }
        }
    }
}
