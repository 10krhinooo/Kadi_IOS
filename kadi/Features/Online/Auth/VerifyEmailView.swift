//
//  VerifyEmailView.swift
//  kadi
//

import SwiftUI
import KadiOnline

/// Shown for `.needsVerification` — prompts the user to verify their email before they
/// can create/join online rooms.
struct VerifyEmailView: View {
    @ObservedObject var viewModel: AuthViewModel
    let user: AuthUser

    var body: some View {
        ZStack {
            KadiTheme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: KadiTheme.Layout.spacingL) {
                Spacer()

                Text("Verify Your Email")
                    .font(KadiTheme.Typography.title)
                    .foregroundStyle(KadiTheme.Colors.textPrimary)

                Text("We sent a verification link to \(user.email ?? "your email address"). Open it, then tap Continue.")
                    .font(KadiTheme.Typography.body)
                    .foregroundStyle(KadiTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)

                Spacer()

                VStack(spacing: KadiTheme.Layout.spacingM) {
                    Button("I've Verified — Continue") {
                        Task { await viewModel.reload() }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(viewModel.isWorking)

                    Button("Resend Email") {
                        Task { await viewModel.resendVerification() }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(viewModel.isWorking)

                    Button("Sign Out") {
                        viewModel.signOut()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }

                if viewModel.isWorking {
                    ProgressView()
                        .tint(KadiTheme.Colors.accent)
                }
            }
            .padding(KadiTheme.Layout.spacingL)
        }
        .navigationTitle("Online")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}
