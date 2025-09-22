import SwiftUI

struct DealsView: View {
    @ObservedObject var viewModel: DealListViewModel
    @State private var searchText: String = ""

    private var filteredDeals: [Deal] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !keyword.isEmpty else { return viewModel.deals }

        return viewModel.deals.filter { deal in
            let matchesName = deal.name.lowercased().contains(keyword)
            let matchesDescription = deal.description?.lowercased().contains(keyword) ?? false
            let matchesDiscount = deal.discount.lowercased().contains(keyword)
            return matchesName || matchesDescription || matchesDiscount
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .navigationTitle("Deals")
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search deals")
            .refreshable {
                await viewModel.refreshDeals()
            }
            .task {
                if viewModel.deals.isEmpty {
                    viewModel.fetchDeals()
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.deals.isEmpty && viewModel.isLoading {
            ProgressView()
                .progressViewStyle(.circular)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if filteredDeals.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(filteredDeals) { deal in
                        DealCardView(deal: deal)
                    }
                }
                .padding()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tag")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No deals right now")
                .font(.headline)
            Text("Check back soon – new student deals will appear here once they're approved.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct DealCardView: View {
    let deal: Deal

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(deal.kind.symbol) \(deal.kind.title)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text(deal.discount)
                    .font(.headline)
                    .foregroundColor(Color("LSERed"))
            }

            Text(deal.name)
                .font(.title3)
                .fontWeight(.semibold)

            if let description = deal.description, !description.isEmpty {
                Text(description)
                    .font(.body)
                    .foregroundColor(.primary)
            }

            if let location = deal.location, !location.isEmpty {
                Label(location, systemImage: "mappin.and.ellipse")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Text(deal.validitySummary)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 4)
    }
}
