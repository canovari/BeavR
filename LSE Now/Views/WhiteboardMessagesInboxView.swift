import SwiftUI

struct MessagesInboxView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MessagesInboxViewModel

    let token: String

    @State private var selectedFolder: MessagesInboxViewModel.Folder = .received

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Picker("Mailbox", selection: $selectedFolder) {
                    ForEach(MessagesInboxViewModel.Folder.allCases, id: \.self) { folder in
                        Text(folder.title).tag(folder)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 16)

                content
                    .animation(.easeInOut(duration: 0.2), value: viewModel.messages)

                Spacer(minLength: 0)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Messages")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task(id: selectedFolder) {
                await viewModel.fetchMessages(folder: selectedFolder, token: token)
            }
            .alert(
                "Unable to Load Messages",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { newValue in
                        if !newValue {
                            viewModel.errorMessage = nil
                        }
                    }
                )
            ) {
                Button("OK", role: .cancel) {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.messages.isEmpty {
            ProgressView()
                .padding(.top, 40)
        } else if viewModel.messages.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "tray")
                    .font(.system(size: 36))
                    .foregroundColor(.secondary)
                Text(emptyStateText)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(.top, 48)
        } else {
            List {
                ForEach(viewModel.messages) { message in
                    MessageRow(message: message, folder: selectedFolder)
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .refreshable {
                await viewModel.fetchMessages(folder: selectedFolder, token: token)
            }
        }
    }

    private var emptyStateText: String {
        switch selectedFolder {
        case .received:
            return "No one has replied to your pins yet."
        case .sent:
            return "You haven\'t sent any whiteboard replies yet."
        }
    }
}

private struct MessageRow: View {
    let message: WhiteboardMessage
    let folder: MessagesInboxViewModel.Folder

    private var descriptor: String {
        switch folder {
        case .received:
            return "From \(message.senderEmail)"
        case .sent:
            return "To \(message.receiverEmail)"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let author = message.author, !author.isEmpty {
                Text(author)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(message.message)
                .font(.body)
                .foregroundColor(.primary)

            Text(descriptor)
                .font(.footnote)
                .foregroundColor(.secondary)

            if !message.formattedTimestamp.isEmpty {
                Text(message.formattedTimestamp)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(.separator), lineWidth: 1)
        )
    }
}
