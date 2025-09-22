import SwiftUI

struct WhiteboardView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var viewModel = WhiteboardViewModel()
    @StateObject private var inboxViewModel = MessagesInboxViewModel()
    @StateObject private var seenPinsStore = WhiteboardSeenPinsStore()

    @State private var addTarget: WhiteboardCoordinate?
    @State private var replyTarget: WhiteboardPin?
    @State private var selectedPin: WhiteboardPin?
    @State private var showingInbox = false
    @State private var showingHowItWorks = false
    @State private var hasUnreadMessages = false

    private let rows = WhiteboardGridConfiguration.rows
    private let columns = WhiteboardGridConfiguration.columns

    private var activeToken: String? {
        guard let token = authViewModel.token?.trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty else {
            return nil
        }
        return token
    }

    private var normalizedLoggedInEmail: String {
        let rawEmail = authViewModel.loggedInEmail ?? authViewModel.email
        return rawEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
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

                        howItWorksButton

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
                            .overlay(alignment: .topTrailing) {
                                if hasUnreadMessages {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 10, height: 10)
                                        .offset(x: 6, y: -6)
                                }
                            }
                    }
                    .accessibilityLabel(
                        hasUnreadMessages
                            ? "Open messages inbox, new messages available"
                            : "Open messages inbox"
                    )
                }
            }
            .task {
                await viewModel.loadPins()
            }
            .onReceive(NotificationCenter.default.publisher(for: PushNotificationManager.messageReplyReceivedNotification)) { _ in
                hasUnreadMessages = true
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
                    .environmentObject(authViewModel)
                } else {
                    MissingSessionView()
                }
            }
            .sheet(item: $selectedPin) { pin in
                let token = activeToken
                let canReply = token != nil
                let canDelete = canReply && pin.creatorEmail == normalizedLoggedInEmail

                PinDetailSheet(
                    pin: pin,
                    canReply: canReply,
                    onReply: {
                        selectedPin = nil
                        replyTarget = pin
                    },
                    canDelete: canDelete,
                    onDelete: canDelete ? {
                        if let token {
                            try await viewModel.deletePin(pin, token: token)
                        }
                    } : nil
                )
            }
            .sheet(item: $replyTarget) { pin in
                if let token = activeToken {
                    ReplySheet(viewModel: viewModel, pin: pin, token: token)
                } else {
                    MissingSessionView()
                }
            }
            .sheet(isPresented: $showingHowItWorks) {
                HowItWorksView()
            }
            .sheet(isPresented: $showingInbox) {
                if let token = activeToken {
                    MessagesInboxView(
                        viewModel: inboxViewModel,
                        token: token,
                        hasUnreadMessages: $hasUnreadMessages
                    )
                } else {
                    MissingSessionView()
                }
            }
        }
        .onChange(of: viewModel.pins) { _, newPins in
            seenPinsStore.sync(with: newPins)
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

    private var howItWorksButton: some View {
        Button {
            showingHowItWorks = true
        } label: {
            Text("How it works")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding(.horizontal, 16)
        .accessibilityLabel("Learn how the Pinboard works")
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
                        isMine: !normalizedLoggedInEmail.isEmpty && pin.creatorEmail == normalizedLoggedInEmail,
                        isSeen: seenPinsStore.isPinSeen(pin.id),
                        referenceDate: referenceDate
                    )
                    .onTapGesture {
                        seenPinsStore.markPinAsSeen(pin)
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

    @MainActor
    private func refreshPins() async {
        print("🔄 [Refresh] Starting refreshPins()")
        print("🔄 [Refresh] Current thread: \(Thread.isMainThread ? "Main" : "Background")")
        print("🔄 [Refresh] Current pin count before refresh: \(viewModel.pins.count)")
        print("🔄 [Refresh] isLoading before refresh: \(viewModel.isLoading)")

        do {
            let spinnerDelay: UInt64 = 800_000_000  // 0.8 seconds
            try await Task.sleep(nanoseconds: spinnerDelay)
        } catch {
            if Task.isCancelled {
                print("⛔️ [Refresh] refreshPins() cancelled during spinner delay")
                return
            }

            print("⚠️ [Refresh] Unexpected error during spinner delay: \(error.localizedDescription)")
        }

        if Task.isCancelled {
            print("⛔️ [Refresh] refreshPins() cancelled before reloading")
            return
        }

        await viewModel.loadPins(forceReload: true)

        print("✅ [Refresh] Completed refreshPins() — new pin count: \(viewModel.pins.count)")
    }

}

private struct HowItWorksView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("📌 Welcome to the Pinboard")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("The Pinboard is a shared space where everyone can post and interact. How it works:")

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Add a Pin → Tap an empty slot, pick 1–2 emojis, and write your text.")
                        Text("Get Replies → Others can reply directly to your pin.")
                        Text("Reply to Others → Join the conversation by replying to their pins — replies can be anonymous or include your name.")
                        Text("Stay Engaged → The more you pin and reply, the more active the board becomes.")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
            .navigationTitle("How it works")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

private struct WhiteboardPinCell: View {
    let pin: WhiteboardPin
    let isMine: Bool
    let isSeen: Bool
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
        .overlay(borderOverlay(referenceDate: referenceDate))
        .opacity(isSeen ? 0.7 : 1.0)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(referenceDate: referenceDate))
    }

    @ViewBuilder
    private func borderOverlay(referenceDate: Date) -> some View {
        let baseShape = RoundedRectangle(cornerRadius: 16, style: .continuous)

        if isMine {
            let progress = CGFloat(pin.remainingLifetimeFraction(referenceDate: referenceDate))

            ZStack {
                baseShape
                    .stroke(Color(.separator), lineWidth: 1)

                if progress > 0 {
                    baseShape
                        .trim(from: 0, to: progress)
                        .stroke(
                            Color("LSERed"),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .scaleEffect(x: -1, y: 1, anchor: .center)
                        .animation(Animation.easeInOut(duration: 0.35), value: progress)
                }
            }
        } else {
            baseShape
                .stroke(Color(.separator), lineWidth: 1)
        }
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
    let canDelete: Bool
    let onDelete: (() async throws -> Void)?

    @State private var isDeleting = false
    @State private var deleteError: String?
    @State private var showingDeleteConfirmation = false

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
                .disabled(!canReply || isExpired || isDeleting)
                .opacity((canReply && !isExpired && !isDeleting) ? 1 : 0.5)

                if !canReply {
                    Text("Log in to reply to pins.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                if canDelete, let onDelete {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        if isDeleting {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(Color("LSERed"))
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            Text("Delete Pin")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                    }
                    .disabled(isDeleting)
                    .confirmationDialog(
                        "Delete this pin?",
                        isPresented: $showingDeleteConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Delete Pin", role: .destructive) {
                            Task { await handleDelete(onDelete: onDelete) }
                        }
                        Button("Cancel", role: .cancel) { }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .alert("Couldn't Delete Pin", isPresented: Binding(
            get: { deleteError != nil },
            set: { newValue in
                if !newValue {
                    deleteError = nil
                }
            }
        )) {
            Button("OK", role: .cancel) { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
    }

    @MainActor
    private func handleDelete(onDelete: @escaping () async throws -> Void) async {
        guard !isDeleting else { return }
        showingDeleteConfirmation = false
        isDeleting = true

        do {
            try await onDelete()
            dismiss()
        } catch {
            deleteError = error.localizedDescription
        }

        isDeleting = false
    }
}

private struct AddPinSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authViewModel: AuthViewModel
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

    private var sanitizedEmojiText: String {
        sanitizeEmojiInput(from: emoji)
    }

    private var isSaveDisabled: Bool {
        sanitizedEmojiText.isEmpty ||
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
                        .onChange(of: emoji) { newValue in
                            let sanitized = sanitizeEmojiInput(from: newValue)
                            if sanitized != newValue {
                                emoji = sanitized
                            }
                        }

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
        let trimmedEmoji = sanitizedEmojiText
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAuthor = author.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedEmoji.isEmpty, !trimmedText.isEmpty else { return }

        let normalizedEmail = (authViewModel.loggedInEmail ?? authViewModel.email)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let resolvedAuthor: String?
        if !trimmedAuthor.isEmpty {
            resolvedAuthor = trimmedAuthor
        } else {
            resolvedAuthor = nil
        }

        Task {
            do {
                try await viewModel.createPin(
                    emoji: trimmedEmoji,
                    text: trimmedText,
                    author: resolvedAuthor,
                    at: coordinate,
                    token: token,
                    creatorEmail: normalizedEmail.isEmpty ? nil : normalizedEmail
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func sanitizeEmojiInput(from input: String) -> String {
        var result = ""

        for character in input {
            if isEmojiCharacter(character) {
                result.append(character)
                if result.count == 2 {
                    break
                }
            }
        }

        return result
    }

    private func isEmojiCharacter(_ character: Character) -> Bool {
        if character.unicodeScalars.count == 1 {
            return character.unicodeScalars.first?.properties.isEmoji ?? false
        } else {
            return character.unicodeScalars.contains { $0.properties.isEmoji }
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
