//
//  OnlineSetupView.swift
//  kadi
//

import SwiftUI
import KadiEngine
import KadiOnline

/// Post-auth online entry screen: collects name/avatar (persisted via
/// `PlayerIdentityStore`, reused from LAN), upserts the player's profile, and offers
/// "Create Room" / "Join Room" (by 6-char code).
struct OnlineSetupView: View {
    let authUser: AuthUser

    @State private var identity = PlayerIdentityStore()
    @State private var name: String = ""
    @State private var avatarIndex: Int = 0
    @State private var joinCode: String = ""
    @State private var isCreating = false
    @State private var isJoining = false
    @State private var errorMessage: String?
    @State private var createdRoomId: String?
    @State private var joinedRoomId: String?
    @State private var joinedPlayerIndex: Int = 0

    private let roomService = RoomService()
    private let profileService = ProfileService()

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedJoinCode: String {
        joinCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    var body: some View {
        ZStack {
            KadiTheme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: KadiTheme.Layout.spacingL) {
                Text("Online Multiplayer")
                    .font(KadiTheme.Typography.title)
                    .foregroundStyle(KadiTheme.Colors.textPrimary)
                    .padding(.top, KadiTheme.Layout.spacingL)

                VStack(alignment: .leading, spacing: KadiTheme.Layout.spacingS) {
                    Text("Your Name")
                        .font(KadiTheme.Typography.headline)
                        .foregroundStyle(KadiTheme.Colors.textPrimary)

                    TextField("Enter a display name", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: name) { _, newValue in
                            identity.name = newValue
                        }
                }

                VStack(alignment: .leading, spacing: KadiTheme.Layout.spacingS) {
                    Text("Avatar")
                        .font(KadiTheme.Typography.headline)
                        .foregroundStyle(KadiTheme.Colors.textPrimary)

                    AvatarPickerView(selectedAvatarIndex: $avatarIndex)
                        .onChange(of: avatarIndex) { _, newValue in
                            identity.avatarIndex = newValue
                        }
                }

                Spacer()

                VStack(spacing: KadiTheme.Layout.spacingM) {
                    Button("Create Room") {
                        createRoom()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(trimmedName.isEmpty || isCreating || isJoining)

                    VStack(alignment: .leading, spacing: KadiTheme.Layout.spacingS) {
                        Text("Room Code")
                            .font(KadiTheme.Typography.headline)
                            .foregroundStyle(KadiTheme.Colors.textPrimary)

                        TextField("ABC123", text: $joinCode)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                    }

                    Button("Join Room") {
                        joinRoom()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(trimmedName.isEmpty || trimmedJoinCode.isEmpty || isCreating || isJoining)

                    if isCreating || isJoining {
                        ProgressView()
                            .tint(KadiTheme.Colors.accent)
                    }
                }
            }
            .padding(KadiTheme.Layout.spacingL)
        }
        .navigationTitle("Online")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            name = identity.name
            avatarIndex = identity.avatarIndex
            Task {
                try? await profileService.ensureProfile(
                    uid: authUser.uid,
                    displayName: identity.name,
                    email: authUser.email,
                    avatarId: identity.avatarIndex
                )
            }
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .navigationDestination(isPresented: Binding(
            get: { createdRoomId != nil },
            set: { if !$0 { createdRoomId = nil } }
        )) {
            if let roomId = createdRoomId {
                OnlineHostLobbyView(roomId: roomId, authUser: authUser)
            }
        }
        .navigationDestination(isPresented: Binding(
            get: { joinedRoomId != nil },
            set: { if !$0 { joinedRoomId = nil } }
        )) {
            if let roomId = joinedRoomId {
                OnlineGuestLobbyView(roomId: roomId, localPlayerIndex: joinedPlayerIndex, authUser: authUser)
            }
        }
    }

    private func createRoom() {
        isCreating = true
        Task {
            defer { isCreating = false }
            do {
                let roomId = try await roomService.createRoom(
                    hostUid: authUser.uid,
                    hostName: identity.name,
                    rules: RuleSet()
                )
                createdRoomId = roomId
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func joinRoom() {
        isJoining = true
        Task {
            defer { isJoining = false }
            do {
                let playerIndex = try await roomService.joinRoom(
                    roomId: trimmedJoinCode,
                    uid: authUser.uid,
                    name: identity.name
                )
                joinedPlayerIndex = playerIndex
                joinedRoomId = trimmedJoinCode
            } catch RoomServiceError.roomNotFound {
                errorMessage = "No room found with that code."
            } catch RoomServiceError.roomFull {
                errorMessage = "That room is full."
            } catch RoomServiceError.roomAlreadyStarted {
                errorMessage = "That game has already started."
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
