//
//  ChatView.swift
//  kadi
//

import SwiftUI
import KadiOnline

/// DM chat thread between `authUser` and `otherUid`, backed by
/// `ConversationService.observeMessages(convId:)`.
struct ChatView: View {
    let authUser: AuthUser
    let otherUid: String
    let otherName: String

    @StateObject private var viewModel = ChatViewModel()

    var body: some View {
        ZStack {
            KadiTheme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: KadiTheme.Layout.spacingS) {
                        ForEach(Array(viewModel.messages.enumerated()), id: \.offset) { _, message in
                            messageBubble(message)
                        }
                    }
                    .padding(KadiTheme.Layout.spacingM)
                }

                HStack(spacing: KadiTheme.Layout.spacingS) {
                    TextField("Message", text: $viewModel.draftText)
                        .textFieldStyle(.roundedBorder)

                    Button("Send") {
                        Task { await viewModel.send(authUser: authUser, otherUid: otherUid) }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(viewModel.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(KadiTheme.Layout.spacingM)
            }
        }
        .navigationTitle(otherName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.start(authUser: authUser, otherUid: otherUid)
        }
        .onDisappear {
            viewModel.stop()
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private func messageBubble(_ message: DMMessage) -> some View {
        let isMine = message.senderUid == authUser.uid

        return HStack {
            if isMine { Spacer(minLength: 40) }

            Text(message.text)
                .font(KadiTheme.Typography.body)
                .foregroundStyle(isMine ? KadiTheme.Colors.background : KadiTheme.Colors.textPrimary)
                .padding(.horizontal, KadiTheme.Layout.spacingM)
                .padding(.vertical, KadiTheme.Layout.spacingS)
                .background(isMine ? KadiTheme.Colors.accent : KadiTheme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: KadiTheme.Layout.cornerRadius))

            if !isMine { Spacer(minLength: 40) }
        }
        .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
    }
}
