//
//  LeaderboardViewModel.swift
//  kadi
//

import Combine
import Foundation
import KadiOnline

@MainActor
final class LeaderboardViewModel: ObservableObject {
    @Published private(set) var players: [UserProfile] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let leaderboardService: LeaderboardService

    init(leaderboardService: LeaderboardService = LeaderboardService()) {
        self.leaderboardService = leaderboardService
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            players = try await leaderboardService.fetchTopPlayers(limit: 50)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
