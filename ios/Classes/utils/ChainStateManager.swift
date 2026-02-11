import Foundation

/// Manages persistence and recovery of task chain state on iOS.
///
/// Allows chains to resume after app kills or crashes by saving progress
/// after each step completion.
///
/// **Storage:** UserDefaults (lightweight, suitable for chain metadata)
/// **Cleanup:** Auto-removes chains completed > 7 days ago
actor ChainStateManager {

    // MARK: - Constants

    private static let userDefaultsKey = "com.brewkits.native_workmanager.chain_states"
    private static let maxStateAge: TimeInterval = 7 * 24 * 60 * 60 // 7 days

    // MARK: - Models

    /// Represents a saved chain state
    struct ChainState: Codable {
        let chainId: String
        let chainName: String?
        let totalSteps: Int
        var currentStep: Int  // 0-indexed
        var completed: Bool
        let createdAt: Date
        var lastUpdatedAt: Date
        let steps: [[TaskData]]  // All steps with their tasks

        struct TaskData: Codable {
            let taskId: String
            let workerClassName: String
            let workerConfig: [String: AnyCodable]  // JSON-compatible config
            var completed: Bool
        }

        var progress: Double {
            guard totalSteps > 0 else { return 0 }
            return Double(currentStep) / Double(totalSteps)
        }

        var canResume: Bool {
            !completed && currentStep < totalSteps
        }
    }

    /// Type-erased Codable wrapper for Any values
    struct AnyCodable: Codable {
        let value: Any

        init(_ value: Any) {
            self.value = value
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()

            if let bool = try? container.decode(Bool.self) {
                value = bool
            } else if let int = try? container.decode(Int.self) {
                value = int
            } else if let double = try? container.decode(Double.self) {
                value = double
            } else if let string = try? container.decode(String.self) {
                value = string
            } else if let array = try? container.decode([AnyCodable].self) {
                value = array.map { $0.value }
            } else if let dict = try? container.decode([String: AnyCodable].self) {
                value = dict.mapValues { $0.value }
            } else {
                value = NSNull()
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()

            switch value {
            case let bool as Bool:
                try container.encode(bool)
            case let int as Int:
                try container.encode(int)
            case let double as Double:
                try container.encode(double)
            case let string as String:
                try container.encode(string)
            case let array as [Any]:
                try container.encode(array.map { AnyCodable($0) })
            case let dict as [String: Any]:
                try container.encode(dict.mapValues { AnyCodable($0) })
            default:
                try container.encodeNil()
            }
        }
    }

    // MARK: - Storage

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Save/Load

    /// Save chain state to UserDefaults
    func saveChainState(_ state: ChainState) throws {
        print("ChainStateManager: Saving state for chain '\(state.chainId)'")
        print("  Progress: \(state.currentStep + 1)/\(state.totalSteps) steps")

        var states = try loadAllStates()

        // Update or add state
        if let index = states.firstIndex(where: { $0.chainId == state.chainId }) {
            states[index] = state
        } else {
            states.append(state)
        }

        // Encode and save
        let data = try JSONEncoder().encode(states)
        defaults.set(data, forKey: Self.userDefaultsKey)
        defaults.synchronize()

        print("ChainStateManager: Saved successfully")
    }

    /// Load chain state by ID
    func loadChainState(chainId: String) throws -> ChainState? {
        let states = try loadAllStates()
        return states.first { $0.chainId == chainId }
    }

    /// Load all saved chain states
    func loadAllStates() throws -> [ChainState] {
        guard let data = defaults.data(forKey: Self.userDefaultsKey) else {
            return []
        }

        do {
            let states = try JSONDecoder().decode([ChainState].self, from: data)
            return states
        } catch {
            print("ChainStateManager: Error decoding states: \(error)")
            // Corrupted data - clear it
            defaults.removeObject(forKey: Self.userDefaultsKey)
            return []
        }
    }

    /// Load all resumable chains (not completed, not expired)
    func loadResumableChains() throws -> [ChainState] {
        let allStates = try loadAllStates()
        let cutoffDate = Date().addingTimeInterval(-Self.maxStateAge)

        return allStates.filter { state in
            state.canResume && state.lastUpdatedAt > cutoffDate
        }
    }

    // MARK: - Update

    /// Mark current step as completed and advance to next step
    func advanceToNextStep(chainId: String) throws {
        guard var state = try loadChainState(chainId: chainId) else {
            print("ChainStateManager: Chain '\(chainId)' not found")
            return
        }

        print("ChainStateManager: Advancing chain '\(chainId)'")
        print("  From step: \(state.currentStep + 1)/\(state.totalSteps)")

        state.currentStep += 1
        state.lastUpdatedAt = Date()

        if state.currentStep >= state.totalSteps {
            state.completed = true
            print("  Chain completed!")
        } else {
            print("  To step: \(state.currentStep + 1)/\(state.totalSteps)")
        }

        try saveChainState(state)
    }

    /// Mark chain as completed
    func markChainCompleted(chainId: String) throws {
        guard var state = try loadChainState(chainId: chainId) else {
            return
        }

        print("ChainStateManager: Marking chain '\(chainId)' as completed")
        state.completed = true
        state.lastUpdatedAt = Date()
        try saveChainState(state)
    }

    /// Mark chain as failed
    func markChainFailed(chainId: String) throws {
        print("ChainStateManager: Removing failed chain '\(chainId)'")
        try removeChainState(chainId: chainId)
    }

    // MARK: - Remove/Clean

    /// Remove specific chain state
    func removeChainState(chainId: String) throws {
        print("ChainStateManager: Removing chain '\(chainId)'")

        var states = try loadAllStates()
        states.removeAll { $0.chainId == chainId }

        if states.isEmpty {
            defaults.removeObject(forKey: Self.userDefaultsKey)
        } else {
            let data = try JSONEncoder().encode(states)
            defaults.set(data, forKey: Self.userDefaultsKey)
        }

        defaults.synchronize()
    }

    /// Remove all completed or expired chains
    func cleanupOldStates() throws {
        print("ChainStateManager: Cleaning up old states...")

        let allStates = try loadAllStates()
        let cutoffDate = Date().addingTimeInterval(-Self.maxStateAge)

        let activeStates = allStates.filter { state in
            !state.completed && state.lastUpdatedAt > cutoffDate
        }

        let removedCount = allStates.count - activeStates.count

        if removedCount > 0 {
            print("ChainStateManager: Removed \(removedCount) old chain(s)")

            if activeStates.isEmpty {
                defaults.removeObject(forKey: Self.userDefaultsKey)
            } else {
                let data = try JSONEncoder().encode(activeStates)
                defaults.set(data, forKey: Self.userDefaultsKey)
            }

            defaults.synchronize()
        } else {
            print("ChainStateManager: No cleanup needed")
        }
    }

    /// Remove ALL chain states (use for testing/debugging only)
    func clearAllStates() {
        print("ChainStateManager: Clearing ALL chain states")
        defaults.removeObject(forKey: Self.userDefaultsKey)
        defaults.synchronize()
    }

    // MARK: - Helpers

    /// Create initial chain state from chain configuration
    static func createInitialState(
        chainId: String,
        chainName: String?,
        stepsData: [[Any]]
    ) throws -> ChainState {
        var steps: [[ChainState.TaskData]] = []

        for stepData in stepsData {
            guard let stepTasks = stepData as? [[String: Any]] else {
                throw NSError(domain: "ChainStateManager", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Invalid step format"])
            }

            var tasks: [ChainState.TaskData] = []

            for taskData in stepTasks {
                guard let taskId = taskData["id"] as? String,
                      let workerClassName = taskData["workerClassName"] as? String,
                      let workerConfig = taskData["workerConfig"] as? [String: Any] else {
                    continue
                }

                let task = ChainState.TaskData(
                    taskId: taskId,
                    workerClassName: workerClassName,
                    workerConfig: workerConfig.mapValues { AnyCodable($0) },
                    completed: false
                )
                tasks.append(task)
            }

            steps.append(tasks)
        }

        return ChainState(
            chainId: chainId,
            chainName: chainName,
            totalSteps: steps.count,
            currentStep: 0,
            completed: false,
            createdAt: Date(),
            lastUpdatedAt: Date(),
            steps: steps
        )
    }
}
