import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:native_workmanager_gen/builder.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';

/// Tests for [WorkerCallbackGenerator] via the [workerCallbackBuilder]
/// SharedPartBuilder.
///
/// Output lands at the `.worker_callback.g.part` extension (SharedPartBuilder's
/// raw part-file convention) rather than `.g.dart` — the combining builder that
/// merges part files into the final `.g.dart` runs as a separate build step not
/// exercised here.
///
/// The generator's `TypeChecker.fromUrl(...)` matches annotations by exact
/// declaring-library URI (`package:native_workmanager/src/worker_callback_generator_annotation.dart#WorkerCallback`),
/// not just by class name — so a `class WorkerCallback` declared inline in a
/// test fixture's own library does NOT match, and the generator silently finds
/// zero annotated elements (no error, no output). We instead provide a
/// *virtual* `native_workmanager` package asset at that exact path so
/// `import 'package:native_workmanager/src/worker_callback_generator_annotation.dart'`
/// resolves to a real, matching library within the test's in-memory filesystem.
///
/// This also sidesteps a real dependency-resolution trap: adding the actual
/// `native_workmanager` (a Flutter package) as a test dependency here pulls in
/// the Flutter SDK's pinned `meta` version, which forces `analyzer` down below
/// the version the generator's own code targets (`TopLevelFunctionElement`,
/// an analyzer 12.x API) and breaks constant-value resolution entirely.
void main() {
  Builder builder() => workerCallbackBuilder(BuilderOptions.empty);

  const _annotationSource = '''
class WorkerCallback {
  final String id;
  final Type? inputType;
  const WorkerCallback(this.id, {this.inputType});
}
''';

  const _import =
      "import 'package:native_workmanager/src/worker_callback_generator_annotation.dart';";

  /// Builds the asset map for a `lib/workers.dart` source, plus the virtual
  /// `native_workmanager` annotation package every fixture imports.
  Map<String, String> assets(String workersSource) => {
    'native_workmanager|lib/src/worker_callback_generator_annotation.dart':
        _annotationSource,
    'a|lib/workers.dart': '$_import\n\n$workersSource',
  };

  const outputAsset = 'a|lib/workers.worker_callback.g.part';

  test('generates a WorkerIds constant for a single callback', () async {
    await testBuilder(
      builder(),
      assets('''
@WorkerCallback('sync_contacts')
Future<bool> syncContacts(Map<String, dynamic>? input) async => true;
'''),
      outputs: {
        outputAsset: decodedMatches(
          allOf(
            contains('abstract final class WorkerIds'),
            contains("static const String syncContacts = 'sync_contacts';"),
            contains('generatedWorkerRegistry'),
            contains("'sync_contacts': (input) => syncContacts(input"),
          ),
        ),
      },
    );
  });

  test('generates constants for multiple callbacks', () async {
    await testBuilder(
      builder(),
      assets('''
@WorkerCallback('sync_contacts')
Future<bool> syncContacts(Map<String, dynamic>? input) async => true;

@WorkerCallback('backup_photos')
Future<bool> backupPhotos(Map<String, dynamic>? input) async => true;
'''),
      outputs: {
        outputAsset: decodedMatches(
          allOf(
            contains("static const String syncContacts = 'sync_contacts';"),
            contains("static const String backupPhotos = 'backup_photos';"),
            contains("'sync_contacts': (input) => syncContacts(input"),
            contains("'backup_photos': (input) => backupPhotos(input"),
          ),
        ),
      },
    );
  });

  group('camelCase ID conversion', () {
    Future<String> generateFor(String id) async {
      String? captured;
      await testBuilder(
        builder(),
        assets('''
@WorkerCallback('$id')
Future<bool> myCallback(Map<String, dynamic>? input) async => true;
'''),
        outputs: {
          outputAsset: decodedMatches(
            predicate<String>((content) {
              captured = content;
              return true;
            }),
          ),
        },
      );
      return captured!;
    }

    test('snake_case id becomes lowerCamelCase field', () async {
      final content = await generateFor('sync_contacts_now');
      expect(content, contains('syncContactsNow'));
    });

    test('kebab-case id becomes lowerCamelCase field', () async {
      final content = await generateFor('backup-photos-now');
      expect(content, contains('backupPhotosNow'));
    });

    test('already-camelCase id is left as the field name', () async {
      final content = await generateFor('myWorker');
      expect(content, contains('static const String myWorker'));
    });
  });

  test('no annotated functions produces no output', () async {
    await testBuilder(
      builder(),
      assets('''
Future<bool> notAnnotated(Map<String, dynamic>? input) async => true;
'''),
      outputs: {},
    );
  });

  group('typed input generates an enqueue wrapper', () {
    test('wrapper calls NativeWorkManager.enqueue with a DartWorker', () async {
      await testBuilder(
        builder(),
        assets('''
class SyncInput {
  const SyncInput(this.userId);
  final String userId;
  Map<String, dynamic> toMap() => {'userId': userId};
}

@WorkerCallback('sync_contacts', inputType: SyncInput)
Future<bool> syncContacts(Map<String, dynamic>? input) async => true;
'''),
        outputs: {
          outputAsset: decodedMatches(
            allOf(
              contains('Future<TaskHandler> enqueueSyncContacts('),
              contains('SyncInput input'),
              contains('NativeWorkManager.enqueue('),
              contains("callbackId: 'sync_contacts'"),
            ),
          ),
        },
      );
    });

    test('untyped callback (no inputType) gets no enqueue wrapper', () async {
      await testBuilder(
        builder(),
        assets('''
@WorkerCallback('sync_contacts')
Future<bool> syncContacts(Map<String, dynamic>? input) async => true;
'''),
        outputs: {
          outputAsset: decodedMatches(isNot(contains('Future<TaskHandler>'))),
        },
      );
    });
  });

  // source_gen's SharedPartBuilder catches Generator.generate() errors and
  // reports them as a SEVERE build log record rather than rejecting the
  // builder's Future — testBuilder() resolves normally with zero outputs.
  // So these assert against the captured log, not a thrown exception, and
  // additionally confirm no output asset was written.
  group('validation errors', () {
    Future<void> expectRejected(
      String workersSource, {
      required String messageContains,
    }) async {
      final logs = <String>[];
      await testBuilder(
        builder(),
        assets(workersSource),
        outputs: {},
        onLog: (record) => logs.add(record.message),
      );
      expect(
        logs,
        anyElement(contains(messageContains)),
        reason:
            'Expected a SEVERE log containing "$messageContains", '
            'got: $logs',
      );
    }

    // NOTE: the generator's "must be a top-level function" ElementKind check
    // (worker_callback_generator.dart's `element.kind != ElementKind.FUNCTION`
    // branch) is unreachable through the normal build pipeline: source_gen's
    // `LibraryReader.annotatedWith()` only scans `[library, ...library.children]`
    // — a library's direct children are its top-level declarations only, so an
    // annotation on a method nested inside a class is never yielded to the
    // generator's loop in the first place. Annotating an instance method is
    // therefore silently ignored (no error, no output) rather than rejected
    // with the intended error message — documented here as current behavior,
    // not asserting the unreachable rejection path.
    test('silently ignores an instance method (not top-level)', () async {
      await testBuilder(
        builder(),
        assets('''
class Foo {
  @WorkerCallback('bad')
  Future<bool> notTopLevel(Map<String, dynamic>? input) async => true;
}
'''),
        outputs: {},
      );
    });

    test('rejects a non-Future<bool> return type', () async {
      await expectRejected('''
@WorkerCallback('bad')
Future<void> wrongReturn(Map<String, dynamic>? input) async {}
''', messageContains: 'Future<bool>');
    });

    test('rejects a function with zero parameters', () async {
      await expectRejected('''
@WorkerCallback('bad')
Future<bool> noParams() async => true;
''', messageContains: 'no parameters');
    });

    test('rejects a function with more than one parameter', () async {
      await expectRejected('''
@WorkerCallback('bad')
Future<bool> twoParams(Map<String, dynamic>? input, String extra) async => true;
''', messageContains: 'has 2 parameters');
    });

    test(
      'rejects a parameter type that is not Map<String, dynamic>?',
      () async {
        await expectRejected('''
@WorkerCallback('bad')
Future<bool> wrongParamType(String? input) async => true;
''', messageContains: 'Map<String, dynamic>?');
      },
    );

    test('rejects an empty id', () async {
      await expectRejected('''
@WorkerCallback('')
Future<bool> emptyId(Map<String, dynamic>? input) async => true;
''', messageContains: 'cannot be empty');
    });

    test('rejects duplicate ids within the same library', () async {
      await expectRejected('''
@WorkerCallback('dup')
Future<bool> first(Map<String, dynamic>? input) async => true;

@WorkerCallback('dup')
Future<bool> second(Map<String, dynamic>? input) async => true;
''', messageContains: 'already used');
    });
  });
}
