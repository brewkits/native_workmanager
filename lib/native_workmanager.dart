/// Native background task manager for Flutter.
///
/// Zero Flutter Engine overhead. Built on Kotlin Multiplatform.
///
/// ## Quick Start
///
/// ```dart
/// import 'package:native_workmanager/native_workmanager.dart';
///
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await NativeWorkManager.initialize();
///   runApp(MyApp());
/// }
///
/// // Schedule a periodic sync
/// await NativeWorkManager.enqueue(
///   taskId: 'sync',
///   trigger: TaskTrigger.periodic(Duration(hours: 1)),
///   worker: NativeWorker.httpSync(url: 'https://api.example.com/sync'),
///   constraints: Constraints.networkRequired,
/// );
/// ```
///
/// ## Features
///
/// - **Native Workers**: Run background tasks without Flutter Engine (~2MB vs ~50MB RAM)
/// - **Task Chains**: Complex workflows (A → B → C)
/// - **Auto iOS Config**: Reads Info.plist automatically
/// - **Built-in Workers**: HTTP (request, upload, download, sync), Files (compress, decompress),
///   Image processing, Cryptography (hash, encrypt, decrypt)
///
/// See [NativeWorkManager] for full documentation.
library;

export 'src/constraints.dart';
export 'src/events.dart';
export 'src/native_work_manager.dart';
export 'src/performance/performance_monitor.dart';
export 'src/task_chain.dart';
export 'src/task_trigger.dart';
export 'src/worker.dart';
