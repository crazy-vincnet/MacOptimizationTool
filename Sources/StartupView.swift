import SwiftUI

struct StartupView: View {
    @StateObject private var viewModel = StartupViewModel()
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                // 상단 고정 헤더
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("시작 프로그램 관리")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text("Mac 로그인 시 백그라운드에서 백그라운드 데몬 및 서브 프로세스로 실행되는 에이전트 목록을 조율합니다.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    Button(action: {
                        viewModel.scanStartupItems()
                    }) {
                        Label("새로고침", systemImage: "arrow.clockwise")
                            .fontWeight(.medium)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 8)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isScanning)
                }
                .padding(.horizontal, 30)
                .padding(.top, 30)
                .padding(.bottom, 20)
                
                // 안내 배너
                HStack(spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                    Text("불필요한 시작 프로그램을 끄면 Mac의 부팅 속도가 대폭 향상되고, 메모리(RAM) 대기 가용량이 증가합니다. 시스템 파일의 권한 요구사항에 따라 일부 항목 변경 시 OS 권한 알림이 뜰 수 있습니다.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(15)
                .background(Color.blue.opacity(0.08))
                .cornerRadius(10)
                .padding(.horizontal, 30)
                .padding(.bottom, 20)
                
                // 시작 프로그램 테이블 목록
                if viewModel.items.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "cpu.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary.opacity(0.6))
                        Text(viewModel.isScanning ? "백그라운드 에이전트 분석 중..." : "등록된 시작 프로그램 에이전트가 없습니다.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(viewModel.items) { item in
                            HStack(spacing: 16) {
                                // 타입별 아이콘
                                ZStack {
                                    Circle()
                                        .fill(colorForType(item.type).opacity(0.12))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: iconForType(item.type))
                                        .foregroundColor(colorForType(item.type))
                                        .font(.system(size: 14))
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.name)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    Text(item.plistName)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                // 구분 배너
                                Text(item.type)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(colorForType(item.type))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(colorForType(item.type).opacity(0.1))
                                    .cornerRadius(6)
                                
                                if item.isSystemProtected {
                                    Image(systemName: "lock.fill")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 11))
                                        .help("시스템 권한이 필요한 항목으로 비활성화할 수 없습니다.")
                                }
                                
                                // 활성 여부 토글 버튼
                                Toggle("", isOn: Binding(
                                    get: { item.isEnabled },
                                    set: { _ in viewModel.toggleItem(item) }
                                ))
                                .toggleStyle(.switch)
                                .scaleEffect(0.8)
                                .disabled(item.isSystemProtected)
                                .opacity(item.isSystemProtected ? 0.5 : 1.0)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color(NSColor.controlBackgroundColor).opacity(0.2)))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.08), lineWidth: 1))
                        }
                    }
                    .listStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            
            // 로딩 오버레이
            if viewModel.isScanning {
                ProgressOverlay(message: "시스템 내 백그라운드 구동 목록 파싱 중...")
            }
        }
        .alert(isPresented: $viewModel.showSuccessAlert) {
            Alert(
                title: Text("시작 프로그램 변경"),
                message: Text(viewModel.alertMessage),
                dismissButton: .default(Text("확인"))
            )
        }
        .onAppear {
            if !viewModel.hasScanned {
                viewModel.scanStartupItems()
            }
        }
    }
    
    private func iconForType(_ type: String) -> String {
        switch type {
        case "사용자 에이전트": return "person.circle.fill"
        case "시스템 에이전트": return "laptopcomputer"
        default: return "cpu"
        }
    }
    
    private func colorForType(_ type: String) -> Color {
        switch type {
        case "사용자 에이전트": return .blue
        case "시스템 에이전트": return .purple
        default: return .orange
        }
    }
}
