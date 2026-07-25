import Foundation
import AppKit
import UserNotifications
import MacOptimizationCore

struct HighResourceProcess: Identifiable {
    let id = UUID()
    let pid: Int32
    let name: String
    let cpuPercent: Double
    let memoryMB: Double
    let reason: GuardReason
}

enum GuardReason {
    case highCPU
    case highMemory

    var localizedDescription: String {
        switch self {
        case .highCPU: return String(format: t("guard.reason.highCPU"), Int(ProcessGuardManager.cpuThresholdPercent))
        case .highMemory: return String(format: t("guard.reason.highMemory"), ProcessGuardManager.memoryThresholdGB)
        }
    }
}

@MainActor
final class ProcessGuardManager: NSObject, ObservableObject {
    static let shared = ProcessGuardManager()

    /// 경고 임계값. 문구와 판정 로직이 같은 상수를 공유해야 불일치가 생기지 않는다.
    /// 백그라운드 스캔에서도 읽으므로 액터 격리 밖에 둔다.
    nonisolated static let cpuThresholdPercent: Double = 85.0
    nonisolated static let memoryThresholdMB: Double = 2500.0
    nonisolated static var memoryThresholdGB: String { String(format: "%.1f", memoryThresholdMB / 1024.0) }

    @Published var isGuardEnabled: Bool {
        didSet { UserDefaults.standard.set(isGuardEnabled, forKey: Self.enabledDefaultsKey) }
    }

    @Published var alertProcess: HighResourceProcess? = nil
    @Published var showAlertModal: Bool = false

    private static let enabledDefaultsKey = "processGuardEnabled"

    private var monitorTask: Task<Void, Never>?
    private var alertedPIDs: Set<Int32> = []

    private override init() {
        if UserDefaults.standard.object(forKey: Self.enabledDefaultsKey) == nil {
            isGuardEnabled = true
        } else {
            isGuardEnabled = UserDefaults.standard.bool(forKey: Self.enabledDefaultsKey)
        }
        super.init()
    }

    func startGuard() {
        guard monitorTask == nil else { return }
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.inspectProcesses()
                do {
                    try await Task.sleep(nanoseconds: 5_000_000_000)
                } catch {
                    break
                }
            }
        }
    }

    func stopGuard() {
        monitorTask?.cancel()
        monitorTask = nil
    }

    private func inspectProcesses() async {
        guard isGuardEnabled, !showAlertModal else { return }

        let snapshot = await Task.detached(priority: .utility) { () -> HighResourceProcess? in
            let task = Process()
            let pipe = Pipe()
            task.executableURL = URL(fileURLWithPath: "/bin/ps")
            task.arguments = ["-eo", "pid,%cpu,rss,comm"]
            task.standardOutput = pipe

            do {
                try task.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                task.waitUntilExit()

                guard let output = String(data: data, encoding: .utf8) else { return nil }
                let ownPID = ProcessInfo.processInfo.processIdentifier

                for line in output.components(separatedBy: .newlines).dropFirst() {
                    let parts = line.trimmingCharacters(in: .whitespaces)
                        .components(separatedBy: .whitespaces)
                        .filter { !$0.isEmpty }
                    guard parts.count >= 4,
                          let pid = Int32(parts[0]),
                          let cpu = Double(parts[1]),
                          let rss = Double(parts[2]) else { continue }

                    let path = parts[3...].joined(separator: " ")
                    let name = (path as NSString).lastPathComponent

                    // 자기 자신과 시스템 필수 프로세스는 제외
                    if name == "MacOptimizationTool" || name == "WindowServer" || pid == ownPID {
                        continue
                    }

                    let memoryMB = rss / 1024.0

                    if cpu > Self.cpuThresholdPercent {
                        return HighResourceProcess(pid: pid, name: name, cpuPercent: cpu, memoryMB: memoryMB, reason: .highCPU)
                    } else if memoryMB > Self.memoryThresholdMB {
                        return HighResourceProcess(pid: pid, name: name, cpuPercent: cpu, memoryMB: memoryMB, reason: .highMemory)
                    }
                }
                return nil
            } catch {
                return nil
            }
        }.value

        if let snapshot {
            handleHighResourceProcess(snapshot)
        }
    }

    private func handleHighResourceProcess(_ process: HighResourceProcess) {
        guard !alertedPIDs.contains(process.pid) else { return }
        alertedPIDs.insert(process.pid)

        self.alertProcess = process
        self.showAlertModal = true

        let content = UNMutableNotificationContent()
        content.title = String(format: t("guard.notif.title"), process.name)
        content.body = String(format: t("guard.notif.body"),
                              process.reason.localizedDescription,
                              Int(process.cpuPercent),
                              Int(process.memoryMB))
        content.sound = .default

        let request = UNNotificationRequest(identifier: "process_guard_\(process.pid)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    func killAlertProcess() {
        guard let proc = alertProcess else { return }
        kill(proc.pid, SIGKILL)
        self.showAlertModal = false
        self.alertProcess = nil
    }

    /// 사용자가 무시한 경고는 모달만 닫고 해당 PID 는 재알림하지 않는다.
    func dismissAlert() {
        self.showAlertModal = false
        self.alertProcess = nil
    }
}
