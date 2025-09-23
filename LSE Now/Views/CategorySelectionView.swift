import SwiftUI

struct CategorySelectionView: View {
    @Binding var selectedCategory: String

    var body: some View {
        List {
            ForEach(EventCategoryCatalog.grouped, id: \.title) { group in
                Section(header: Text(group.title)) {
                    ForEach(group.categories, id: \.self) { cat in
                        categoryRow(for: cat)
                    }
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
