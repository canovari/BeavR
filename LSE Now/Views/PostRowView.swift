import SwiftUI

struct PostRowView: View {
    let post: Post

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Category placeholder (first letter or ?)
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.secondary.opacity(0.3))
                .frame(width: 64, height: 64)
                .overlay(
                    Text(String((post.category ?? "?").prefix(1)))
                        .font(.headline)
                )

            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(post.title)
                    .font(.headline)

                // Date / Time
                if let end = post.endTime {
                    Text("\(post.startTime.formatted(date: .abbreviated, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text(post.startTime.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Description (optional, 2 lines max)
                if let desc = post.description, !desc.isEmpty {
                    Text(desc)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }
}
