import Foundation

/// Helpers for inspecting the device's LAN-facing network interfaces.
enum LocalNetwork {
    /// The device's primary LAN IPv4 address (prefers `en0`, the typical Wi-Fi interface on
    /// iOS/macOS), or `nil` if none could be determined.
    static func ipv4Address() -> String? {
        var result: String?
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let firstAddr = ifaddrPtr else { return nil }
        defer { freeifaddrs(ifaddrPtr) }

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            guard interface.ifa_addr.pointee.sa_family == UInt8(AF_INET) else { continue }

            let name = String(cString: interface.ifa_name)
            guard name.hasPrefix("en") else { continue }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let success = getnameinfo(
                interface.ifa_addr,
                socklen_t(interface.ifa_addr.pointee.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            )
            guard success == 0 else { continue }

            let address = String(cString: hostname)
            result = address
            if name == "en0" { break }
        }
        return result
    }
}
