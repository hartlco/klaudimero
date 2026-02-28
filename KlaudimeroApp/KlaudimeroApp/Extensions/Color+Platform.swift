import SwiftUI

extension Color {
    #if os(iOS)
    static let platformGray4 = Color(.systemGray4)
    static let platformGray5 = Color(.systemGray5)
    static let platformGray6 = Color(.systemGray6)
    #elseif os(macOS)
    static let platformGray4 = Color(nsColor: .systemGray).opacity(0.3)
    static let platformGray5 = Color(nsColor: .systemGray).opacity(0.2)
    static let platformGray6 = Color(nsColor: .systemGray).opacity(0.1)
    #endif
}
