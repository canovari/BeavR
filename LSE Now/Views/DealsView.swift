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
            let matchesLocation = deal.location?.lowercased().contains(keyword) ?? false
            let matchesLink = deal.link?.lowercased().contains(keyword) ?? false
            return matchesName || matchesDescription || matchesDiscount || matchesLocation || matchesLink
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
                await refreshDeals()
            }
            .task {
                if viewModel.deals.isEmpty {
                    viewModel.fetchDeals()
                }
            }
            .navigationDestination(for: Deal.self) { deal in
                DealDetailView(deal: deal)
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
                        NavigationLink(value: deal) {
                            DealCardView(deal: deal)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .scrollIndicators(.hidden)
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

    private func refreshDeals() async {
        print("🔄 [Refresh] Starting refreshDeals()")
        print("🔄 [Refresh] Current deal count before refresh: \(viewModel.deals.count)")
        print("🔄 [Refresh] isLoading before refresh: \(viewModel.isLoading)")

        do {
            let spinnerDelay: UInt64 = 800_000_000  // 0.8 seconds
            try await Task.sleep(nanoseconds: spinnerDelay)
        } catch {
            if Task.isCancelled {
                print("⛔️ [Refresh] refreshDeals() cancelled during spinner delay")
                return
            }

            print("⚠️ [Refresh] Unexpected error during spinner delay: \(error.localizedDescription)")
        }

        if Task.isCancelled {
            print("⛔️ [Refresh] refreshDeals() cancelled before reloading")
            return
        }

        await viewModel.refreshDeals()

        print("✅ [Refresh] Completed refreshDeals() — new deal count: \(viewModel.deals.count)")
    }
}

private struct DealCardView: View {
    let deal: Deal

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(deal.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)

                    Spacer(minLength: 12)

                    Text(deal.discount)
                        .font(.headline)
                        .foregroundColor(Color("LSERed"))
                }

                if let location = deal.location, !location.isEmpty {
                    Label(location, systemImage: "mappin.and.ellipse")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Text(deal.validitySummary)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.footnote)
                .foregroundColor(Color(.tertiaryLabel))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 4)
    }
}

private struct DealDetailView: View {
    let deal: Deal
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(deal.name)
                    .font(.largeTitle)
                    .bold()
                    .multilineTextAlignment(.leading)

                if !deal.discount.isEmpty {
                    Text(deal.discount)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color("LSERed").opacity(0.12))
                        .foregroundColor(Color("LSERed"))
                        .clipShape(Capsule())
                }

                Text("\(deal.kind.symbol) \(deal.kind.title)")
                    .font(.headline)
                    .foregroundColor(.secondary)

                if let description = deal.description, !description.isEmpty {
                    Text(description)
                        .font(.body)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let location = deal.location, !location.isEmpty {
                    Label(location, systemImage: "mappin.and.ellipse")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Text(deal.validitySummary)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if let link = deal.link, let url = sanitizedURL(from: link) {
                    Button {
                        openURL(url)
                    } label: {
                        Label("Open Link", systemImage: "link")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color("LSERed"))
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Deal Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sanitizedURL(from rawLink: String) -> URL? {
        let trimmed = rawLink.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }

        let prefixed = "https://" + trimmed
        if let url = URL(string: prefixed) {
            return url
        }

        let allowed = CharacterSet.urlFragmentAllowed
            .union(.urlHostAllowed)
            .union(.urlPathAllowed)
            .union(.urlQueryAllowed)
        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: allowed) ?? trimmed

        if let url = URL(string: encoded), url.scheme != nil {
            return url
        }

        return URL(string: "https://" + encoded)
    }
}
