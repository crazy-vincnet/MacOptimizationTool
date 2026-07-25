import SwiftUI
import MacOptimizationCore

struct StartupManagerView: View {
    @StateObject private var viewModel = StartupManagerViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
                .padding(.horizontal, Theme.pagePadding)
                .padding(.top, Theme.pagePadding)
                .padding(.bottom, 16)

            // Category Filter Pills
            filterPills
                .padding(.horizontal, Theme.pagePadding)
                .padding(.bottom, 20)

            // Items List
            if viewModel.isScanning {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text(t("startup.scanning"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.filteredItems.isEmpty {
                emptyView
            } else {
                itemsList
            }
        }
        .background(Theme.appBackground)
        .onAppear {
            viewModel.scanStartupItems()
        }
    }

    // MARK: - Header
    private var headerView: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(t("startup.title"))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Text(t("startup.subtitle"))
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer()

            Button(action: {
                viewModel.scanStartupItems()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text(t("common.rescan"))
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

    // MARK: - Filter Pills
    private var filterPills: some View {
        HStack(spacing: 10) {
            filterButton(title: String(format: t("startup.filter.all"), viewModel.startupItems.count), type: nil)

            ForEach(StartupType.allCases, id: \.self) { type in
                let count = viewModel.startupItems.filter { $0.type == type }.count
                filterButton(title: "\(type.displayName) (\(count))", type: type)
            }

            Spacer()
        }
    }

    private func filterButton(title: String, type: StartupType?) -> some View {
        let isSelected = viewModel.selectedFilter == type
        return Button(action: {
            viewModel.selectedFilter = type
        }) {
            Text(title)
                .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .white : Theme.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Theme.accent : Theme.bgCardHover)
                .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Items List
    private var itemsList: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(viewModel.filteredItems) { item in
                    HStack(spacing: 16) {
                        Image(systemName: item.type.icon)
                            .font(.title3)
                            .foregroundColor(Theme.accent)
                            .frame(width: 32, height: 32)
                            .background(Theme.accentGlow)
                            .cornerRadius(8)

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 8) {
                                Text(item.name)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Theme.textPrimary)

                                Text(item.type.displayName)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(Theme.textSecondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Theme.bgCardHover)
                                    .cornerRadius(4)
                            }

                            Text(item.label)
                                .font(.system(size: 11))
                                .foregroundColor(Theme.textSecondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { item.isEnabled },
                            set: { _ in viewModel.toggleStartupItem(item) }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()

                        Button(action: {
                            viewModel.removeItem(item)
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 13))
                                .foregroundColor(Theme.danger.opacity(0.8))
                                .padding(8)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(16)
                    .glassCard()
                }
            }
            .padding(.horizontal, Theme.pagePadding)
            .padding(.bottom, Theme.pagePadding)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 44))
                .foregroundColor(Theme.accent)

            Text(t("startup.empty"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
