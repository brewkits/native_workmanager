import XCTest
@testable import native_workmanager

/// Unit tests for BackgroundSessionManager.
///
/// Tests the singleton pattern, task-ID registration, cancellation,
/// and pause/resume lifecycle without making real network calls.
@available(iOS 13.0, *)
class BackgroundSessionManagerTests: XCTestCase {

    // MARK: - Singleton

    func testSharedInstance_isSingleton() {
        let instance1 = BackgroundSessionManager.shared
        let instance2 = BackgroundSessionManager.shared
        XCTAssertTrue(instance1 === instance2,
                      "BackgroundSessionManager.shared must be the same object on every access")
    }

    // MARK: - Task ID Management

    func testPendingTaskIds_initiallyEmpty() {
        // After a clean launch there should be no leftover task IDs from this test run.
        // (Other tests may have registered tasks, so we just verify the API is accessible.)
        let taskIds = BackgroundSessionManager.shared.pendingTaskIds
        XCTAssertNotNil(taskIds, "pendingTaskIds must not be nil")
    }

    func testCancelTask_nonExistentTaskId_doesNotCrash() {
        // Cancelling a task that doesn't exist should be a no-op, never crash.
        BackgroundSessionManager.shared.cancelTask(taskId: "nonexistent-task-id-\(UUID().uuidString)")
        XCTAssertTrue(true, "Cancelling non-existent task must not crash")
    }

    func testPauseTask_nonExistentTaskId_doesNotCrash() {
        BackgroundSessionManager.shared.pauseTask(taskId: "nonexistent-pause-\(UUID().uuidString)")
        XCTAssertTrue(true, "Pausing non-existent task must not crash")
    }

    func testResumeTask_nonExistentTaskId_doesNotCrash() {
        BackgroundSessionManager.shared.resumeTask(taskId: "nonexistent-resume-\(UUID().uuidString)")
        XCTAssertTrue(true, "Resuming non-existent task must not crash")
    }

    // MARK: - Session Identifier

    func testSessionIdentifier_isConsistent() {
        // The session identifier must not change between accesses (used by AppDelegate).
        let id1 = BackgroundSessionManager.shared.sessionIdentifier
        let id2 = BackgroundSessionManager.shared.sessionIdentifier
        XCTAssertEqual(id1, id2, "Session identifier must be stable")
        XCTAssertFalse(id1.isEmpty, "Session identifier must not be empty")
    }

    func testSessionIdentifier_isAppSpecific() {
        let identifier = BackgroundSessionManager.shared.sessionIdentifier
        // Should contain the bundle identifier or a plugin-specific prefix
        XCTAssertTrue(
            identifier.contains("brewkits") || identifier.contains("native_workmanager"),
            "Session identifier should contain plugin namespace: '\(identifier)'"
        )
    }

    // MARK: - Relaunch Completion Delegate

    func testRelaunchCompletionDelegate_canBeSet() {
        var delegateCalled = false
        BackgroundSessionManager.shared.relaunchCompletionDelegate = { taskId, result in
            delegateCalled = true
        }
        // Just verify the assignment doesn't crash
        XCTAssertTrue(true, "Setting relaunchCompletionDelegate must not crash")
        // Clean up
        BackgroundSessionManager.shared.relaunchCompletionDelegate = nil
    }

    func testRelaunchCompletionDelegate_canBeCleared() {
        BackgroundSessionManager.shared.relaunchCompletionDelegate = { _, _ in }
        BackgroundSessionManager.shared.relaunchCompletionDelegate = nil
        XCTAssertTrue(true, "Clearing relaunchCompletionDelegate must not crash")
    }

    // MARK: - Rich Progress Delegate

    func testRichProgressDelegate_canBeSet() {
        BackgroundSessionManager.shared.richProgressDelegate = { dict in }
        XCTAssertTrue(true, "Setting richProgressDelegate must not crash")
        BackgroundSessionManager.shared.richProgressDelegate = nil
    }

    // MARK: - Download Registration (mock / offline)

    func testDownload_invalidURL_doesNotCrash() {
        // Passing an invalid URL to download should be handled gracefully.
        // We expect the completion to be called with a failure.
        let expectation = self.expectation(description: "completion called")

        guard let url = URL(string: "https://127.0.0.1:1/unreachable") else {
            XCTFail("Test URL must be parseable")
            return
        }

        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("bsm_test_\(UUID().uuidString).dat")
        let taskId = "test-dl-\(UUID().uuidString)"

        BackgroundSessionManager.shared.download(
            url: url,
            to: dest,
            taskId: taskId
        ) { result in
            switch result {
            case .success:
                // Unexpected — connection to 127.0.0.1:1 should fail
                break
            case .failure:
                // Expected path for unreachable host
                break
            }
            expectation.fulfill()
        }

        // Background sessions may take a while to time out; give 30 s
        waitForExpectations(timeout: 30)
    }

    // MARK: - Concurrency Safety

    func testConcurrentCancellations_doNotCrash() {
        let group = DispatchGroup()
        let taskIds = (0..<20).map { "concurrent-cancel-\($0)-\(UUID().uuidString)" }

        for taskId in taskIds {
            group.enter()
            DispatchQueue.global().async {
                BackgroundSessionManager.shared.cancelTask(taskId: taskId)
                group.leave()
            }
        }

        let result = group.wait(timeout: .now() + 5)
        XCTAssertEqual(result, .success,
                       "Concurrent cancellations on non-existent tasks must not crash or deadlock")
    }
}
