//
//  LANJoinBrowserView.swift
//  kadi
//

import SwiftUI
import KadiNetworking

/// Lists LAN games discovered via Bonjour/UDP beacon and joins one as a guest.
struct LANJoinBrowserView: View {
    @StateObject private var viewModel: LANJoinBrowserViewModel
    private let identity: PlayerIdentityStore

    init(identity: PlayerIdentityStore) {
        self.identity = identity
        _viewModel = StateObject(wrappedValue: LANJoinBrowserViewModel(identity: identity))
    }

    var body: some View {
        ZStack {
            KadiTheme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: KadiTheme.Layout.spacingL) {
                Text("Join Game")
                    .font(KadiTheme.Typography.title)
                    .foregroundStyle(KadiTheme.Colors.textPrimary)
                    .padding(.top, KadiTheme.Layout.spacingL)

                if viewModel.hosts.isEmpty {
                    Spacer()
                    ProgressView("Searching for games…")
                        .tint(KadiTheme.Colors.accent)
                        .foregroundStyle(KadiTheme.Colors.textSecondary)
                    Spacer()
                } else {
                    List(viewModel.hosts, id: \.name) { host in
                        Button {
                            viewModel.join(host)
                        } label: {
                            HStack {
                                Text(host.name)
                                    .foregroundStyle(KadiTheme.Colors.textPrimary)
                                Spacer()
                                if viewModel.isJoining {
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(viewModel.isJoining)
                    }
                    .scrollContentBackground(.hidden)
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(KadiTheme.Typography.callout)
                        .foregroundStyle(KadiTheme.Colors.warning)
                }
            }
            .padding(KadiTheme.Layout.spacingL)
        }
        .navigationTitle("Join Game")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.startBrowsing() }
        .onDisappear {
            if !viewModel.didConnect {
                viewModel.stopBrowsing()
            }
        }
        .navigationDestination(isPresented: $viewModel.didConnect) {
            if let client = viewModel.connectedClient {
                LANGuestLobbyView(client: client, identity: identity)
            }
        }
    }
}
