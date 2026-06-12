//
//  DemandEntryOverlay.swift
//  kadi
//

import SwiftUI
import KadiEngine

/// Shown when `phase == .demandEntry` and it's the human's turn — after playing the
/// Ace of Spades (or 2+ Aces), name the exact card the next player must produce.
struct DemandEntryOverlay: View {
    let onDemand: (Rank, Suit) -> Void

    @State private var rank: Rank = .two
    @State private var suit: Suit = .hearts

    private var demandableRanks: [Rank] {
        Rank.allCases.filter { $0 != .joker }
    }

    var body: some View {
        OverlayCard(title: "Make a Demand") {
            Picker("Rank", selection: $rank) {
                ForEach(demandableRanks, id: \.self) { rank in
                    Text(rank.label).tag(rank)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 100)

            Picker("Suit", selection: $suit) {
                ForEach(Suit.allCases, id: \.self) { suit in
                    Text(suit.symbol).tag(suit)
                }
            }
            .pickerStyle(.segmented)

            Button("Demand") {
                onDemand(rank, suit)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }
}
