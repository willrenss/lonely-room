#if canImport(UIKit)
import UIKit

// MARK: - Haptics
/// Wrapper haptic feedback yang menghormati toggle di Pengaturan.
enum Haptics {
    private static let light     = UIImpactFeedbackGenerator(style: .light)
    private static let medium    = UIImpactFeedbackGenerator(style: .medium)
    private static let selection = UISelectionFeedbackGenerator()
    private static let notify    = UINotificationFeedbackGenerator()

    private static var enabled: Bool { AppSettings.shared.hapticsEnabled }

    static func tap()     { guard enabled else { return }; light.impactOccurred() }
    static func thump()   { guard enabled else { return }; medium.impactOccurred() }
    static func select()  { guard enabled else { return }; selection.selectionChanged() }
    static func success() { guard enabled else { return }; notify.notificationOccurred(.success) }
    static func warning() { guard enabled else { return }; notify.notificationOccurred(.warning) }
}
#endif
