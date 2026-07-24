import SwiftUI
import UniformTypeIdentifiers

struct UninstallerView: View {
    @StateObject private var viewModel = UninstallerViewModel()
    @State private var isTargeted = false
    @State private var searchText = ""
    @State private var showDeleteConfirm = false
    
    // 전체 선택 상태를 제어하기 위한 계산 프로퍼티
    private var isAllSelected: Bool {
        get {
            !viewModel.leftoverItems.isEmpty && viewModel.leftoverItems.allSatisfy { $0.isSelected }
        }
        set {
            for i in 0..<viewModel.leftoverItems.count {
                viewModel.leftoverItems[i].isSelected = newValue
            }
        }
    }
    
    // 선택된 아이템 정보 계산
    private var selectedCount: Int {
        viewModel.leftoverItems.filter { $0.isSelected }.count
    }
    
    private var selectedSize: Int64 {
        viewModel.leftoverItems.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
    }
    
    private var readableSelectedSize: String {
        ByteCountFormatter.string(fromByteCount: selectedSize, countStyle: .file)
    }
    
    // 검색 및 정렬 조건이 반영된 앱 목록
    private var filteredApps: [SelectedAppInfo] {
        var apps = viewModel.installedApps
        
        if !searchText.isEmpty {
            apps = apps.filter { $0.name.lowercased().contains(searchText.lowercased()) }
        }
        
        switch viewModel.sortOption {
        case .nameAsc:
            apps.sort(by: { $0.name.localizedCompare($1.name) == .orderedAscending })
        case .nameDesc:
            apps.sort(by: { $0.name.localizedCompare($1.name) == .orderedDescending })
        case .sizeDesc:
            apps.sort(by: { $0.size > $1.size })
        case .sizeAsc:
            apps.sort(by: { $0.size < $1.size })
        case .dateDesc:
            apps.sort(by: { $0.installationDate > $1.installationDate })
        case .dateAsc:
            apps.sort(by: { $0.installationDate < $1.installationDate })
        }
        
        return apps
    }
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 20) {
                // 헤더 영역
                PageHeader(
                    title: t("uninst.title"),
                    subtitle: t("uninst.subtitle"),
                    icon: "trash.circle.fill"
                )
                
                if viewModel.selectedApp == nil {
                    // 앱이 아직 선택되지 않은 경우: 드롭존 및 설치 앱 리스트
                    if viewModel.showCleanSuccess {
                        cleanSuccessView
                    } else {
                        unselectedStateView
                    }
                } else {
                    // 앱이 선택되어 스캔 중이거나 스캔 완료된 경우
                    if viewModel.isScanning {
                        scanningView
                    } else {
                        scanResultView
                    }
                }
            }
            .padding(Theme.pagePadding)
            .onAppear {
                // 진입 시 설치된 앱 목록을 불러옵니다.
                if viewModel.installedApps.isEmpty {
                    viewModel.fetchInstalledApps()
                }
            }
            
            // 삭제 처리 중 오버레이
            if viewModel.isCleaning {
                ZStack {
                    Color.black.opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack(spacing: 15) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(Theme.accent)
                        Text(t("uninst.movingToTrash"))
                            .fontWeight(.medium)
                            .foregroundColor(Theme.textPrimary)
                    }
                    .glassCard(padding: 30, radius: Theme.radiusCard, highlighted: true)
                }
            }
        }
    }
    
    // 미선택 상태: 드롭존 + 설치된 앱 검색 리스트
    private var unselectedStateView: some View {
        VStack(alignment: .leading, spacing: 15) {
            // 콤팩트 가로형 드롭존
            compactDropZoneView
                .frame(height: 110)
            
            // 앱 검색 및 카운트 헤더
            HStack(spacing: 12) {
                Text("\(t("uninst.installedApps")): \(filteredApps.count)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)

                Spacer()

                // 새로고침 버튼
                Button(action: {
                    viewModel.fetchInstalledApps()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(Theme.textSecondary)
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.radiusChip, style: .continuous)
                                .fill(.ultraThinMaterial)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.radiusChip, style: .continuous)
                                .stroke(Theme.hairlineSoft, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .help(t("uninst.refreshHelp"))

                // 정렬 필터
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.and.down.text.horizontal")
                        .foregroundColor(Theme.textSecondary)
                        .font(.system(size: 11))
                    Picker(t("uninst.sortLabel"), selection: $viewModel.sortOption) {
                        ForEach(AppSortOption.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 130)
                    .tint(Theme.accent)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: Theme.radiusChip, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusChip, style: .continuous)
                        .stroke(Theme.hairlineSoft, lineWidth: 1)
                )

                // 검색 텍스트 필드
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Theme.textSecondary)
                    TextField(t("uninst.searchPlaceholder"), text: $searchText)
                        .textFieldStyle(.plain)
                        .frame(width: 180)

                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Theme.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: Theme.radiusChip, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusChip, style: .continuous)
                        .stroke(Theme.hairlineSoft, lineWidth: 1)
                )
            }
            .padding(.top, 10)
            
            // 앱 리스트 그리드 영역
            if viewModel.isSearchingApps {
                VStack(spacing: 15) {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.0)
                        .tint(Theme.accent)
                    Text(t("uninst.loadingApps"))
                        .foregroundColor(Theme.textSecondary)
                        .font(.subheadline)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 260, maximum: .infinity), spacing: 12)], spacing: 12) {
                        ForEach(filteredApps) { app in
                            Button(action: {
                                viewModel.loadAppAndScan(at: app.url)
                            }) {
                                installedAppCard(for: app)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 5)
                }
            }
        }
    }
    
    // 콤팩트 가로형 드롭존 디자인
    private var compactDropZoneView: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(t("uninst.dropZoneTitle"))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                Text(t("uninst.dropZoneSubtitle"))
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)

                Button(action: {
                    viewModel.selectAppAndScan()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle")
                        Text(t("uninst.selectManually"))
                    }
                    .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(SecondaryButtonStyle())
                .padding(.top, 4)
            }

            Spacer()

            Image(systemName: "square.and.arrow.down.on.square.fill")
                .font(.system(size: 42))
                .foregroundStyle(
                    isTargeted
                        ? AnyShapeStyle(Theme.accentGradient)
                        : AnyShapeStyle(Color.secondary.opacity(0.4))
                )
                .scaleEffect(isTargeted ? 1.08 : 1.0)
                .animation(.spring(), value: isTargeted)
                .padding(.trailing, 10)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                .fill(isTargeted ? Theme.accent.opacity(0.06) : Color.clear)
                .background(
                    RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                .strokeBorder(
                    isTargeted ? Theme.accent : Theme.hairline,
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 4])
                )
        )
        .shadow(color: Color.black.opacity(0.06), radius: 14, x: 0, y: 6)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, error in
                if let url = url {
                    DispatchQueue.main.async {
                        viewModel.handleDroppedAppURL(url)
                    }
                }
            }
            return true
        }
    }
    
    // 날짜 포맷 함수
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: date)
    }
    
    // 개별 설치된 앱 카드 디자인
    private func installedAppCard(for app: SelectedAppInfo) -> some View {
        HStack(spacing: 12) {
            Image(nsImage: app.icon)
                .resizable()
                .frame(width: 38, height: 38)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(app.name)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(app.readableSize)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.accentDeep)

                    Text("•")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textSecondary.opacity(0.5))

                    Text(formatDate(app.installationDate))
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textSecondary)

                    if let version = app.version {
                        Text("•")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textSecondary.opacity(0.5))

                        Text("v\(version)")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textSecondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Theme.textSecondary.opacity(0.6))
        }
        .glassCard(padding: 12, radius: Theme.radiusControl)
    }
    
    // 2. 스캔 로딩 뷰
    private var scanningView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
                .tint(Theme.accent)
            VStack(spacing: 5) {
                Text(t("uninst.scanning"))
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                if let app = viewModel.selectedApp {
                    Text("\(app.name) \(t("uninst.scanningDetail"))")
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // 3. 스캔 완료 목록 뷰
    private var scanResultView: some View {
        VStack(spacing: 15) {
            // 상단: 선택된 앱 요약 정보 바
            if let app = viewModel.selectedApp {
                HStack(spacing: 15) {
                    Image(nsImage: app.icon)
                        .resizable()
                        .frame(width: 48, height: 48)
                        
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(alignment: .lastTextBaseline) {
                            Text(app.name)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.textPrimary)
                            if let version = app.version {
                                Text("v\(version)")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                        if let bid = app.bundleID {
                            Text(bid)
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        Text(t("uninst.appSize"))
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                        Text(app.readableSize)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.accentDeep)
                    }
                }
                .glassCard(padding: 15, radius: Theme.radiusControl)
            }
            
            // 중단: 찌꺼기 파일 목록 테이블
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    // 전체 선택 체크박스
                    Toggle(isOn: Binding(
                        get: { !viewModel.leftoverItems.isEmpty && viewModel.leftoverItems.allSatisfy { $0.isSelected } },
                        set: { newValue in
                            for i in 0..<viewModel.leftoverItems.count {
                                viewModel.leftoverItems[i].isSelected = newValue
                            }
                        }
                    )) {
                        Text(t("uninst.fileNameAndPath"))
                            .fontWeight(.semibold)
                            .foregroundColor(Theme.textPrimary)
                    }
                    .toggleStyle(CheckboxToggleStyle())

                    Spacer()

                    Text(t("uninst.typeAndSize"))
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.textPrimary)
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 5)

                Divider()

                ScrollView {
                    VStack(spacing: 8) {
                        ForEach($viewModel.leftoverItems) { $item in
                            leftoverRow(for: $item)
                        }
                    }
                    .padding(.vertical, 5)
                }
            }
            .glassCard(padding: 15, radius: Theme.radiusCard)
            
            // 하단: 제어 및 액션 바
            HStack {
                Button(action: {
                    viewModel.reset()
                }) {
                    Text(t("uninst.cancel"))
                }
                .buttonStyle(SecondaryButtonStyle())

                Spacer()

                HStack(spacing: 15) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(t("uninst.selectedFiles")): \(selectedCount)")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                        Text("\(t("uninst.totalSelectedSize")): \(readableSelectedSize)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                    }

                    Button(action: {
                        showDeleteConfirm = true
                    }) {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text(t("uninst.moveSelectedToTrash"))
                        }
                    }
                    .buttonStyle(DangerActionButtonStyle(enabled: selectedCount > 0))
                    .disabled(selectedCount == 0)
                    .confirmationDialog(
                        "\(viewModel.selectedApp?.name ?? t("uninst.appFallback")) · \(selectedCount)\(t("uninst.confirmItemsToTrash"))",
                        isPresented: $showDeleteConfirm,
                        titleVisibility: .visible
                    ) {
                        Button("\(t("uninst.moveToTrash")) (\(readableSelectedSize))", role: .destructive) {
                            viewModel.deleteSelectedItems()
                        }
                        Button(t("uninst.cancel"), role: .cancel) {}
                    } message: {
                        Text(t("uninst.recoverNote"))
                    }
                }
            }
            .padding(.top, 5)
        }
    }
    
    // 개별 찌꺼기 파일 로우 뷰
    private func leftoverRow(for item: Binding<LeftoverItem>) -> some View {
        HStack(spacing: 12) {
            Toggle(isOn: item.isSelected) {
                HStack(spacing: 10) {
                    Image(systemName: item.wrappedValue.category.iconName)
                        .foregroundColor(categoryColor(item.wrappedValue.category))
                        .font(.title3)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.wrappedValue.url.lastPathComponent)
                            .fontWeight(.medium)
                            .foregroundColor(Theme.textPrimary)
                            .lineLimit(1)
                        Text(abbreviatePath(item.wrappedValue.path))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Theme.textSecondary)
                            .lineLimit(1)
                            .help(item.wrappedValue.path)
                    }
                }
            }
            .toggleStyle(CheckboxToggleStyle())

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(item.wrappedValue.category.displayName)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                Text(item.wrappedValue.readableSize)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusControl, style: .continuous)
                .fill(item.wrappedValue.isSelected ? Theme.accent.opacity(0.10) : Color.clear)
                .background(
                    RoundedRectangle(cornerRadius: Theme.radiusControl, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusControl, style: .continuous)
                .stroke(item.wrappedValue.isSelected ? Theme.accent.opacity(0.4) : Theme.hairlineSoft, lineWidth: 1)
        )
    }
    
    // 4. 완료 화면 뷰
    private var cleanSuccessView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 70))
                .foregroundStyle(Theme.accentGradient)
                .shadow(color: Theme.accent.opacity(0.3), radius: 10, x: 0, y: 5)

            VStack(spacing: 8) {
                Text(t("uninst.optimizeComplete"))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                Text(t("uninst.movedSafely"))
                    .font(.headline)
                    .foregroundColor(Theme.textSecondary)
                Text("\(t("uninst.freedTotal")): \(ByteCountFormatter.string(fromByteCount: viewModel.cleanedSize, countStyle: .file))")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.accentDeep)
                    .padding(.top, 5)
            }
            .padding(.bottom, 20)

            Button(action: {
                viewModel.reset()
            }) {
                Text(t("uninst.backToMain"))
            }
            .buttonStyle(PrimaryActionButtonStyle())
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // 카테고리별 컬러 매핑
    private func categoryColor(_ category: LeftoverCategory) -> Color {
        switch category {
        case .appBundle: return Theme.accent
        case .appSupport: return Theme.warning
        case .caches: return Theme.danger
        case .preferences: return Theme.textSecondary
        case .logs: return Theme.textSecondary
        case .containers: return Theme.accentDeep
        case .launchAgents: return Theme.textSecondary
        case .others: return Theme.textSecondary
        }
    }
    
    // 경로를 읽기 쉽도록 줄여주는 함수 (예: ~/Library/...)
    private func abbreviatePath(_ path: String) -> String {
        let homePath = NSHomeDirectory()
        if path.hasPrefix(homePath) {
            return path.replacingOccurrences(of: homePath, with: "~")
        }
        return path
    }
}
