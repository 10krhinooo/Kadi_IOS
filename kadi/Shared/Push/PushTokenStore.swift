//
//  PushTokenStore.swift
//  kadi
//

import Combine
import Foundation

/// Bridges `MessagingDelegate.messaging(_:didReceiveRegistrationToken:)` (delivered on
/// `AppDelegate`, a UIKit type) to SwiftUI via a published property `kadiApp` can
/// `.onChange(of:)`.
final class PushTokenStore: ObservableObject {
    static let shared = PushTokenStore()

    @Published var fcmToken: String?

    private init() {}
}
