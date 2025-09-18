import SwiftUI

struct CategorySelectionView: View {
    @Binding var selectedCategory: String

    // ✅ Emoji first, then category name
    let categories = [
        "🎨 Art Events",
        "💼 Career",
        "🎉 Club Events",
        "👨‍🍳 Cooking",
        "🌍 Cultural",
        "🎊 Festivals",
        "😎 Freebie",
        "✨ Holiday",
        "🎤 Lectures",
        "📚 Library",
        "🎬 Movie",
        "🎶 Night Life",
        "🏳️‍🌈 Pride",
        "🎵 Shows",
        "🏀 Sports",
        "🎲 Trivia",
        "🧘 Wellness"
    ].sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

    var body: some View {
        List {
            ForEach(categories, id: \.self) { cat in
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
        .navigationTitle("Select Category")
    }
}
