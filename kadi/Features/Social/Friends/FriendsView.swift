//
//  FriendsView.swift
//  kadi
//

import SwiftUI
import KadiOnline

/// Friends list, incoming friend requests, and blocked users (`docs/GAME_SPEC.md` §L).
/// Friends are added by UID (no user search) — see `ProfileView`'s "Your ID" row.
struct FriendsView: View {
    let authUser: AuthUser

    @StateObject private var viewModel = FriendsViewModel()
    @State private var friendPendingRemoval: Friend?
    @State private var friendPendingBlock: Friend?

    var body: some View {
        ZStack {
            KadiTheme.backgroundGradient.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: KadiTheme.Layout.spacingL) {
                    addFriendSection

                    if !viewModel.incomingRequests.isEmpty {
                        requestsSection
                    }

                    friendsSection

                    if !viewModel.blockedUsers.isEmpty {
                        blockedSection
                    }
                }
                .padding(KadiTheme.Layout.spacingL)
            }
        }
        .navigationTitle("Friends")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
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
        .confirmationDialog(
            "Remove \(friendPendingRemoval?.displayName ?? "this friend")?",
            isPresented: Binding(
                get: { friendPendingRemoval != nil },
                set: { if !$0 { friendPendingRemoval = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remove Friend", role: .destructive) {
                if let friend = friendPendingRemoval {
                    Task { await viewModel.removeFriend(friend, authUser: authUser) }
                }
                friendPendingRemoval = nil
            }
            Button("Cancel", role: .cancel) { friendPendingRemoval = nil }
        }
        .confirmationDialog(
            "Block \(friendPendingBlock?.displayName ?? "this friend")?",
            isPresented: Binding(
                get: { friendPendingBlock != nil },
                set: { if !$0 { friendPendingBlock = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Block", role: .destructive) {
                if let friend = friendPendingBlock {
                    Task { await viewModel.block(friend, authUser: authUser) }
                }
                friendPendingBlock = nil
            }
            Button("Cancel", role: .cancel) { friendPendingBlock = nil }
        } message: {
            Text("They'll be removed from your friends and won't be able to send you requests or messages.")
        }
    }

    private var addFriendSection: some View {
        VStack(alignment: .leading, spacing: KadiTheme.Layout.spacingS) {
            Text("Add Friend")
                .font(KadiTheme.Typography.headline)
                .foregroundStyle(KadiTheme.Colors.textPrimary)

            Text("Enter a friend's ID, found on their Profile screen.")
                .font(KadiTheme.Typography.caption)
                .foregroundStyle(KadiTheme.Colors.textSecondary)

            TextField("Friend's ID", text: $viewModel.addFriendUid)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif

            Button("Send Request") {
                Task { await viewModel.sendFriendRequest(authUser: authUser) }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(viewModel.trimmedAddFriendUid.isEmpty || viewModel.isWorking)
        }
    }

    private var requestsSection: some View {
        VStack(alignment: .leading, spacing: KadiTheme.Layout.spacingS) {
            Text("Requests")
                .font(KadiTheme.Typography.headline)
                .foregroundStyle(KadiTheme.Colors.textPrimary)

            VStack(spacing: KadiTheme.Layout.spacingS) {
                ForEach(viewModel.incomingRequests, id: \.id) { request in
                    HStack {
                        AvatarView(avatarIndex: request.fromAvatarId, size: 32)
                        Text(request.fromName)
                            .font(KadiTheme.Typography.body)
                            .foregroundStyle(KadiTheme.Colors.textPrimary)
                        Spacer()
                        Button("Decline") {
                            Task { await viewModel.respond(to: request, accept: false) }
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        Button("Accept") {
                            Task { await viewModel.respond(to: request, accept: true) }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding(KadiTheme.Layout.spacingS)
                    .background(KadiTheme.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: KadiTheme.Layout.cornerRadius))
                }
            }
        }
    }

    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: KadiTheme.Layout.spacingS) {
            Text("Friends")
                .font(KadiTheme.Typography.headline)
                .foregroundStyle(KadiTheme.Colors.textPrimary)

            if viewModel.friends.isEmpty {
                Text("No friends yet — share your ID from Profile to add one.")
                    .font(KadiTheme.Typography.body)
                    .foregroundStyle(KadiTheme.Colors.textSecondary)
            } else {
                VStack(spacing: KadiTheme.Layout.spacingS) {
                    ForEach(viewModel.friends, id: \.uid) { friend in
                        HStack {
                            AvatarView(avatarIndex: friend.avatarId, size: 32)
                            Text(friend.displayName)
                                .font(KadiTheme.Typography.body)
                                .foregroundStyle(KadiTheme.Colors.textPrimary)
                            Spacer()
                        }
                        .padding(KadiTheme.Layout.spacingS)
                        .background(KadiTheme.Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: KadiTheme.Layout.cornerRadius))
                        .contextMenu {
                            Button("Remove Friend", role: .destructive) {
                                friendPendingRemoval = friend
                            }
                            Button("Block", role: .destructive) {
                                friendPendingBlock = friend
                            }
                        }
                    }
                }
            }
        }
    }

    private var blockedSection: some View {
        VStack(alignment: .leading, spacing: KadiTheme.Layout.spacingS) {
            Text("Blocked")
                .font(KadiTheme.Typography.headline)
                .foregroundStyle(KadiTheme.Colors.textPrimary)

            VStack(spacing: KadiTheme.Layout.spacingS) {
                ForEach(viewModel.blockedUsers, id: \.uid) { blocked in
                    HStack {
                        Text(blocked.uid)
                            .font(KadiTheme.Typography.caption)
                            .foregroundStyle(KadiTheme.Colors.textSecondary)
                        Spacer()
                        Button("Unblock") {
                            Task { await viewModel.unblock(blocked, authUser: authUser) }
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                    .padding(KadiTheme.Layout.spacingS)
                    .background(KadiTheme.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: KadiTheme.Layout.cornerRadius))
                }
            }
        }
    }
}
