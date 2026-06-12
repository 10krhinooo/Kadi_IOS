//
//  ActionBar.swift
//  kadi
//

import SwiftUI
import KadiEngine

/// Play / Pass / Draw Stack / Declare Kadi controls, shown when it's the human's turn
/// and `phase == .playing`.
struct ActionBar: View {
    @ObservedObject var viewModel: SoloGameViewModel

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
