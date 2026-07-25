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
    case highCPU(thresholdPercent: Double)
    case highMemory(thresholdMB: Double)

    var localizedDescription: String {
        switch self {
        case .highCPU(let threshold):
            return String(format: t("guard.reason.highCPU"), Int(threshold))
        case .highMemory(let thresholdMB):
            return String(format: t("guard.reason.highMemory"), String(format: "%.1f", thresholdMB / 1024.0))
        }
    }
}

/// 한 번의 ps 스냅샷에서 임계값을 넘긴 후보. 즉시 알리지 않고 지속 여부를 확인한다.
private struct GuardCandidate: Sendable {
    let pid: Int32
    let name: String
    let cpuPercent: Double
    let memoryMB: Double
    let isCPUBreach: Bool
}

@MainActor
final class ProcessGuardManager: NSObject, ObservableObject {
    static let shared = ProcessGuardManager()

    /// 기본 임계값. 잠깐 튀는 정상 작업(빌드, 압축, 브라우저 탭)까지 잡지 않도록 널널하게 잡는다.
    /// ps 의 %cpu 는 코어 합산이라 100 을 넘을 수 있다.
    static let defaultCPUThresholdPercent: Double = 250.0
    static let defaultMemoryThresholdMB: Double = 8192.0
    /// 임계값 초과가 이 횟수만큼 연속으로 관측돼야 알린다.
    static let defaultSustainedSamples: Int = 4
    /// 스캔 주기(초). 기본값은 4회 연속 = 약 2분 지속.
    static let scanIntervalSeconds: UInt64 = 30

    @Published var isGuardEnabled: Bool {
        didSet {
            guard oldValue != isGuardEnabled else { return }
            UserDefaults.standard.set(isGuardEnabled, forKey: Self.enabledDefaultsKey)
            if isGuardEnabled {
                startGuard()
            } else {
                stopGuard()
                breachCounts.removeAll()
                dismissAlert()
            }
        }
    }

    @Published var cpuThresholdPercent: Double {
        didSet {
            UserDefaults.standard.set(cpuThresholdPercent, forKey: Self.cpuThresholdDefaultsKey)
            breachCounts.removeAll()
        }
    }

    @Published var memoryThresholdMB: Double {
        didSet {
            UserDefaults.standard.set(memoryThresholdMB, forKey: Self.memoryThresholdDefaultsKey)
            breachCounts.removeAll()
        }
    }

    @Published var sustainedSamples: Int {
        didSet {
            UserDefaults.standard.set(sustainedSamples, forKey: Self.sustainedSamplesDefaultsKey)
            breachCounts.removeAll()
        }
    }

    @Published var alertProcess: HighResourceProcess? = nil
    @Published var showAlertModal: Bool = false

    /// 지속 조건이 사람이 읽을 수 있는 분 단위로 얼마인지.
    var sustainedWindowDescription: String {
        let seconds = Double(sustainedSamples) * Double(Self.scanIntervalSeconds)
        return String(format: "%.1f", seconds / 60.0)
    }

    private static let enabledDefaultsKey = "processGuardEnabled"
    private static let cpuThresholdDefaultsKey = "processGuardCPUThreshold"
    private static let memoryThresholdDefaultsKey = "processGuardMemoryThresholdMB"
    private static let sustainedSamplesDefaultsKey = "processGuardSustainedSamples"

    private var monitorTask: Task<Void, Never>?
    private var alertedPIDs: Set<Int32> = []
    /// PID 별 연속 초과 횟수. 한 번이라도 임계값 아래로 내려오면 사라진다.
    private var breachCounts: [Int32: Int] = [:]

    private override init() {
        let defaults = UserDefaults.standard
        // 기본값은 비활성. 사용자가 명시적으로 켤 때만 감시한다.
        isGuardEnabled = defaults.bool(forKey: Self.enabledDefaultsKey)

        let storedCPU = defaults.double(forKey: Self.cpuThresholdDefaultsKey)
        cpuThresholdPercent = storedCPU > 0 ? storedCPU : Self.defaultCPUThresholdPercent

        let storedMemory = defaults.double(forKey: Self.memoryThresholdDefaultsKey)
        memoryThresholdMB = storedMemory > 0 ? storedMemory : Self.defaultMemoryThresholdMB

        let storedSamples = defaults.integer(forKey: Self.sustainedSamplesDefaultsKey)
        sustainedSamples = storedSamples > 0 ? storedSamples : Self.defaultSustainedSamples

        super.init()
    }

    func startGuard() {
        guard isGuardEnabled, monitorTask == nil else { return }
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: Self.scanIntervalSeconds * 1_000_000_000)
                } catch {
                    break
                }
                await self?.inspectProcesses()
            }
        }
    }

    func stopGuard() {
        monitorTask?.cancel()
        monitorTask = nil
    }

    private func inspectProcesses() async {
        guard isGuardEnabled, !showAlertModal else { return }

        let cpuLimit = cpuThresholdPercent
        let memoryLimit = memoryThresholdMB

        let candidates = await Task.detached(priority: .utility) { () -> [GuardCandidate] in
            let task = Process()
            let pipe = Pipe()
            task.executableURL = URL(fileURLWithPath: "/bin/ps")
            task.arguments = ["-eo", "pid,%cpu,rss,comm"]
            task.standardOutput = pipe

            do {
                try task.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                task.waitUntilExit()

                guard let output = String(data: data, encoding: .utf8) else { return [] }
                let ownPID = ProcessInfo.processInfo.processIdentifier
                var found: [GuardCandidate] = []

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

                    if cpu > cpuLimit {
                        found.append(GuardCandidate(pid: pid, name: name, cpuPercent: cpu, memoryMB: memoryMB, isCPUBreach: true))
                    } else if memoryMB > memoryLimit {
                        found.append(GuardCandidate(pid: pid, name: name, cpuPercent: cpu, memoryMB: memoryMB, isCPUBreach: false))
                    }
                }
                return found
            } catch {
                return []
            }
        }.value

        // 이번 스냅샷에서 사라진 PID 의 누적 횟수는 리셋한다. 순간 스파이크는 알리지 않는다.
        let currentPIDs = Set(candidates.map(\.pid))
        breachCounts = breachCounts.filter { currentPIDs.contains($0.key) }
        alertedPIDs = alertedPIDs.intersection(currentPIDs)

        for candidate in candidates {
            let count = (breachCounts[candidate.pid] ?? 0) + 1
            breachCounts[candidate.pid] = count
            guard count >= sustainedSamples, !alertedPIDs.contains(candidate.pid) else { continue }

            let reason: GuardReason = candidate.isCPUBreach
                ? .highCPU(thresholdPercent: cpuLimit)
                : .highMemory(thresholdMB: memoryLimit)
            handleHighResourceProcess(HighResourceProcess(pid: candidate.pid,
                                                         name: candidate.name,
                                                         cpuPercent: candidate.cpuPercent,
                                                         memoryMB: candidate.memoryMB,
                                                         reason: reason))
            break
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
        breachCounts[proc.pid] = nil
        alertedPIDs.remove(proc.pid)
        self.showAlertModal = false
        self.alertProcess = nil
    }

    /// 사용자가 무시한 경고는 모달만 닫고 해당 PID 는 재알림하지 않는다.
    func dismissAlert() {
        self.showAlertModal = false
        self.alertProcess = nil
    }
}
