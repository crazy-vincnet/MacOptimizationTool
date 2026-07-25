import Foundation
import AppKit
import UserNotifications

struct HighResourceProcess: Identifiable {
    let id = UUID()
    let pid: Int32
    let name: String
    let cpuPercent: Double
    let memoryMB: Double
    let reason: GuardReason
}

enum GuardReason: String {
    case highCPU = "CPU 과다 점유 (80% 이상)"
    case highMemory = "메모리 과다 점유 (2.5GB 이상)"
}

@MainActor
final class ProcessGuardManager: NSObject, ObservableObject {
    static let shared = ProcessGuardManager()

    @Published var isGuardEnabled: Bool = true
    @Published var alertProcess: HighResourceProcess? = nil
    @Published var showAlertModal: Bool = false

    private var monitorTimer: Timer?
    private var alertedPIDs: Set<Int32> = []

    private override init() {
        super.init()
    }

    func startGuard() {
        guard monitorTimer == nil else { return }
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.inspectProcesses()
            }
        }
    }

    func stopGuard() {
        monitorTimer?.invalidate()
        monitorTimer = nil
    }

    private func inspectProcesses() {
        guard isGuardEnabled else { return }

        Task.detached(priority: .utility) {
            let task = Process()
            let pipe = Pipe()
            task.executableURL = URL(fileURLWithPath: "/bin/ps")
            task.arguments = ["-eo", "pid,%cpu,rss,comm"]
            task.standardOutput = pipe

            do {
                try task.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                task.waitUntilExit()

                guard let output = String(data: data, encoding: .utf8) else { return }
                let lines = output.components(separatedBy: .newlines)

                for line in lines.dropFirst() {
                    let parts = line.trimmingCharacters(in: .whitespaces).components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    guard parts.count >= 4,
                          let pid = Int32(parts[0]),
                          let cpu = Double(parts[1]),
                          let rss = Double(parts[2]) else { continue }

                    let path = parts[3...].joined(separator: " ")
                    let name = (path as NSString).lastPathComponent

                    // Ignore system apps / MacCleanOptimizer itself
                    if name == "MacCleanOptimizer" || name == "WindowServer" || pid == ProcessInfo.processInfo.processIdentifier {
                        continue
                    }

                    let memoryMB = rss / 1024.0

                    // Threshold Check: CPU > 85% or RAM > 2500MB
                    if cpu > 85.0 {
                        await self.handleHighResourceProcess(pid: pid, name: name, cpu: cpu, mem: memoryMB, reason: .highCPU)
                        break
                    } else if memoryMB > 2500.0 {
                        await self.handleHighResourceProcess(pid: pid, name: name, cpu: cpu, mem: memoryMB, reason: .highMemory)
                        break
                    }
                }
            } catch {}
        }
    }

    private func handleHighResourceProcess(pid: Int32, name: String, cpu: Double, mem: Double, reason: GuardReason) {
        guard !alertedPIDs.contains(pid) else { return }
        alertedPIDs.insert(pid)

        let process = HighResourceProcess(pid: pid, name: name, cpuPercent: cpu, memoryMB: mem, reason: reason)
        self.alertProcess = process
        self.showAlertModal = true

        // Send Notification
        let content = UNMutableNotificationContent()
        content.title = "⚠️ 프로세스 폭주 감지: \(name)"
        content.body = "\(reason.rawValue)\nCPU: \(Int(cpu))%, 메모리: \(Int(mem)) MB"
        content.sound = .default

        let request = UNNotificationRequest(identifier: "process_guard_\(pid)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    func killAlertProcess() {
        guard let proc = alertProcess else { return }
        kill(proc.pid, SIGKILL)
        self.showAlertModal = false
        self.alertProcess = nil
    }
}
