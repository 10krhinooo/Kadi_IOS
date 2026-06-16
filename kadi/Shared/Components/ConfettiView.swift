//
//  ConfettiView.swift
//  kadi

import SwiftUI

/// Looping confetti rain drawn on a Canvas — zero UIView overhead, smooth 60fps.
struct ConfettiView: View {
    private struct Particle {
        let startX: CGFloat   // 0…1 fraction of width
        let delay: Double     // seconds before first appearance
        let cycleDuration: Double
        let rotationRate: Double  // full turns per cycle
        let color: Color
        let shape: Int        // 0 = rect, 1 = circle, 2 = thin strip
    }

    private let particles: [Particle]
    @State private var startDate = Date()

    private static let palette: [Color] = [
        KadiTheme.Colors.accent,
        .red, .green, .blue, .pink, .orange, .purple, .cyan, .yellow
    ]

    init(count: Int = 70) {
        particles = (0..<count).map { _ in
            Particle(
                startX: .random(in: 0...1),
                delay: .random(in: 0...2.5),
                cycleDuration: .random(in: 2.2...4.0),
                rotationRate: .random(in: 0.5...2.5),
                color: Self.palette.randomElement()!,
                shape: Int.random(in: 0...2)
            )
        }
    }

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { context, size in
                let elapsed = tl.date.timeIntervalSince(startDate)
                for p in particles {
                    let adjusted = elapsed + p.delay
                    guard adjusted > 0 else { continue }
                    let t = adjusted.truncatingRemainder(dividingBy: p.cycleDuration) / p.cycleDuration
                    let x = p.startX * size.width
                    let y = t * (size.height + 40) - 20
                    let angle = Angle.degrees(t * p.rotationRate * 360)

                    context.drawLayer { ctx in
                        ctx.translateBy(x: x, y: y)
                        ctx.rotate(by: angle)
                        let rect: CGRect
                        switch p.shape {
                        case 1:
                            rect = CGRect(x: -5, y: -5, width: 10, height: 10)
                            ctx.fill(Circle().path(in: rect), with: .color(p.color))
                        case 2:
                            rect = CGRect(x: -2, y: -8, width: 4, height: 16)
                            ctx.fill(Rectangle().path(in: rect), with: .color(p.color))
                        default:
                            rect = CGRect(x: -4, y: -6, width: 8, height: 12)
                            ctx.fill(Rectangle().path(in: rect), with: .color(p.color))
                        }
                    }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear { startDate = Date() }
    }
}
