//
//  AuthView.swift
//  kadi
//

import SwiftUI
import UIKit

/// Email/Password sign in / sign up form for `OnlineRootView`'s `.signedOut` state.
struct AuthView: View {
    @ObservedObject var viewModel: AuthViewModel

    private enum Mode: String, CaseIterable {
        case signIn = "Sign In"
        case signUp = "Sign Up"
    }

    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""

    private var canSubmit: Bool {
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !password.isEmpty else {
            return false
        }
        if mode == .signUp {
            return !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    var body: some View {
        ZStack {
            KadiTheme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: KadiTheme.Layout.spacingL) {
                Text("Online Multiplayer")
                    .font(KadiTheme.Typography.title)
                    .foregroundStyle(KadiTheme.Colors.textPrimary)
                    .padding(.top, KadiTheme.Layout.spacingL)

                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: KadiTheme.Layout.spacingM) {
                    if mode == .signUp {
                        VStack(alignment: .leading, spacing: KadiTheme.Layout.spacingS) {
                            Text("Display Name")
                                .font(KadiTheme.Typography.headline)
                                .foregroundStyle(KadiTheme.Colors.textPrimary)
                            TextField("Enter a display name", text: $displayName)
                                .textFieldStyle(.roundedBorder)
                                .textInputAutocapitalization(.words)
                        }
                    }

                    VStack(alignment: .leading, spacing: KadiTheme.Layout.spacingS) {
                        Text("Email")
                            .font(KadiTheme.Typography.headline)
                            .foregroundStyle(KadiTheme.Colors.textPrimary)
                        TextField("you@example.com", text: $email)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)
                    }

                    VStack(alignment: .leading, spacing: KadiTheme.Layout.spacingS) {
                        Text("Password")
                            .font(KadiTheme.Typography.headline)
                            .foregroundStyle(KadiTheme.Colors.textPrimary)
                        SecureField("At least 6 characters", text: $password)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                Spacer()

                Button(mode.rawValue) {
                    submit()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canSubmit || viewModel.isWorking)

                Button("Sign in with Google") {
                    signInWithGoogle()
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(viewModel.isWorking)

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

    private func submit() {
        Task {
            switch mode {
            case .signIn:
                await viewModel.signIn(email: email, password: password)
            case .signUp:
                await viewModel.register(email: email, password: password, displayName: displayName)
            }
        }
    }

    private func signInWithGoogle() {
        guard let viewController = UIApplication.shared.topMostViewController else { return }
        Task {
            await viewModel.signInWithGoogle(presenting: viewController)
        }
    }
}

private extension UIApplication {
    var topMostViewController: UIViewController? {
        let scene = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        guard var top = scene?.windows.first(where: \.isKeyWindow)?.rootViewController else {
            return nil
        }
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}
