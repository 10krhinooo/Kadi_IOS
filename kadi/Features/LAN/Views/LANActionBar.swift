//
//  LANActionBar.swift
//  kadi
//

import SwiftUI
import KadiEngine

/// Play / Pass / Draw Stack / Declare Kadi controls, shown when it's the local player's
/// turn and `phase == .playing`. Mirrors `Features/Game/Views/ActionBar.swift` for
/// `LANGameViewModel`.
struct LANActionBar: View {
    @ObservedObject var viewModel: LANGameViewModel

    var body: some View {
        HStack(spacing: KadiTheme.Layout.spacingS) {
            Button("Play (\(viewModel.selectedCardIndices.count))") {
                viewModel.confirmPlaySelected()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(viewModel.selectedCardIndices.isEmpty)

            Button("Pass") {
                viewModel.pass()
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(viewModel.state.isDrawStackActive)

            if viewModel.state.isDrawStackActive {
                Button("Draw Stack") {
                    viewModel.drawStack()
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            if viewModel.canDeclareKadi {
                Button("Declare Kadi") {
                    viewModel.declareKadi()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(.horizontal, KadiTheme.Layout.spacingM)
    }
}
