//
//  LANJoinBrowserViewModel.swift
//  kadi
//

import Combine
import Foundation
import KadiNetworking

/// Browses for LAN games via `LANBrowser` and connects to a chosen host as a
/// `LANGameClient`.
@MainActor
final class LANJoinBrowserViewModel: ObservableObject {
    @Published var hosts: [DiscoveredHost] = []
    @Published var connectedClient: LANGameClient?
    @Published var didConnect = false
    @Published var errorMessage: String?
    @Published var isJoining = false

    private let identity: PlayerIdentityStore
    private let browser = LANBrowser()
    private var browseTask: Task<Void, Never>?

    init(identity: PlayerIdentityStore) {
        self.identity = identity
    }

    func startBrowsing() {
        let browser = self.browser
        browseTask = Task { [weak self] in
            for await host in await browser.discoveredHosts() {
                guard let self else { return }
                if !self.hosts.contains(host) {
                    self.hosts.append(host)
                }
            }
        }
    }

    func stopBrowsing() {
        browseTask?.cancel()
        let browser = self.browser
        Task { await browser.stop() }
    }

    func join(_ host: DiscoveredHost) {
        isJoining = true
        errorMessage = nil
        let identity = self.identity
        Task {
            do {
                let client = try await LANGameClient.connect(
                    to: host.endpoint,
                    name: identity.name,
                    uid: identity.uid,
                    avatarIndex: identity.avatarIndex
                )
                self.connectedClient = client
                self.didConnect = true
            } catch {
                self.errorMessage = "\(error)"
            }
            self.isJoining = false
        }
    }
}
