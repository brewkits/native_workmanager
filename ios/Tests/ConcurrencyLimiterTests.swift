import XCTest
@testable import native_workmanager

final class ConcurrencyLimiterTests: XCTestCase {
    private actor Counter {
        var running = 0
        var peak = 0
        func enter() { running += 1; peak = max(peak, running) }
        func leave() { running -= 1 }
    }

    func test_issue_84_caps_suspended_workers() async throws {
        for limit in [1, 2, 4] {
            let limiter = ConcurrencyLimiter(max: limit)
            let counter = Counter()
            try await withThrowingTaskGroup(of: Void.self) { group in
                for _ in 0..<20 {
                    group.addTask {
                        try await limiter.acquire()
                        await counter.enter()
                        try await Task.sleep(nanoseconds: 10_000_000)
                        await counter.leave()
                        await limiter.release()
                    }
                }
                try await group.waitForAll()
            }
            let peak = await counter.peak
            XCTAssertEqual(peak, limit)
        }
    }

    func test_issue_84_cancelled_waiter_finishes_without_a_free_slot() async throws {
        let limiter = ConcurrencyLimiter(max: 1)
        try await limiter.acquire()
        let cancelled = expectation(description: "queued task cancelled promptly")
        let waiter = Task {
            do {
                try await limiter.acquire()
                XCTFail("cancelled worker must not start")
                await limiter.release()
            } catch is CancellationError { cancelled.fulfill() }
            catch { XCTFail("Unexpected error: \(error)") }
        }
        try await Task.sleep(nanoseconds: 10_000_000)
        waiter.cancel()
        await fulfillment(of: [cancelled], timeout: 1)
        await limiter.release()
        try await limiter.acquire()
        await limiter.release()
    }

    func test_issue_84_resize_keeps_existing_permits() async throws {
        let limiter = ConcurrencyLimiter(max: 2)
        try await limiter.acquire()
        try await limiter.acquire()
        await limiter.configure(max: 1)
        let counter = Counter()
        let waiter = Task {
            try await limiter.acquire()
            await counter.enter()
            await limiter.release()
        }
        await limiter.release()
        try await Task.sleep(nanoseconds: 20_000_000)
        let peak = await counter.peak
        XCTAssertEqual(peak, 0)
        // Increasing the limit must wake the waiter even without a release.
        await limiter.configure(max: 2)
        try await waiter.value
        await limiter.release()
        let finalPeak = await counter.peak
        XCTAssertEqual(finalPeak, 1)
    }
}
