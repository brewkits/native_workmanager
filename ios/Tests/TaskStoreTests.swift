import XCTest
@testable import native_workmanager

final class TaskStoreTests: XCTestCase {
    
    var taskStore: TaskStore!
    let dbName = "test_tasks"
    
    override func setUp() {
        super.setUp()
        // Use a fresh test database for each run
        taskStore = TaskStore(name: dbName)
    }
    
    override func tearDown() {
        // Cleanup: remove test DB files
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let storeDir = appSupport.appendingPathComponent("native_workmanager", isDirectory: true)
        let dbPath = storeDir.appendingPathComponent("\(dbName).sqlite").path
        try? fileManager.removeItem(atPath: dbPath)
        try? fileManager.removeItem(atPath: dbPath + "-wal")
        try? fileManager.removeItem(atPath: dbPath + "-shm")
        super.tearDown()
    }
    
    // MARK: - Task Tests
    
    func testUpsertAndRetrieveTask() {
        let taskId = "test-task-1"
        let tag = "group-1"
        let workerClass = "HttpDownloadWorker"
        let config = "{\"url\":\"https://example.com\"}"
        
        taskStore.upsert(
            taskId: taskId,
            tag: tag,
            status: "pending",
            workerClassName: workerClass,
            workerConfig: config
        )
        
        let record = taskStore.task(taskId: taskId)
        XCTAssertNotNil(record)
        XCTAssertEqual(record?.taskId, taskId)
        XCTAssertEqual(record?.tag, tag)
        XCTAssertEqual(record?.status, "pending")
        XCTAssertEqual(record?.workerClassName, workerClass)
        XCTAssertEqual(record?.workerConfig, config)
    }
    
    func testUpdateStatus() {
        let taskId = "test-update-status"
        taskStore.upsert(taskId: taskId, tag: nil, status: "pending", workerClassName: "Worker", workerConfig: nil)
        
        taskStore.updateStatus(taskId: taskId, status: "success", resultData: "{\"done\":true}", errorMessage: nil)
        
        let record = taskStore.task(taskId: taskId)
        XCTAssertEqual(record?.status, "success")
        XCTAssertEqual(record?.resultData, "{\"done\":true}")
        XCTAssertNil(record?.errorMessage)
    }
    
    // MARK: - Background Registry Tests
    
    func testRegisterAndRetrieveBackgroundDownload() {
        let taskId = "bg-task-1"
        let url = "https://example.com/file.zip"
        let dest = "/tmp/file.zip"
        
        taskStore.registerBackgroundDownload(taskId: taskId, url: url, destinationPath: dest)
        
        let registry = taskStore.getRegistryByUrl(url: url)
        XCTAssertNotNil(registry)
        XCTAssertEqual(registry?["task_id"] as? String, taskId)
        XCTAssertEqual(registry?["destination_path"] as? String, dest)
        
        let registryById = taskStore.getRegistryByTaskId(taskId: taskId)
        XCTAssertNotNil(registryById)
        XCTAssertEqual(registryById?["url_string"] as? String, url)
    }
    
    func testUpdateResumeData() {
        let taskId = "resume-task-1"
        taskStore.registerBackgroundDownload(taskId: taskId, url: "url", destinationPath: "dest")
        
        let testData = "some-resume-data".data(using: .utf8)!
        taskStore.updateResumeData(taskId: taskId, data: testData)
        
        let registry = taskStore.getRegistryByTaskId(taskId: taskId)
        XCTAssertEqual(registry?["resume_data"] as? Data, testData)
        
        // Test clearing resume data
        taskStore.updateResumeData(taskId: taskId, data: nil)
        let clearedRegistry = taskStore.getRegistryByTaskId(taskId: taskId)
        XCTAssertNil(clearedRegistry?["resume_data"] as? Data)
    }
    
    // MARK: - Migration Tests
    
    func testMigrationFromUserDefaults() {
        let defaults = UserDefaults.standard
        let destKey = "NativeWorkManager.BGSession.destinations"
        let urlKey = "NativeWorkManager.BGSession.urls"
        
        let taskId = "legacy-task-123"
        let url = "https://legacy.com/data"
        let dest = "/legacy/path"
        
        // Mock legacy data in UserDefaults
        defaults.set([taskId: dest], forKey: destKey)
        defaults.set([url: taskId], forKey: urlKey)
        
        // Trigger setup which calls migrateFromUserDefaults
        let freshStore = TaskStore(name: "test_migration")
        
        // Verify SQLite now has the data
        let registry = freshStore.getRegistryByTaskId(taskId: taskId)
        XCTAssertNotNil(registry)
        XCTAssertEqual(registry?["url_string"] as? String, url)
        XCTAssertEqual(registry?["destination_path"] as? String, dest)
        
        // Verify UserDefaults is cleaned up
        XCTAssertNil(defaults.object(forKey: destKey))
        XCTAssertNil(defaults.object(forKey: urlKey))
        
        // Cleanup
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let storeDir = appSupport.appendingPathComponent("native_workmanager", isDirectory: true)
        let dbPath = storeDir.appendingPathComponent("test_migration.sqlite").path
        try? fileManager.removeItem(atPath: dbPath)
    }
}
