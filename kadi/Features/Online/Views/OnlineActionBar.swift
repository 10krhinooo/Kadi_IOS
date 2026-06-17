//
//  OnlineActionBar.swift
//  kadi
//

import SwiftUI
import KadiEngine

/// Play / Pass / Draw Stack / Declare Kadi controls, shown when it's the local player's
/// turn and `phase == .playing`. Mirrors `Features/LAN/Views/LANActionBar.swift` for
/// `OnlineGameViewModel`.
struct OnlineActionBar: View {
    @ObservedObject var viewModel: OnlineGameViewModel

    var body: some View {
        HStack(spacing: KadiTheme.Layout.spacingS) {
            if viewModel.canDeclareKadi {
                Button("KADI") {
                    Haptics.kadiDeclare()
                    viewModel.declareKadi()
                }
                .buttonStyle(KadiDeclareButtonStyle())
                .disabled(viewModel.selectedCardIndices.isEmpty)
            }

            Button("Play (\(viewModel.selectedCardIndices.count))") {
                Haptics.cardPlay()
                viewModel.confirmPlaySelected()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(viewModel.selectedCardIndices.isEmpty)

            if viewModel.state.isDrawStackActive {
                Button("Draw (+\(viewModel.state.pendingDrawCount))") {
                    viewModel.drawStack()
                }
                .buttonStyle(SecondaryButtonStyle())
            } else {
                Button("Draw Card") {
                    viewModel.pass()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(.horizontal, KadiTheme.Layout.spacingM)
    }
}
