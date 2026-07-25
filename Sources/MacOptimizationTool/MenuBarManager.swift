import Foundation
import AppKit
import SwiftUI
import MacOptimizationCore

@MainActor
final class MenuBarManager: NSObject, ObservableObject {
    static let shared = MenuBarManager()

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var updateTimer: Timer?

    @Published var cpuUsage: Double = 0.0
    @Published var memoryUsage: Double = 0.0
    /// 커널 통계 조회에 한 번이라도 성공했는지. 실패 상태에서는 수치 대신 `--` 를 표시한다.
    @Published var hasCPUReading: Bool = false
    @Published var hasMemoryReading: Bool = false
    @Published var downloadSpeed: String = "0 KB/s"
    @Published var uploadSpeed: String = "0 KB/s"

    private var prevBytesIn: UInt64 = 0
    private var prevBytesOut: UInt64 = 0
    private var lastNetworkCheckTime: Date = Date()

    private override init() {
        super.init()
    }

    func setupMenuBar() {
        guard statusItem == nil else { return }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "bolt.horizontal.circle.fill", accessibilityDescription: "MacOptimizationTool")

            button.action = #selector(togglePopover)
            button.target = self
        }

        let popoverView = MenuBarMiniView()
        let hostingController = NSHostingController(rootView: popoverView)
        
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 320, height: 380)
        popover?.behavior = .transient
        popover?.contentViewController = hostingController

        startMonitoring()
    }

    @objc func togglePopover() {
        guard let button = statusItem?.button, let popover = popover else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func startMonitoring() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateStats()
            }
        }
    }

    private func updateStats() {
        if let ramStats = HardwareStatsHelper.getRAMStats(), ramStats.total > 0 {
            self.memoryUsage = Double(ramStats.used) / Double(ramStats.total)
            self.hasMemoryReading = true
        } else {
            self.hasMemoryReading = false
        }

        Task.detached(priority: .utility) {
            let cpu = HardwareStatsHelper.getCPUUsage()
            await MainActor.run {
                // 측정 실패 시 직전 값을 유지한다 (추정값을 지어내지 않음).
                if let cpu {
                    self.cpuUsage = cpu / 100.0
                    self.hasCPUReading = true
                }
            }
        }

        updateNetworkSpeed()

        if let button = statusItem?.button {
            button.title = hasMemoryReading ? " \(Int(self.memoryUsage * 100))%" : " --"
        }
    }

    private func updateNetworkSpeed() {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return }
        defer { freeifaddrs(ifaddr) }

        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let flags = Int32(ptr.pointee.ifa_flags)
            if (flags & IFF_UP) != 0 && (flags & IFF_LOOPBACK) == 0 {
                if let data = ptr.pointee.ifa_data {
                    let networkData = data.assumingMemoryBound(to: if_data.self)
                    totalIn += UInt64(networkData.pointee.ifi_ibytes)
                    totalOut += UInt64(networkData.pointee.ifi_obytes)
                }
            }
        }

        let now = Date()
        let timeInterval = now.timeIntervalSince(lastNetworkCheckTime)
        if timeInterval > 0 && prevBytesIn > 0 {
            let bytesInPerSec = Double(totalIn - prevBytesIn) / timeInterval
            let bytesOutPerSec = Double(totalOut - prevBytesOut) / timeInterval

            self.downloadSpeed = formatSpeed(bytesInPerSec)
            self.uploadSpeed = formatSpeed(bytesOutPerSec)
        }

        prevBytesIn = totalIn
        prevBytesOut = totalOut
        lastNetworkCheckTime = now
    }

    private func formatSpeed(_ bytesPerSec: Double) -> String {
        if bytesPerSec >= 1_048_576 {
            return String(format: "%.1f MB/s", bytesPerSec / 1_048_576)
        } else {
            return String(format: "%.0f KB/s", bytesPerSec / 1024)
        }
    }
}

// MARK: - Mini Dashboard Popover View
struct MenuBarMiniView: View {
    @ObservedObject var menuManager = MenuBarManager.shared

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "bolt.circle.fill")
                    .foregroundColor(Theme.accent)
                    .font(.title2)
                Text("MacOptimizationTool Mini")

                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
            }

            Divider().background(Theme.hairline)

            // Memory & CPU Gauges
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(t("menubar.ramUsage"))
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                    Text(menuManager.hasMemoryReading ? "\(Int(menuManager.memoryUsage * 100))%" : "--")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard(padding: 12)

                VStack(alignment: .leading, spacing: 6) {
                    Text(t("menubar.cpuUsage"))
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                    Text(menuManager.hasCPUReading ? "\(Int(menuManager.cpuUsage * 100))%" : "--")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Theme.accent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard(padding: 12)
            }

            // Network Meter
            VStack(spacing: 8) {
                HStack {
                    Label(t("menubar.download"), systemImage: "arrow.down.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    Text(menuManager.downloadSpeed)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                }
                HStack {
                    Label(t("menubar.upload"), systemImage: "arrow.up.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    Text(menuManager.uploadSpeed)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                }
            }
            .glassCard(padding: 12)

            // Actions
            Button(action: {
                Task(priority: .userInitiated) {
                    let p = Process()
                    p.launchPath = "/usr/sbin/purge"
                    try? p.run()
                    p.waitUntilExit()
                }
            }) {
                HStack {
                    Image(systemName: "sparkles")
                    Text(t("menubar.optimizeNow"))
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Theme.accent)
                .cornerRadius(Theme.radiusControl)
            }
            .buttonStyle(.plain)

            Button(action: {
                NSApp.activate(ignoringOtherApps: true)
                for window in NSApp.windows {
                    window.makeKeyAndOrderFront(nil)
                }
            }) {
                Text(t("menubar.openMain"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(width: 320, height: 380)
        .background(Theme.bgCard)
    }
}
