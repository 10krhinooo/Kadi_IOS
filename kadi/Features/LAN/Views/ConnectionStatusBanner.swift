//
//  ConnectionStatusBanner.swift
//  kadi
//

import SwiftUI

/// Top-of-screen banner shown during host migration (promoting/reconnecting) or after a
/// failed reconnect attempt, with an optional "Retry" action.
struct ConnectionStatusBanner: View {
    let message: String
    var isError: Bool = false
    var onRetry: (() -> Void)?

    var body: some View {
        HStack(spacing: KadiTheme.Layout.spacingS) {
            if isError {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(KadiTheme.Colors.warning)
            } else {
                ProgressView()
                    .tint(KadiTheme.Colors.accent)
            }

            Text(message)
                .font(KadiTheme.Typography.callout)
                .foregroundStyle(KadiTheme.Colors.textPrimary)

            Spacer()

            if let onRetry {
                Button("Retry", action: onRetry)
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(KadiTheme.Layout.spacingM)
        .background(
            RoundedRectangle(cornerRadius: KadiTheme.Layout.cornerRadius)
                .fill(KadiTheme.Colors.surfaceElevated)
        )
        .padding(.horizontal, KadiTheme.Layout.spacingM)
    }
}

#Preview {
    VStack(spacing: KadiTheme.Layout.spacingM) {
        ConnectionStatusBanner(message: "Taking over as host…")
        ConnectionStatusBanner(message: "Searching for new host…")
        ConnectionStatusBanner(message: "Couldn't find the new host.", isError: true, onRetry: {})
    }
    .padding()
    .background(KadiTheme.Colors.tableFelt)
}
