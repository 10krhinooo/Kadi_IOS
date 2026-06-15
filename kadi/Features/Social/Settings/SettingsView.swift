//
//  SettingsView.swift
//  kadi
//

import SwiftUI
import KadiOnline

/// Account + presence settings: sign out (via the shared `AuthViewModel`) and an
/// editable custom status message (`PresenceService.updatePresence`).
struct SettingsView: View {
    let authUser: AuthUser

    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var viewModel = SettingsViewModel()
    @State private var isConfirmingSignOut = false

    var body: some View {
        ZStack {
            KadiTheme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: KadiTheme.Layout.spacingL) {
                VStack(alignment: .leading, spacing: KadiTheme.Layout.spacingS) {
                    Text("Account")
                        .font(KadiTheme.Typography.headline)
                        .foregroundStyle(KadiTheme.Colors.textPrimary)

                    Text(authUser.email ?? "")
                        .font(KadiTheme.Typography.body)
                        .foregroundStyle(KadiTheme.Colors.textSecondary)

                    Button("Sign Out") {
                        isConfirmingSignOut = true
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }

                VStack(alignment: .leading, spacing: KadiTheme.Layout.spacingS) {
                    Text("Status")
                        .font(KadiTheme.Typography.headline)
                        .foregroundStyle(KadiTheme.Colors.textPrimary)

                    TextField("What are you up to?", text: $viewModel.customStatus)
                        .textFieldStyle(.roundedBorder)

                    Button("Save Status") {
                        Task { await viewModel.saveCustomStatus(uid: authUser.uid) }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(viewModel.isSaving)
                }

                if viewModel.isLoading || viewModel.isSaving {
                    ProgressView()
                        .tint(KadiTheme.Colors.accent)
                }

                Spacer()
            }
            .padding(KadiTheme.Layout.spacingL)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load(uid: authUser.uid)
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert("Sign Out?", isPresented: $isConfirmingSignOut) {
            Button("Sign Out", role: .destructive) { authViewModel.signOut() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll need to sign in again to access your account.")
        }
    }
}
