import Foundation

/// Manages persistence and recovery of task chain state on iOS.
///
/// Allows chains to resume after app kills or crashes by saving progress
/// after each step completion.
///
/// **Storage:** SQLite via ChainStore (primary).
///   UserDefaults is no longer used for new data; the one-time migration on
///   first launch moves any legacy records to SQLite and clears the old key.
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
        var stepResults: [[String: AnyCodable]?]  // Output data from each completed step (v1.0.0+)

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

    private let chainStore: ChainStore
    private let defaults: UserDefaults

    init(chainStore: ChainStore, defaults: UserDefaults = .standard) {
        self.chainStore = chainStore
        self.defaults = defaults
        
        // One-time migration from UserDefaults to SQLite
        Task {
            await migrateFromUserDefaults()
        }
    }

    private func migrateFromUserDefaults() async {
        guard let data = defaults.data(forKey: Self.userDefaultsKey) else { return }
        print("ChainStateManager: Found legacy data in UserDefaults. Migrating to SQLite...")
        
        do {
            let states = try JSONDecoder().decode([ChainState].self, from: data)
            for state in states {
                let stateData = try JSONEncoder().encode(state)
                if let stateJson = String(data: stateData, encoding: .utf8) {
                    chainStore.upsertChain(
                        id: state.chainId,
                        name: state.chainName,
                        totalSteps: state.totalSteps,
                        currentStep: state.currentStep,
                        isCompleted: state.completed,
                        stateJson: stateJson
                    )
                }
            }
            // Clear legacy data after successful migration
            defaults.removeObject(forKey: Self.userDefaultsKey)
            defaults.synchronize()
            print("ChainStateManager: Migration complete (\(states.count) chains)")
        } catch {
            print("ChainStateManager: Migration failed: \(error)")
        }
    }

    // MARK: - Save/Load

    /// Save chain state to SQLite
    func saveChainState(_ state: ChainState) throws {
        print("ChainStateManager: Saving state for chain '\(state.chainId)' to SQLite")
        print("  Progress: \(state.currentStep + 1)/\(state.totalSteps) steps")

        let stateData = try JSONEncoder().encode(state)
        guard let stateJson = String(data: stateData, encoding: .utf8) else {
            throw NSError(domain: "ChainStateManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode state"])
        }

        chainStore.upsertChain(
            id: state.chainId,
            name: state.chainName,
            totalSteps: state.totalSteps,
            currentStep: state.currentStep,
            isCompleted: state.completed,
            stateJson: stateJson
        )

        print("ChainStateManager: Saved successfully to SQLite")
    }

    /// Load chain state by ID
    func loadChainState(chainId: String) throws -> ChainState? {
        guard let row = chainStore.getChain(id: chainId),
              let json = row["full_state_json"] as? String,
              let data = json.data(using: .utf8) else {
            return nil
        }
        return try JSONDecoder().decode(ChainState.self, from: data)
    }

    /// Load all saved chain states
    func loadAllStates() throws -> [ChainState] {
        let rows = chainStore.getAllChains()
        var states: [ChainState] = []
        
        for row in rows {
            if let json = row["full_state_json"] as? String,
               let data = json.data(using: .utf8) {
                if let state = try? JSONDecoder().decode(ChainState.self, from: data) {
                    states.append(state)
                }
            }
        }
        return states
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

    /// Save result data from a completed step
    func saveStepResult(chainId: String, stepIndex: Int, resultData: [String: Any]?) throws {
        guard var state = try loadChainState(chainId: chainId) else {
            print("ChainStateManager: Chain '\(chainId)' not found")
            return
        }

        guard stepIndex >= 0 && stepIndex < state.totalSteps else {
            print("ChainStateManager: Invalid step index \(stepIndex)")
            return
        }

        // Store result data (convert to AnyCodable)
        if let resultData = resultData {
            state.stepResults[stepIndex] = resultData.mapValues { AnyCodable($0) }
            print("ChainStateManager: Saved result data for step \(stepIndex + 1) (\(resultData.count) keys)")
        } else {
            state.stepResults[stepIndex] = nil
            print("ChainStateManager: No result data for step \(stepIndex + 1)")
        }

        state.lastUpdatedAt = Date()
        try saveChainState(state)
    }

    /// Get result data from previous step (for data flow between steps)
    func getPreviousStepResult(chainId: String, currentStepIndex: Int) throws -> [String: Any]? {
        guard let state = try loadChainState(chainId: chainId) else {
            return nil
        }

        // If first step or invalid index, no previous result
        guard currentStepIndex > 0 && currentStepIndex <= state.totalSteps else {
            return nil
        }

        let previousIndex = currentStepIndex - 1
        guard previousIndex < state.stepResults.count else {
            return nil
        }

        // Convert AnyCodable back to [String: Any]
        if let result = state.stepResults[previousIndex] {
            return result.mapValues { $0.value }
        }

        return nil
    }

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
        print("ChainStateManager: Removing chain '\(chainId)' from SQLite")
        chainStore.deleteChain(id: chainId)
    }

    /// Remove all completed or expired chains
    func cleanupOldStates() throws {
        print("ChainStateManager: Cleaning up old states in SQLite...")
        let cutoffDate = Date().addingTimeInterval(-Self.maxStateAge)
        chainStore.cleanup(olderThan: cutoffDate)
    }

    /// Remove ALL chain states (use for testing/debugging only)
    func clearAllStates() {
        print("ChainStateManager: Clearing ALL chain states in SQLite")
        let states = (try? loadAllStates()) ?? []
        for state in states {
            chainStore.deleteChain(id: state.chainId)
        }
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
            steps: steps,
            stepResults: Array(repeating: nil, count: steps.count)  // Initialize with nil
        )
    }
}
