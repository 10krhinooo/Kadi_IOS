//
//  ProfileViewModel.swift
//  kadi
//

import Combine
import Foundation
import KadiOnline

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var profile: UserProfile?
    @Published var displayName: String = ""
    @Published var avatarIndex: Int = 0
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?

    private let profileService: ProfileService
    private var identity = PlayerIdentityStore()

    init(profileService: ProfileService = ProfileService()) {
        self.profileService = profileService
    }

    var trimmedDisplayName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func load(authUser: AuthUser) async {
        isLoading = true
        defer { isLoading = false }

        if identity.hasCompletedSetup {
            displayName = identity.name
            avatarIndex = identity.avatarIndex
        }

        do {
            let fetched = try await profileService.fetchProfile(uid: authUser.uid)
            profile = fetched
            if !identity.hasCompletedSetup, let fetched {
                displayName = fetched.displayName
                avatarIndex = fetched.avatarId
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func save(authUser: AuthUser) async {
        guard !trimmedDisplayName.isEmpty else { return }
        isSaving = true
        defer { isSaving = false }

        identity.name = trimmedDisplayName
        identity.avatarIndex = avatarIndex

        do {
            try await profileService.ensureProfile(
                uid: authUser.uid,
                displayName: trimmedDisplayName,
                email: authUser.email,
                avatarId: avatarIndex
            )
            profile = try await profileService.fetchProfile(uid: authUser.uid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
