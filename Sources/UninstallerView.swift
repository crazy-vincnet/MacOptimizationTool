import SwiftUI
import UniformTypeIdentifiers

struct UninstallerView: View {
    @StateObject private var viewModel = UninstallerViewModel()
    @State private var isTargeted = false
    @State private var searchText = ""
    
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
                VStack(alignment: .leading, spacing: 5) {
                    Text("앱 완전 삭제기")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("단순히 앱만 삭제하면 시스템에 남겨지는 캐시, 설정, 찌꺼기 파일을 완전 제거합니다.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
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
            .padding(30)
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
                        Text("안전하게 파일들을 휴지통으로 이동하는 중...")
                            .fontWeight(.medium)
                    }
                    .padding(30)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color(NSColor.windowBackgroundColor)))
                    .shadow(radius: 20)
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
                Text("설치된 응용 프로그램 (\(filteredApps.count)개)")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // 새로고침 버튼
                Button(action: {
                    viewModel.fetchInstalledApps()
                }) {
                    ZStack {
                        Color(NSColor.controlBackgroundColor)
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12, weight: .bold))
                    }
                    .frame(width: 28, height: 28)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .help("설치된 앱 목록 새로고침")
                
                // 정렬 필터
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.and.down.text.horizontal")
                        .foregroundColor(.secondary)
                        .font(.system(size: 11))
                    Picker("정렬", selection: $viewModel.sortOption) {
                        ForEach(AppSortOption.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 130)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                
                // 검색 텍스트 필드
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("앱 이름 검색...", text: $searchText)
                        .textFieldStyle(.plain)
                        .frame(width: 180)
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
            }
            .padding(.top, 10)
            
            // 앱 리스트 그리드 영역
            if viewModel.isSearchingApps {
                VStack(spacing: 15) {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.0)
                    Text("설치된 앱 리스트를 불러오는 중...")
                        .foregroundColor(.secondary)
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
                Text("여기에 앱(.app) 파일을 드래그 앤 드롭하세요")
                    .font(.headline)
                Text("드롭하면 관련된 캐시 및 찌꺼기 파일의 경로와 용량을 정밀 추적합니다.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button(action: {
                    viewModel.selectAppAndScan()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle")
                        Text("수동으로 앱 파일 선택...")
                    }
                    .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                .padding(.top, 4)
            }
            
            Spacer()
            
            Image(systemName: "square.and.arrow.down.on.square.fill")
                .font(.system(size: 42))
                .foregroundStyle(
                    LinearGradient(
                        colors: isTargeted ? [.green, .teal] : [.gray.opacity(0.4), .gray.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(isTargeted ? 1.08 : 1.0)
                .animation(.spring(), value: isTargeted)
                .padding(.trailing, 10)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    isTargeted ? Color.green : Color.gray.opacity(0.2),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 4])
                )
                .background(isTargeted ? Color.green.opacity(0.04) : Color.clear)
        )
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
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text(app.readableSize)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                    
                    Text("•")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    Text(formatDate(app.installationDate))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    if let version = app.version {
                        Text("•")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.5))
                        
                        Text("v\(version)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary.opacity(0.6))
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }
    
    // 2. 스캔 로딩 뷰
    private var scanningView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            VStack(spacing: 5) {
                Text("찌꺼기 파일 탐색 중...")
                    .font(.headline)
                if let app = viewModel.selectedApp {
                    Text("\(app.name) 앱의 캐시, 환경설정, 로그 등을 추적하고 있습니다.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
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
                                .font(.title3)
                                .fontWeight(.bold)
                            if let version = app.version {
                                Text("v\(version)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        if let bid = app.bundleID {
                            Text(bid)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("앱 크기")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(app.readableSize)
                            .font(.headline)
                    }
                }
                .padding(15)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
                .cornerRadius(12)
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
                        Text("파일명 및 경로")
                            .fontWeight(.semibold)
                    }
                    .toggleStyle(CheckboxToggleStyle())
                    
                    Spacer()
                    
                    Text("유형 및 크기")
                        .fontWeight(.semibold)
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
            .padding(15)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.gray.opacity(0.15), lineWidth: 1)
            )
            
            // 하단: 제어 및 액션 바
            HStack {
                Button(action: {
                    viewModel.reset()
                }) {
                    Text("취소")
                        .padding(.horizontal, 15)
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                HStack(spacing: 15) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("선택된 파일: \(selectedCount)개")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("총 선택 크기: \(readableSelectedSize)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                    }
                    
                    Button(action: {
                        viewModel.deleteSelectedItems()
                    }) {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text("선택된 항목 휴지통으로 이동")
                        }
                        .fontWeight(.bold)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(selectedCount == 0)
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
                            .lineLimit(1)
                        Text(abbreviatePath(item.wrappedValue.path))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
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
                    .foregroundColor(.secondary)
                Text(item.wrappedValue.readableSize)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor).opacity(item.wrappedValue.isSelected ? 0.4 : 0.1))
        .cornerRadius(10)
    }
    
    // 4. 완료 화면 뷰
    private var cleanSuccessView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 70))
                .foregroundColor(.green)
                .shadow(color: .green.opacity(0.3), radius: 10, x: 0, y: 5)
            
            VStack(spacing: 8) {
                Text("최적화 완료!")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("선택한 항목들을 휴지통으로 안전하게 보냈습니다.")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text("확보된 총 용량: \(ByteCountFormatter.string(fromByteCount: viewModel.cleanedSize, countStyle: .file))")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                    .padding(.top, 5)
            }
            .padding(.bottom, 20)
            
            Button(action: {
                viewModel.reset()
            }) {
                Text("메인 화면으로 돌아가기")
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // 카테고리별 컬러 매핑
    private func categoryColor(_ category: LeftoverCategory) -> Color {
        switch category {
        case .appBundle: return .green
        case .appSupport: return .orange
        case .caches: return .red
        case .preferences: return .purple
        case .logs: return .gray
        case .containers: return .teal
        case .launchAgents: return .pink
        case .others: return .yellow
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
