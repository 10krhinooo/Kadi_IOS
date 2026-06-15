//
//  SocialHubViewModel.swift
//  kadi
//

import Combine
import Foundation
import KadiOnline

@MainActor
final class SocialHubViewModel: ObservableObject {
    @Published private(set) var pendingRequestCount: Int = 0

    private let friendsService: FriendsService
    private var task: Task<Void, Never>?

    init(friendsService: FriendsService = FriendsService()) {
        self.friendsService = friendsService
    }

    func start(authUser: AuthUser) {
        guard task == nil else { return }
        task = Task { [weak self] in
            guard let self else { return }
            do {
                for try await requests in self.friendsService.observeIncomingFriendRequests(uid: authUser.uid) {
                    self.pendingRequestCount = requests.count
                }
            } catch {
                // Badge is best-effort; ignore errors.
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
