//
//  FriendsViewModel.swift
//  kadi
//

import Combine
import Foundation
import KadiOnline

@MainActor
final class FriendsViewModel: ObservableObject {
    @Published private(set) var friends: [Friend] = []
    @Published private(set) var incomingRequests: [FriendRequest] = []
    @Published private(set) var blockedUsers: [BlockedUser] = []
    @Published var addFriendUid: String = ""
    @Published var isWorking = false
    @Published var errorMessage: String?

    private let friendsService: FriendsService
    private let profileService: ProfileService
    private let identity = PlayerIdentityStore()
    private var friendsTask: Task<Void, Never>?
    private var requestsTask: Task<Void, Never>?
    private var blockedTask: Task<Void, Never>?

    init(friendsService: FriendsService = FriendsService(), profileService: ProfileService = ProfileService()) {
        self.friendsService = friendsService
        self.profileService = profileService
    }

    func start(authUser: AuthUser) {
        guard friendsTask == nil else { return }

        friendsTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await friends in self.friendsService.observeFriends(uid: authUser.uid) {
                    self.friends = friends
                }
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }

        requestsTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await requests in self.friendsService.observeIncomingFriendRequests(uid: authUser.uid) {
                    self.incomingRequests = requests
                }
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }

        blockedTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await blocked in self.friendsService.observeBlockedUsers(uid: authUser.uid) {
                    self.blockedUsers = blocked
                }
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func stop() {
        friendsTask?.cancel()
        requestsTask?.cancel()
        blockedTask?.cancel()
        friendsTask = nil
        requestsTask = nil
        blockedTask = nil
    }

    var trimmedAddFriendUid: String {
        addFriendUid.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func sendFriendRequest(authUser: AuthUser) async {
        let targetUid = trimmedAddFriendUid
        guard !targetUid.isEmpty else { return }
        guard targetUid != authUser.uid else {
            errorMessage = "You can't add yourself as a friend."
            return
        }

        isWorking = true
        defer { isWorking = false }

        do {
            guard let profile = try await profileService.fetchProfile(uid: targetUid) else {
                errorMessage = "No user found with that ID."
                return
            }
            try await friendsService.sendFriendRequest(
                fromUid: authUser.uid,
                fromName: identity.name,
                fromAvatarId: identity.avatarIndex,
                toUid: profile.uid
            )
            addFriendUid = ""
        } catch FriendsServiceError.requestAlreadyPending {
            errorMessage = "A friend request is already pending between you and this user."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func respond(to request: FriendRequest, accept: Bool) async {
        guard let requestId = request.id else { return }
        do {
            try await friendsService.respondToFriendRequest(requestId: requestId, accept: accept)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeFriend(_ friend: Friend, authUser: AuthUser) async {
        do {
            try await friendsService.removeFriend(uid: authUser.uid, friendUid: friend.uid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func block(_ friend: Friend, authUser: AuthUser) async {
        do {
            try await friendsService.removeFriend(uid: authUser.uid, friendUid: friend.uid)
            try await friendsService.blockUser(uid: authUser.uid, targetUid: friend.uid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func unblock(_ blocked: BlockedUser, authUser: AuthUser) async {
        do {
            try await friendsService.unblockUser(uid: authUser.uid, targetUid: blocked.uid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
