//
//  FriendPickerSheet.swift
//  kadi
//

import SwiftUI
import KadiOnline

/// Modal sheet listing the current user's friends, for "New Message"
/// (`ConversationsListView`) and "Invite Friend" (`OnlineHostLobbyView`).
struct FriendPickerSheet: View {
    let authUser: AuthUser
    let onSelect: (Friend) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = FriendsViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                KadiTheme.backgroundGradient.ignoresSafeArea()

                if viewModel.friends.isEmpty {
                    Text("Add friends from the Profile tab to message or invite them.")
                        .font(KadiTheme.Typography.body)
                        .foregroundStyle(KadiTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(KadiTheme.Layout.spacingL)
                } else {
                    List(viewModel.friends, id: \.uid) { friend in
                        Button {
                            onSelect(friend)
                            dismiss()
                        } label: {
                            HStack(spacing: KadiTheme.Layout.spacingM) {
                                AvatarView(avatarIndex: friend.avatarId, size: 28)
                                Text(friend.displayName)
                                    .font(KadiTheme.Typography.body)
                                    .foregroundStyle(KadiTheme.Colors.textPrimary)
                            }
                        }
                        .listRowBackground(KadiTheme.Colors.surface)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Choose a Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear { viewModel.start(authUser: authUser) }
        .onDisappear { viewModel.stop() }
    }
}
