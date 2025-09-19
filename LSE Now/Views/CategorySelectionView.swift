import SwiftUI

struct CategorySelectionView: View {
    @Binding var selectedCategory: String

    // 🎉 Social
    private let socialCategories = [
        "🥳 Festivals",
        "🍕 Food",
        "🎁 Freebie",
        "🎮 Gaming",
        "🎲 Games",
        "🎥 Movies",
        "🎉 Parties",
        "🍻 Pubs"
    ].sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

    // 🌍 Cultural & Lifestyle
    private let culturalCategories = [
        "🖼️ Art",
        "🌱 Charity",
        "🌍 Culture",
        "🎶 Music",
        "🧑‍🍳 Skills",
        "🎭 Theatre",
        "🧘 Wellness"
    ].sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

    // 📚 Academic & Career
    private let academicCategories = [
        "💼 Careers",
        "🧠 Debate",
        "📊 Finance",
        "⚖️ Law",
        "🧮 Math",
        "🏛️ Politics",
        "🧾 Research",
        "📚 Study",
        "🎤 Talks"
    ].sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

    var body: some View {
        List {
            Section(header: Text("Social")) {
                ForEach(socialCategories, id: \.self) { cat in
                    categoryRow(for: cat)
                }
            }

            Section(header: Text("Cultural & Lifestyle")) {
                ForEach(culturalCategories, id: \.self) { cat in
                    categoryRow(for: cat)
                }
            }

            Section(header: Text("Academic & Career")) {
                ForEach(academicCategories, id: \.self) { cat in
                    categoryRow(for: cat)
                }
            }
        }
        .navigationTitle("Select Category")
    }

    private func categoryRow(for cat: String) -> some View {
        Button(action: {
            selectedCategory = cat
        }) {
            HStack {
                Text(cat)
                if selectedCategory == cat {
                    Spacer()
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
        }
    }
}
