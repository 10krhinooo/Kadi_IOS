//
//  SettingsViewModel.swift
//  kadi
//

import Combine
import Foundation
import KadiOnline

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var customStatus: String = ""
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?

    private let presenceService: PresenceService

    init(presenceService: PresenceService = PresenceService()) {
        self.presenceService = presenceService
    }

    func load(uid: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            for try await presence in presenceService.observePresence(uid: uid) {
                customStatus = presence?.customStatus ?? ""
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveCustomStatus(uid: String) async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await presenceService.updatePresence(uid: uid, customStatus: customStatus)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
