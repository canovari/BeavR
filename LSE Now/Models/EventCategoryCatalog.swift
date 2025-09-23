import Foundation

enum EventCategoryCatalog {
    static let social: [String] = [
        "🥳 Festivals",
        "🍕 Food",
        "🎁 Freebie",
        "🎮 Gaming",
        "🎲 Games",
        "🎥 Movies",
        "🎉 Parties",
        "🍻 Pubs"
    ].sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

    static let culturalLifestyle: [String] = [
        "🖼️ Art",
        "🌱 Charity",
        "🌍 Culture",
        "🎶 Music",
        "🧑‍🍳 Skills",
        "🎭 Theatre",
        "🧘 Wellness"
    ].sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

    static let academicCareer: [String] = [
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

    static let grouped: [(title: String, categories: [String])] = [
        ("Social", social),
        ("Cultural & Lifestyle", culturalLifestyle),
        ("Academic & Career", academicCareer)
    ]

    static let all: [String] = {
        var combined: Set<String> = []
        for group in grouped {
            combined.formUnion(group.categories)
        }
        return combined.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }()
}
