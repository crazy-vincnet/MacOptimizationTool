import SwiftUI
import MacOptimizationCore

struct SunburstNode: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let size: Int64
    let color: Color
    var children: [SunburstNode] = []
}

@MainActor
final class DiskSunburstViewModel: ObservableObject {
    @Published var rootNode: SunburstNode? = nil
    @Published var isScanning = false
    @Published var currentPath: String = NSString(string: "~").expandingTildeInPath

    /// 스캔 계산은 백그라운드에서만 수행되므로 액터 격리 밖의 정적 상수를 사용한다.
    nonisolated private static let colors: [Color] = [.blue, .purple, .cyan, .green, .orange, .pink, .indigo, .mint, .teal]

    func scanPath(targetPath: String) {
        self.currentPath = targetPath
        self.isScanning = true

        Task {
            let node = await Task.detached(priority: .userInitiated) {
                Self.calculateNode(path: targetPath, depth: 0)
            }.value
            self.rootNode = node
            self.isScanning = false
        }
    }

    /// 재귀적으로 폴더 내부의 모든 파일 용량을 100% 합산
    nonisolated private static func directorySize(at url: URL) -> Int64 {
        let keys: [URLResourceKey] = [.fileSizeKey, .isDirectoryKey]
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, _ in return true }
        ) else { return 0 }

        var total: Int64 = 0
        while let fileURL = enumerator.nextObject() as? URL {
            if let resourceValues = try? fileURL.resourceValues(forKeys: Set(keys)),
               let isDir = resourceValues.isDirectory, !isDir,
               let size = resourceValues.fileSize {
                total += Int64(size)
            }
        }
        return total
    }


    nonisolated private static func calculateNode(path: String, depth: Int) -> SunburstNode {
        let fileManager = FileManager.default
        let name = (path as NSString).lastPathComponent
        var totalSize: Int64 = 0
        var childNodes: [SunburstNode] = []

        if let contents = try? fileManager.contentsOfDirectory(atPath: path) {
            for item in contents {
                guard !item.hasPrefix(".") else { continue }
                let fullPath = (path as NSString).appendingPathComponent(item)
                let itemURL = URL(fileURLWithPath: fullPath)
                
                var isDir: ObjCBool = false
                if fileManager.fileExists(atPath: fullPath, isDirectory: &isDir) {
                    if isDir.boolValue {
                        let dirSize = Self.directorySize(at: itemURL)
                        totalSize += dirSize
                        if dirSize > 0 {
                            let color = colors[abs(item.hashValue) % colors.count]
                            childNodes.append(SunburstNode(name: item, path: fullPath, size: dirSize, color: color, children: []))
                        }
                    } else if let attrs = try? fileManager.attributesOfItem(atPath: fullPath),
                              let size = attrs[.size] as? Int64, size > 0 {
                        totalSize += size
                        let color = colors[abs(item.hashValue) % colors.count]
                        childNodes.append(SunburstNode(name: item, path: fullPath, size: size, color: color, children: []))
                    }
                }
            }
        }

        let color = colors[abs(name.hashValue) % colors.count]
        childNodes.sort(by: { $0.size > $1.size })
        return SunburstNode(name: name, path: path, size: totalSize, color: color, children: Array(childNodes.prefix(35)))
    }

    func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

struct DiskSunburstView: View {
    @StateObject private var viewModel = DiskSunburstViewModel()
    @State private var hoveredChild: SunburstNode? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
                .padding(.horizontal, Theme.pagePadding)
                .padding(.top, Theme.pagePadding)
                .padding(.bottom, 20)

            if viewModel.isScanning {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(Theme.accent)
                    Text(t("sunburst.calculating"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let root = viewModel.rootNode {
                contentView(root: root)
            } else {
                emptyView
            }
        }
        .background(Theme.appBackground)
        .onAppear {
            // 수동 스캔 모드
        }
    }

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(t("sunburst.title"))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Text(t("sunburst.subtitle"))
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer()

            HStack(spacing: 10) {
                if viewModel.rootNode != nil {
                    Button(action: {
                        viewModel.scanPath(targetPath: viewModel.currentPath)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                            Text(t("common.rescan"))
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }

                Button(action: {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    if panel.runModal() == .OK, let url = panel.url {
                        viewModel.scanPath(targetPath: url.path)
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "folder")
                        Text(t("common.selectFolder"))
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Theme.accent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Theme.accentGlow)
                    .cornerRadius(Theme.radiusControl)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func contentView(root: SunburstNode) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Top Summary Card
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(format: t("sunburst.targetFolder"), root.name))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Theme.textPrimary)
                        Text(root.path)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Theme.textSecondary)
                    }
                    Spacer()
                    Text(viewModel.formatBytes(root.size))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.accent)
                }
                .padding(20)
                .glassCard()

                // Sunburst Visual Bar Breakdown
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(t("sunburst.topItems"))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Theme.textPrimary)

                        Spacer()

                        // 툴팁 및 실시간 호버 칩 정보
                        if let hovered = hoveredChild {
                            let pct = root.size > 0 ? (Double(hovered.size) / Double(root.size) * 100.0) : 0.0
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(hovered.color)
                                    .frame(width: 8, height: 8)
                                Text(hovered.name)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Theme.textPrimary)
                                Text("•")
                                    .foregroundColor(Theme.textSecondary)
                                Text(viewModel.formatBytes(hovered.size))
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(Theme.accentDeep)
                                Text("(\(String(format: "%.1f", pct))%)")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.accent)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.radiusChip)
                                    .fill(Theme.bgCardHover)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.radiusChip)
                                    .stroke(hovered.color, lineWidth: 1)
                            )
                        } else {
                            Text(t("sunburst.hint"))
                                .font(.system(size: 11))
                                .foregroundColor(Theme.textSecondary)
                        }
                    }

                    // Interactive Stacked Ring Bar with Hover & Tooltips
                    GeometryReader { geo in
                        HStack(spacing: 2) {
                            ForEach(root.children) { child in
                                let fraction = (root.size > 0 && child.size > 0) ? CGFloat(child.size) / CGFloat(root.size) : 0
                                let pct = (root.size > 0 && child.size > 0) ? (Double(child.size) / Double(root.size) * 100.0) : 0.0
                                let isHovered = (hoveredChild?.id == child.id)

                                Rectangle()
                                    .fill(child.color)
                                    .frame(width: max(geo.size.width * fraction, 3))
                                    .opacity(hoveredChild == nil || isHovered ? 1.0 : 0.45)
                                    .scaleEffect(y: isHovered ? 1.4 : 1.0)
                                    .animation(.easeOut(duration: 0.15), value: isHovered)
                                    .help("\(child.name) • \(viewModel.formatBytes(child.size)) (\(String(format: "%.1f", pct))%)")
                                    .onHover { hovering in
                                        withAnimation(.easeInOut(duration: 0.12)) {
                                            if hovering {
                                                hoveredChild = child
                                            } else if hoveredChild?.id == child.id {
                                                hoveredChild = nil
                                            }
                                        }
                                    }
                            }
                        }
                    }
                    .frame(height: 16)
                    .cornerRadius(8)
                    .padding(.vertical, 4)

                    // Children Breakdown List
                    VStack(spacing: 10) {
                        ForEach(root.children) { child in
                            let isHovered = (hoveredChild?.id == child.id)
                            let pct = root.size > 0 ? (Double(child.size) / Double(root.size) * 100.0) : 0.0

                            HStack {
                                Circle()
                                    .fill(child.color)
                                    .frame(width: 10, height: 10)

                                Text(child.name)
                                    .font(.system(size: 13, weight: isHovered ? .bold : .semibold))
                                    .foregroundColor(Theme.textPrimary)

                                Text("(\(String(format: "%.1f", pct))%)")
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundColor(Theme.textSecondary)

                                Spacer()

                                Text(viewModel.formatBytes(child.size))
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.textSecondary)

                                Button(action: {
                                    var isDir: ObjCBool = false
                                    if FileManager.default.fileExists(atPath: child.path, isDirectory: &isDir), isDir.boolValue {
                                        viewModel.scanPath(targetPath: child.path)
                                    }
                                }) {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(Theme.textSecondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(12)
                            .glassCard(highlighted: isHovered)
                            .scaleEffect(isHovered ? 1.01 : 1.0)
                            .animation(.easeInOut(duration: 0.12), value: isHovered)
                            .onHover { hovering in
                                withAnimation(.easeInOut(duration: 0.12)) {
                                    if hovering {
                                        hoveredChild = child
                                    } else if hoveredChild?.id == child.id {
                                        hoveredChild = nil
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.pagePadding)
            .padding(.bottom, Theme.pagePadding)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "chart.pie.fill")
                .font(.system(size: 70))
                .foregroundStyle(Theme.accentGradient)
                .padding(.bottom, 10)
                .shadow(color: Theme.accent.opacity(0.25), radius: 12)

            Text(t("sunburst.empty.title"))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(Theme.textPrimary)

            Text(t("sunburst.empty.subtitle"))
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .frame(maxWidth: 480)
                .padding(.horizontal, 20)

            Button(action: {
                viewModel.scanPath(targetPath: viewModel.currentPath)
            }) {
                HStack {
                    Image(systemName: "play.fill")
                    Text(t("sunburst.start"))
                }
            }
            .buttonStyle(PrimaryActionButtonStyle())

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
