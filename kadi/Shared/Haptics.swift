//
//  Haptics.swift
//  kadi
//

import UIKit

enum Haptics {
    static func cardTap()     { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func cardPlay()    { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func kadiDeclare() { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
    static func win()         { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func error()       { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}
