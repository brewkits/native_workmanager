import XCTest
@testable import native_workmanager

// Same vector as doc/examples/remote_trigger_sign_v2.py and RemoteTriggerSignatureTest.kt.
@available(iOS 13.0, macOS 10.15, *)
final class RemoteTriggerSignatureTests: XCTestCase {
    private let secret = "s3cret"
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private let vectorHex = "dca042f1afdc1ff83ef350f17e83b78a59175ed8d5b032ca0fdb54eb47ab8f0e"

    private func vector() -> [String: Any] {
        ["type": "download_update", "url": "https://x.test/a?b=c|d", "note": "a=b|c",
         "nested": ["z": 1, "a": [1, "x/y", "é\n"]] as [String: Any],
         "flag": true, "count": 7, "nothing": NSNull(),
         "x-native-wm-timestamp": "1700000000", "x-native-wm-nonce": "nonce-0001"]
    }
    private func signed(_ mutate: (inout [String: Any]) -> Void = { _ in }) -> [String: Any] {
        var p = vector(); mutate(&p)
        p["x-native-wm-signature"] = "v2=" + RemoteTriggerSignature.signV2Hex(p, secretKey: secret)
        return p
    }
    private func check(_ p: [String: Any], store: RemoteTriggerSignature.NonceStore = .init(),
                       at: Date? = nil) -> RemoteTriggerSignature.Verdict {
        RemoteTriggerSignature.verify(payload: p, secretKey: secret, now: at ?? now, nonces: store) { _ in false }
    }

    func testMatchesCrossPlatformReferenceVector() {
        XCTAssertEqual(RemoteTriggerSignature.signV2Hex(vector(), secretKey: secret), vectorHex)
        XCTAssertEqual(check(signed()), .validV2)
    }
    func testSeparatorCharactersCannotCollide() {
        let a: [String: Any] = ["a": "1|b=2", "z": "3"]
        let b: [String: Any] = ["a": "1", "b": "2|z=3"]
        XCTAssertNotEqual(RemoteTriggerSignature.canonicalV2(a), RemoteTriggerSignature.canonicalV2(b))
    }
    func testTamperingRejected() {
        var p = signed(); p["url"] = "https://evil.test/"
        XCTAssertEqual(check(p), .invalid)
    }
    func testReplayRejected() {
        let store = RemoteTriggerSignature.NonceStore(); let p = signed()
        XCTAssertEqual(check(p, store: store), .validV2)
        XCTAssertEqual(check(p, store: store, at: now.addingTimeInterval(1)), .replayed)
    }
    func testStaleAndFutureRejected() {
        let p = signed()
        XCTAssertEqual(check(p, at: now.addingTimeInterval(301)), .stale)
        XCTAssertEqual(check(p, at: now.addingTimeInterval(-301)), .stale)
        XCTAssertEqual(check(p, at: now.addingTimeInterval(299)), .validV2)
    }
    func testMissingFieldsAndForgeryDoNotConsumeNonce() {
        XCTAssertEqual(check(signed { $0["x-native-wm-nonce"] = nil }), .invalid)
        let store = RemoteTriggerSignature.NonceStore()
        var forged = signed(); forged["x-native-wm-signature"] = "v2=" + String(repeating: "00", count: 32)
        XCTAssertEqual(check(forged, store: store), .invalid)
        XCTAssertEqual(check(signed(), store: store), .validV2)
    }
    func testMalformedSignaturesRejected() {
        for sig in ["v2=", "v2=zz", "v2=abc", ""] {
            var p = vector(); p["x-native-wm-signature"] = sig
            XCTAssertEqual(check(p), .invalid)
        }
    }
    func testLegacyDelegated() {
        var p = vector(); p["x-native-wm-signature"] = "deadbeef"
        XCTAssertEqual(RemoteTriggerSignature.verify(payload: p, secretKey: secret, now: now, nonces: .init()) { $0 == "deadbeef" }, .validLegacy)
    }
    func testUnsignedCommandRejectedOnlyWhenOptedInAndNoSecret() {
        let f = RemoteTriggerSignature.shouldRejectUnsignedCommand
        XCTAssertTrue(f(false, true, true))
        XCTAssertFalse(f(false, true, false))
        XCTAssertFalse(f(true, true, true))
        XCTAssertFalse(f(false, false, true))
    }
}
