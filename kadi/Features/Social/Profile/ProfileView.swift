//
//  ProfileView.swift
//  kadi
//

import SwiftUI
import KadiOnline
#if canImport(UIKit)
import UIKit
#endif

/// Own-profile screen: edit display name/avatar (persisted via `PlayerIdentityStore`
/// and `ProfileService.ensureProfile`, same convention as `OnlineSetupView`) and view
/// stats from `/users/{uid}`.
struct ProfileView: View {
    let authUser: AuthUser

    @StateObject private var viewModel = ProfileViewModel()

    var body: some View {
        ZStack {
            KadiTheme.backgroundGradient.ignoresSafeArea()

            ScrollView {
                VStack(spacing: KadiTheme.Layout.spacingL) {
                    AvatarView(avatarIndex: viewModel.avatarIndex, size: 64)
                        .padding(.top, KadiTheme.Layout.spacingL)

                    VStack(alignment: .leading, spacing: KadiTheme.Layout.spacingS) {
                        Text("Display Name")
                            .font(KadiTheme.Typography.headline)
                            .foregroundStyle(KadiTheme.Colors.textPrimary)

                        TextField("Enter a display name", text: $viewModel.displayName)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: KadiTheme.Layout.spacingS) {
                        Text("Avatar")
                            .font(KadiTheme.Typography.headline)
                            .foregroundStyle(KadiTheme.Colors.textPrimary)

                        AvatarPickerView(selectedAvatarIndex: $viewModel.avatarIndex)
                    }

                    if let profile = viewModel.profile {
                        statsSection(profile)
                    }

                    yourIdSection

                    Button("Save") {
                        Task { await viewModel.save(authUser: authUser) }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(viewModel.trimmedDisplayName.isEmpty || viewModel.isSaving)

                    if viewModel.isLoading || viewModel.isSaving {
                        ProgressView()
                            .tint(KadiTheme.Colors.accent)
                    }
                }
                .padding(KadiTheme.Layout.spacingL)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load(authUser: authUser)
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private func statsSection(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: KadiTheme.Layout.spacingS) {
            Text("Stats")
                .font(KadiTheme.Typography.headline)
                .foregroundStyle(KadiTheme.Colors.textPrimary)

            VStack(spacing: KadiTheme.Layout.spacingS) {
                statRow("Points", profile.points)
                statRow("Wins", profile.wins)
                statRow("Losses", profile.losses)
                statRow("Games Played", profile.gamesPlayed)
                statRow("Quits", profile.quits)
            }
            .padding(KadiTheme.Layout.spacingM)
            .background(KadiTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: KadiTheme.Layout.cornerRadius))
        }
    }

    private var yourIdSection: some View {
        VStack(alignment: .leading, spacing: KadiTheme.Layout.spacingS) {
            Text("Your ID")
                .font(KadiTheme.Typography.headline)
                .foregroundStyle(KadiTheme.Colors.textPrimary)

            Text("Share this with friends so they can add you.")
                .font(KadiTheme.Typography.caption)
                .foregroundStyle(KadiTheme.Colors.textSecondary)

            HStack {
                Text(authUser.uid)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(KadiTheme.Colors.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Button {
                    #if canImport(UIKit)
                    UIPasteboard.general.string = authUser.uid
                    #endif
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .padding(KadiTheme.Layout.spacingM)
            .background(KadiTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: KadiTheme.Layout.cornerRadius))
        }
    }

    private func statRow(_ label: String, _ value: Int) -> some View {
        HStack {
            Text(label)
                .font(KadiTheme.Typography.body)
                .foregroundStyle(KadiTheme.Colors.textSecondary)
            Spacer()
            Text("\(value)")
                .font(KadiTheme.Typography.body)
                .foregroundStyle(KadiTheme.Colors.textPrimary)
        }
    }
}
