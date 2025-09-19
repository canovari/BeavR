import SwiftUI

struct WhiteboardView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var viewModel = WhiteboardViewModel()
    @StateObject private var inboxViewModel = MessagesInboxViewModel()

    @State private var addTarget: WhiteboardCoordinate?
    @State private var replyTarget: WhiteboardPin?
    @State private var selectedPin: WhiteboardPin?
    @State private var showingInbox = false

    private let rows = WhiteboardGridConfiguration.rows
    private let columns = WhiteboardGridConfiguration.columns

    private var activeToken: String? {
        guard let token = authViewModel.token?.trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty else {
            return nil
        }
        return token
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        pinboardGrid
                            .padding(.top, 24)

                        if viewModel.isLoading && viewModel.pins.isEmpty {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .padding(.bottom, 24)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                .refreshable {
                    await refreshPins()
                }
            }
            .navigationTitle("Pinboard")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingInbox = true
                    } label: {
                        Image(systemName: "envelope")
                            .padding(.top, 2)
                    }
                    .accessibilityLabel("Open messages inbox")
                }
            }
            .task {
                await viewModel.loadPins()
            }
            .alert(
                "Unable to Load Pins",
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
            .sheet(item: $addTarget) { coordinate in
                if let token = activeToken {
                    AddPinSheet(
                        viewModel: viewModel,
                        coordinate: coordinate,
                        token: token
                    )
                } else {
                    MissingSessionView()
                }
            }
            .sheet(item: $selectedPin) { pin in
                PinDetailSheet(
                    pin: pin,
                    canReply: activeToken != nil,
                    onReply: {
                        selectedPin = nil
                        replyTarget = pin
                    }
                )
            }
            .sheet(item: $replyTarget) { pin in
                if let token = activeToken {
                    ReplySheet(viewModel: viewModel, pin: pin, token: token)
                } else {
                    MissingSessionView()
                }
            }
            .sheet(isPresented: $showingInbox) {
                if let token = activeToken {
                    MessagesInboxView(
                        viewModel: inboxViewModel,
                        token: token
                    )
                } else {
                    MissingSessionView()
                }
            }
        }
    }

    private var gridItems: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: columns)
    }

    private var pinboardGrid: some View {
        TimelineView(.periodic(from: .now, by: 30)) { timeline in
            gridBody(referenceDate: timeline.date)
        }
    }

    @ViewBuilder
    private func gridBody(referenceDate: Date) -> some View {
        LazyVGrid(columns: gridItems, spacing: 12) {
            ForEach(0..<(rows * self.columns), id: \.self) { index in
                let row = index / self.columns
                let column = index % self.columns
                let coordinate = WhiteboardCoordinate(row: row, column: column)

                if let pin = viewModel.pin(at: coordinate) {
                    WhiteboardPinCell(
                        pin: pin,
                        isMine: pin.creatorEmail.caseInsensitiveCompare(authViewModel.loggedInEmail ?? "") == .orderedSame,
                        referenceDate: referenceDate
                    )
                    .onTapGesture {
                        selectedPin = pin
                    }
                } else {
                    EmptySlotCell()
                        .onTapGesture {
                            guard activeToken != nil else { return }
                            addTarget = coordinate
                        }
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.06), radius: 14, x: 0, y: 8)
        )
        .padding(.horizontal, 16)
        .animation(.easeInOut(duration: 0.2), value: viewModel.pins)
    }

    private func refreshPins() async {
        let minimumDuration: TimeInterval = 1
        let start = Date()
        await viewModel.loadPins()

        guard !Task.isCancelled else { return }

        let elapsed = Date().timeIntervalSince(start)
        let remaining = minimumDuration - elapsed
        guard remaining > 0 else { return }

        let delay = UInt64((remaining * 1_000_000_000).rounded())
        try? await Task.sleep(nanoseconds: delay)
    }
}

private struct WhiteboardPinCell: View {
    let pin: WhiteboardPin
    let isMine: Bool
    let referenceDate: Date

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)

            Text(pin.emoji)
                .font(.system(size: 44))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isMine ? Color("LSERed") : Color(.separator), lineWidth: isMine ? 2 : 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(referenceDate: referenceDate))
    }

    private func accessibilityLabel(referenceDate: Date) -> String {
        var parts: [String] = [pin.emoji, pin.text]

        if let author = pin.author, !author.isEmpty {
            parts.append("Author: \(author)")
        }

        if isMine {
            parts.append("Posted by you")
        }

        if let remaining = pin.formattedTimeRemaining(referenceDate: referenceDate) {
            parts.append("Expires in \(remaining)")
        } else if pin.isExpired(referenceDate: referenceDate) {
            parts.append("Expired")
        }

        return parts.joined(separator: ". ")
    }
}

private struct EmptySlotCell: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)

            Image(systemName: "plus")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(Color(.tertiaryLabel))
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [5]))
                .foregroundColor(Color(.tertiaryLabel))
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityLabel("Add a new pin here")
    }
}

private struct PinDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    let pin: WhiteboardPin
    let canReply: Bool
    let onReply: () -> Void

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 30)) { timeline in
                sheetBody(referenceDate: timeline.date)
            }
            .navigationTitle("View Pin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func sheetBody(referenceDate: Date) -> some View {
        let isExpired = pin.isExpired(referenceDate: referenceDate)
        let remaining = pin.formattedTimeRemaining(referenceDate: referenceDate)

        VStack(spacing: 24) {
            ScrollView {
                VStack(spacing: 20) {
                    Text(pin.emoji)
                        .font(.system(size: 72))
                        .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 12) {
                        Text(pin.text)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Label("Posted by \(pin.creatorEmail)", systemImage: "envelope")
                            .font(.callout)
                            .foregroundColor(.secondary)

                        if let author = pin.author, !author.isEmpty {
                            Label(author, systemImage: "person")
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }

                        if !pin.formattedTimestamp.isEmpty {
                            Label("Posted \(pin.formattedTimestamp)", systemImage: "clock")
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }

                        if let remaining {
                            Label("Expires in \(remaining)", systemImage: "hourglass")
                                .font(.callout)
                                .foregroundColor(.secondary)
                        } else if isExpired {
                            Label("This pin has expired", systemImage: "hourglass")
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
            .scrollIndicators(.hidden)

            VStack(spacing: 12) {
                Button {
                    onReply()
                    dismiss()
                } label: {
                    Text(isExpired ? "Pin Expired" : "Reply to Pin")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color("LSERed"))
                        .cornerRadius(16)
                }
                .disabled(!canReply || isExpired)
                .opacity((canReply && !isExpired) ? 1 : 0.5)

                if !canReply {
                    Text("Log in to reply to pins.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }
}

private struct AddPinSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: WhiteboardViewModel

    let coordinate: WhiteboardCoordinate
    let token: String

    @State private var emoji: String = ""
    @State private var text: String = ""
    @State private var author: String = ""
    @State private var errorMessage: String?

    private var slotOccupied: Bool {
        viewModel.pin(at: coordinate) != nil
    }

    private var isSaveDisabled: Bool {
        emoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        slotOccupied
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Pin")) {
                    TextField("Emoji", text: $emoji)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)

                    TextField("Message", text: $text, axis: .vertical)
                        .lineLimit(2...4)

                    TextField("Author (optional)", text: $author)
                        .textInputAutocapitalization(.words)
                }

                if slotOccupied {
                    Text("Someone already posted here. Please pick another slot.")
                        .font(.footnote)
                        .foregroundColor(.red)
                }
            }
            .navigationTitle("New Pin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { submit() }
                        .disabled(isSaveDisabled || viewModel.isSubmittingPin)
                }
            }
            .alert("Couldn\'t Save Pin", isPresented: .constant(errorMessage != nil)) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func submit() {
        let trimmedEmoji = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAuthor = author.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedEmoji.isEmpty, !trimmedText.isEmpty else { return }

        Task {
            do {
                try await viewModel.createPin(
                    emoji: trimmedEmoji,
                    text: trimmedText,
                    author: trimmedAuthor.isEmpty ? nil : trimmedAuthor,
                    at: coordinate,
                    token: token
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private struct ReplySheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: WhiteboardViewModel

    let pin: WhiteboardPin
    let token: String

    @State private var message: String = ""
    @State private var author: String = ""
    @State private var errorMessage: String?

    private var isSendDisabled: Bool {
        message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Replying to")) {
                    HStack(alignment: .top, spacing: 12) {
                        Text(pin.emoji)
                            .font(.system(size: 32))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(pin.text)
                                .font(.body)
                            if let author = pin.author, !author.isEmpty {
                                Text(author)
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Section(header: Text("Message")) {
                    TextField("Your message", text: $message, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("Author (optional)", text: $author)
                        .textInputAutocapitalization(.words)
                }
            }
            .navigationTitle("Send Reply")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") { submit() }
                        .disabled(isSendDisabled || viewModel.isSendingReply)
                }
            }
            .alert("Couldn\'t Send Reply", isPresented: .constant(errorMessage != nil)) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func submit() {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAuthor = author.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedMessage.isEmpty else { return }

        Task {
            do {
                try await viewModel.sendReply(
                    to: pin,
                    message: trimmedMessage,
                    author: trimmedAuthor.isEmpty ? nil : trimmedAuthor,
                    token: token
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private struct MissingSessionView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "lock")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(.secondary)
                Text("You need to be logged in to access this feature.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            .padding()
            .navigationTitle("Unavailable")
        }
    }
}

