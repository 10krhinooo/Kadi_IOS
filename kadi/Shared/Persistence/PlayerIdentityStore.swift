//
//  PlayerIdentityStore.swift
//  kadi
//

import Foundation

/// Persists this device's LAN player identity (uid, display name, avatar) across
/// sessions via `UserDefaults`. The `uid` is generated once (UUID) and never changes;
/// `name`/`avatarIndex` are user-editable from `LANSetupView`.
struct PlayerIdentityStore {
    private enum Keys {
        static let uid = "kadi.lan.playerUid"
        static let name = "kadi.lan.playerName"
        static let avatarIndex = "kadi.lan.playerAvatarIndex"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Persistent device UID, generated once on first access.
    var uid: String {
        if let existing = defaults.string(forKey: Keys.uid) {
            return existing
        }
        let new = UUID().uuidString
        defaults.set(new, forKey: Keys.uid)
        return new
    }

    var name: String {
        get { defaults.string(forKey: Keys.name) ?? "" }
        set { defaults.set(newValue, forKey: Keys.name) }
    }

    var avatarIndex: Int {
        get { defaults.integer(forKey: Keys.avatarIndex) }
        set { defaults.set(newValue, forKey: Keys.avatarIndex) }
    }

    /// True once the user has entered a non-empty name at least once.
    var hasCompletedSetup: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
