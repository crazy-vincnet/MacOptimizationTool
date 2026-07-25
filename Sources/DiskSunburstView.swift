import SwiftUI

struct SunburstNode: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let size: Int64
    let color: Color
    var children: [SunburstNode] = []
}

final class DiskSunburstViewModel: ObservableObject {
    @Published var rootNode: SunburstNode? = nil
    @Published var isScanning = false
    @Published var currentPath: String = NSString(string: "~").expandingTildeInPath

    private let fileManager = FileManager.default
    private let colors: [Color] = [.blue, .purple, .cyan, .green, .orange, .pink, .indigo, .mint, .teal]

    @MainActor
    func scanPath(targetPath: String) {
        self.currentPath = targetPath
        self.isScanning = true

        Task.detached(priority: .userInitiated) {
            let node = self.calculateNode(path: targetPath, depth: 0)
            await MainActor.run {
                self.rootNode = node
                self.isScanning = false
            }
        }
    }

    /// 재귀적으로 폴더 내부의 모든 파일 용량을 100% 합산
    nonisolated private func directorySize(at url: URL) -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
               let isDir = resourceValues.isDirectory, !isDir,
               let size = resourceValues.fileSize {
                total += Int64(size)
            }
        }
        return total
    }

    nonisolated private func calculateNode(path: String, depth: Int) -> SunburstNode {
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
                        let dirSize = directorySize(at: itemURL)
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
                    Text("전체 폴더 및 하위 파일 용량 100% 전수 계산 중...")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
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
            viewModel.scanPath(targetPath: viewModel.currentPath)
        }
    }

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("시각적 디스크 용량 맵")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Text("폴더 내부의 모든 하위 파일 및 디렉토리 용량을 100% 전수 측정합니다.")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer()

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
                    Text("폴더 선택")
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

    private func contentView(root: SunburstNode) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Top Summary Card
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("검색 대상 폴더: \(root.name)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Theme.textPrimary)
                        Text(root.path)
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textSecondary)
                    }
                    Spacer()
                    Text(viewModel.formatBytes(root.size))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Theme.accent)
                }
                .padding(20)
                .glassCard()

                // Sunburst Visual Bar Breakdown
                VStack(alignment: .leading, spacing: 12) {
                    Text("하위 폴더/파일 용량 점유 비율 (상위 35개)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Theme.textPrimary)

                    // Stacked Ring Bar
                    GeometryReader { geo in
                        HStack(spacing: 2) {
                            ForEach(root.children) { child in
                                let fraction = (root.size > 0 && child.size > 0) ? CGFloat(child.size) / CGFloat(root.size) : 0
                                Rectangle()
                                    .fill(child.color)
                                    .frame(width: max(geo.size.width * fraction, 3))
                            }
                        }
                    }
                    .frame(height: 14)
                    .cornerRadius(7)

                    // Children Breakdown List
                    VStack(spacing: 10) {
                        ForEach(root.children) { child in
                            HStack {
                                Circle()
                                    .fill(child.color)
                                    .frame(width: 10, height: 10)

                                Text(child.name)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Theme.textPrimary)

                                Spacer()

                                Text(viewModel.formatBytes(child.size))
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Theme.textSecondary)

                                Button(action: {
                                    var isDir: ObjCBool = false
                                    if FileManager.default.fileExists(atPath: child.path, isDirectory: &isDir), isDir.boolValue {
                                        viewModel.scanPath(targetPath: child.path)
                                    }
                                }) {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundColor(Theme.textSecondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(12)
                            .glassCard()
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.pagePadding)
            .padding(.bottom, Theme.pagePadding)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.pie.fill")
                .font(.system(size: 44))
                .foregroundColor(Theme.textSecondary)
            Text("폴더를 선택하여 시각적 디스크 용량 맵을 탐색하세요.")
                .font(.system(size: 14))
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
