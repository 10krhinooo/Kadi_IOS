//
//  ConversationsListView.swift
//  kadi
//

import SwiftUI
import KadiOnline

/// Identifies a chat thread to navigate to, either from an existing
/// conversation row or a freshly-picked friend.
private struct ChatTarget: Identifiable, Hashable {
    let id: String
    let name: String
}

/// List of DM conversations, per `docs/GAME_SPEC.md` §L. "New Message" opens a
/// `FriendPickerSheet` to start a conversation with a friend.
struct ConversationsListView: View {
    let authUser: AuthUser

    @StateObject private var viewModel = ConversationsViewModel()
    @State private var showingFriendPicker = false
    @State private var chatTarget: ChatTarget?

    var body: some View {
        ZStack {
            KadiTheme.backgroundGradient.ignoresSafeArea()

            if viewModel.conversations.isEmpty {
                Text("No conversations yet — start one from your friends list.")
                    .font(KadiTheme.Typography.body)
                    .foregroundStyle(KadiTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(KadiTheme.Layout.spacingL)
            } else {
                List(viewModel.conversations, id: \.participants) { conversation in
                    if let otherUid = viewModel.otherUid(for: conversation, authUser: authUser) {
                        let profile = viewModel.profiles[otherUid]
                        let unread = viewModel.unreadCount(for: conversation, authUser: authUser)

                        Button {
                            chatTarget = ChatTarget(id: otherUid, name: profile?.displayName ?? otherUid)
                        } label: {
                            HStack(spacing: KadiTheme.Layout.spacingM) {
                                AvatarView(avatarIndex: profile?.avatarId ?? 0, size: 28)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(profile?.displayName ?? otherUid)
                                        .font(KadiTheme.Typography.body)
                                        .foregroundStyle(KadiTheme.Colors.textPrimary)

                                    if let lastMessage = conversation.lastMessage {
                                        Text(lastMessage)
                                            .font(KadiTheme.Typography.caption)
                                            .foregroundStyle(KadiTheme.Colors.textSecondary)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()

                                if unread > 0 {
                                    PillBadge(text: "\(unread)", tint: KadiTheme.Colors.warning)
                                }
                            }
                        }
                        .listRowBackground(KadiTheme.Colors.surface)
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Messages")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New Message") {
                    showingFriendPicker = true
                }
            }
        }
        .sheet(isPresented: $showingFriendPicker) {
            FriendPickerSheet(authUser: authUser) { friend in
                chatTarget = ChatTarget(id: friend.uid, name: friend.displayName)
            }
        }
        .navigationDestination(item: $chatTarget) { target in
            ChatView(authUser: authUser, otherUid: target.id, otherName: target.name)
        }
        .task {
            viewModel.start(authUser: authUser)
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
}
