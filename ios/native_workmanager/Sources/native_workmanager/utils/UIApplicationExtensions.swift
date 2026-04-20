import UIKit

public extension UIApplication {
    /// Returns the root view controller of the currently active window, compatible
    /// with both the legacy UIApplicationDelegate window and the modern UIWindowScene
    /// API introduced in iOS 13 (required for Flutter 3.38+ scene-based apps).
    ///
    /// Must be called on the main thread — UIKit window/view controller access is
    /// not thread-safe. Call sites should use DispatchQueue.main.async or MainActor.
    @MainActor
    var activeRootViewController: UIViewController? {
        if #available(iOS 13.0, *) {
            return connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .filter { $0.activationState == .foregroundActive }
                .first?
                .windows
                .first(where: \.isKeyWindow)?
                .rootViewController
        }
        // iOS 12 fallback (deprecated API, safe on legacy UIApplicationDelegate apps)
        return keyWindow?.rootViewController
    }
}
