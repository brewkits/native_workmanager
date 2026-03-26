import Foundation

/// Thread-safe task registry backed by Swift's structured concurrency Actor model.
///
/// Replaces the `DispatchQueue + [String: Task]` pattern used previously.
/// An actor serialises all access automatically — no manual barrier flags needed,
/// and the Swift compiler enforces correct usage at compile time.
///
/// ## Solved problems
/// - **Zombie handle race**: the old pattern could leave a dead `Task` handle in
///   `activeTasks` when the task body finished before `stateQueue.sync` ran.
///   With an actor the `store` and `remove` calls are serialised; the `remove`
///   in `defer` always sees the stored handle and removes the correct entry.
/// - **Barrier mis-use**: `async(flags: .barrier)` on a concurrent queue is
///   easy to call from the wrong context. Actor isolation is enforced by the
///   compiler — calling `await actor.store(...)` is the only correct path.
///
/// ## Usage
/// ```swift
/// let taskActor = TaskActor()
///
/// // Store handle
/// await taskActor.store(taskId: id, handle: taskHandle)
///
/// // Cancel and remove
/// await taskActor.cancel(taskId: id)
///
/// // Remove without cancelling (when task finishes normally)
/// await taskActor.remove(taskId: id)
///
/// // Inspect
/// let ids = await taskActor.activeTaskIds
/// ```
@available(iOS 13.0, *)
actor TaskActor {

    // MARK: - Storage

    private var handles: [String: Task<Void, Never>] = [:]
    private var states: [String: String] = [:]
    private var tags: [String: String] = [:]
    private var notifTitles: [String: String] = [:]
    private var allowPause: [String: Bool] = [:]
    private var startTimes: [String: Date] = [:]

    // MARK: - Handles

    /// Store an active task handle for later cancellation.
    func store(taskId: String, handle: Task<Void, Never>) {
        handles[taskId] = handle
    }

    /// Cancel and remove a task handle. Calling `.cancel()` on an already-finished
    /// Task is a safe no-op — the actor guarantees the handle was stored before
    /// this is called (unlike the previous barrier-queue pattern).
    func cancel(taskId: String) {
        handles[taskId]?.cancel()
        handles.removeValue(forKey: taskId)
    }

    /// Remove a handle without cancelling (e.g., called from the task's `defer`).
    func remove(taskId: String) {
        handles.removeValue(forKey: taskId)
    }

    /// Cancel all active task handles.
    func cancelAll() {
        for (_, handle) in handles { handle.cancel() }
        handles.removeAll()
    }

    /// IDs of tasks currently stored in the actor.
    var activeTaskIds: [String] { Array(handles.keys) }

    // MARK: - States

    func setState(_ state: String, forTaskId taskId: String) {
        states[taskId] = state
    }

    func state(forTaskId taskId: String) -> String? {
        states[taskId]
    }

    func removeState(forTaskId taskId: String) {
        states.removeValue(forKey: taskId)
    }

    func removeAllStates() {
        states.removeAll()
    }

    // MARK: - Tags

    func setTag(_ tag: String, forTaskId taskId: String) {
        tags[taskId] = tag
    }

    func tag(forTaskId taskId: String) -> String? {
        tags[taskId]
    }

    func taskIds(forTag tag: String) -> [String] {
        tags.filter { $0.value == tag }.map(\.key)
    }

    func allTags() -> [String] {
        Array(Set(tags.values))
    }

    func removeTag(forTaskId taskId: String) {
        tags.removeValue(forKey: taskId)
    }

    func removeAllTags() {
        tags.removeAll()
    }

    // MARK: - Notification metadata

    func setNotifTitle(_ title: String, forTaskId taskId: String) {
        notifTitles[taskId] = title
    }

    func notifTitle(forTaskId taskId: String) -> String? {
        notifTitles[taskId]
    }

    func removeNotifTitle(forTaskId taskId: String) {
        notifTitles.removeValue(forKey: taskId)
    }

    func removeAllNotifTitles() {
        notifTitles.removeAll()
    }

    func setAllowPause(_ value: Bool, forTaskId taskId: String) {
        allowPause[taskId] = value
    }

    func allowsPause(forTaskId taskId: String) -> Bool {
        allowPause[taskId] ?? true
    }

    func removeAllowPause(forTaskId taskId: String) {
        allowPause.removeValue(forKey: taskId)
    }

    func removeAllAllowPause() {
        allowPause.removeAll()
    }

    // MARK: - Start times (debug mode)

    func setStartTime(_ date: Date, forTaskId taskId: String) {
        startTimes[taskId] = date
    }

    func startTime(forTaskId taskId: String) -> Date? {
        startTimes[taskId]
    }

    func removeStartTime(forTaskId taskId: String) {
        startTimes.removeValue(forKey: taskId)
    }

    // MARK: - Bulk clear (cancelAll)

    func clearAll() {
        for (_, handle) in handles { handle.cancel() }
        handles.removeAll()
        states.removeAll()
        tags.removeAll()
        notifTitles.removeAll()
        allowPause.removeAll()
    }
}
