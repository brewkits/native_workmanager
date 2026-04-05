import Foundation

/// Internal helper for Apple Archive operations (Deprecated).
///
/// Native ZIP support has been removed in v1.1.0 to achieve Zero Dependencies.
/// This file remains as a stub to satisfy build requirements.
@available(iOS 14.0, *)
class AppleArchiveHelper {
    static func extract(at sourceURL: URL, to destinationURL: URL) throws {
        throw NSError(domain: "AppleArchiveHelper", code: -1, userInfo: [NSLocalizedDescriptionKey: "Native ZIP support is removed in v1.1.0. Please use the Dart 'archive' package instead."])
    }
    
    static func compress(at sourceURL: URL, to destinationURL: URL) throws {
        throw NSError(domain: "AppleArchiveHelper", code: -1, userInfo: [NSLocalizedDescriptionKey: "Native ZIP support is removed in v1.1.0. Please use the Dart 'archive' package instead."])
    }
}
