import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

/// Generates type-safe worker IDs and a registry map from [@WorkerCallback]
/// annotations.
///
/// For a source file `lib/workers.dart`:
/// ```dart
/// part 'workers.g.dart';
///
/// @WorkerCallback('sync_contacts')
/// Future<bool> syncContacts(Map<String, dynamic>? input) async => true;
///
/// @WorkerCallback('backup_photos')
/// Future<bool> backupPhotos(Map<String, dynamic>? input) async => true;
/// ```
///
/// Generates `lib/workers.g.dart`:
/// ```dart
/// // GENERATED CODE - DO NOT MODIFY BY HAND
/// part of 'workers.dart';
///
/// abstract final class WorkerIds {
///   static const String syncContacts = 'sync_contacts';
///   static const String backupPhotos = 'backup_photos';
/// }
///
/// final Map<String, DartWorkerCallback> generatedWorkerRegistry = {
///   'sync_contacts': syncContacts,
///   'backup_photos': backupPhotos,
/// };
/// ```
class WorkerCallbackGenerator extends Generator {
  /// Creates a [WorkerCallbackGenerator].
  ///
  /// Registered automatically by [workerCallbackBuilder] — do not instantiate
  /// directly in application code.
  const WorkerCallbackGenerator();

  // Use fromUrl instead of fromRuntime to avoid dart:mirrors dependency.
  // This makes the package compatible with all platforms and source_gen >=2.0.
  static final _checker = TypeChecker.fromUrl(
    'package:native_workmanager/src/worker_callback_generator_annotation.dart'
    '#WorkerCallback',
  );

  @override
  Future<String> generate(LibraryReader library, BuildStep buildStep) async {
    final workers = <_WorkerEntry>[];

    for (final annotatedElement in library.annotatedWith(_checker)) {
      final element = annotatedElement.element;
      final annotation = annotatedElement.annotation;

      // ── Validate: must be a top-level function ──────────────────────────
      // Use ElementKind.FUNCTION instead of `is FunctionElement` because
      // FunctionElement was removed in analyzer 12.x (Dart 3.11+).
      if (element.kind != ElementKind.FUNCTION) {
        throw InvalidGenerationSourceError(
          '@WorkerCallback can only be applied to top-level functions.\n'
          '"${element.displayName}" is a ${element.kind.displayName}.',
          element: element,
          todo: 'Move the function to the top level of the file.',
        );
      }

      // Cast to TopLevelFunctionElement (analyzer 12.x) to access
      // formalParameters and returnType via FunctionTypedElement.
      final fn = element as TopLevelFunctionElement;

      // ── Validate: return type must be Future<bool> ──────────────────────
      final returnType = fn.returnType.toString();
      if (returnType != 'Future<bool>') {
        throw InvalidGenerationSourceError(
          '@WorkerCallback function must return Future<bool>.\n'
          '"${element.displayName}" returns "$returnType".',
          element: element,
          todo: "Change the return type to 'Future<bool>'.",
        );
      }

      // ── Validate: exactly one parameter Map<String, dynamic>? ───────────
      // Zero-parameter functions pass Dart's type-checker but crash at runtime
      // because the native side always calls with an input argument.
      final params = fn.formalParameters;
      if (params.isEmpty) {
        throw InvalidGenerationSourceError(
          '@WorkerCallback function must have exactly one parameter: '
          'Map<String, dynamic>? input\n'
          '"${element.displayName}" has no parameters.\n'
          'A zero-parameter function compiles without error but crashes at '
          'runtime when the native side passes the input argument.',
          element: element,
          todo:
              'Add the parameter: Future<bool> ${element.displayName}(Map<String, dynamic>? input)',
        );
      }
      if (params.length != 1) {
        throw InvalidGenerationSourceError(
          '@WorkerCallback function must have exactly one parameter '
          '(Map<String, dynamic>?).\n'
          '"${element.displayName}" has ${params.length} parameters.',
          element: element,
          todo:
              'Use signature: Future<bool> ${element.displayName}(Map<String, dynamic>? input)',
        );
      }
      final paramType = params.first.type.toString();
      if (!paramType.startsWith('Map<String, dynamic>')) {
        throw InvalidGenerationSourceError(
          '@WorkerCallback parameter must be Map<String, dynamic>?.\n'
          '"${element.displayName}" has parameter type "$paramType".',
          element: element,
          todo: "Change the parameter type to 'Map<String, dynamic>?'.",
        );
      }

      // ── Read annotation ID ──────────────────────────────────────────────
      final String id;
      try {
        id = annotation.read('id').stringValue;
      } catch (e) {
        throw InvalidGenerationSourceError(
          '@WorkerCallback annotation on "${element.displayName}" has a malformed '
          'or missing "id" value: $e',
          element: element,
          todo: "Ensure the annotation is @WorkerCallback('some_id')",
        );
      }

      if (id.isEmpty) {
        throw InvalidGenerationSourceError(
          '@WorkerCallback id cannot be empty.\n'
          'Annotated function: "${element.displayName}".',
          element: element,
          todo: "Provide a non-empty string id: @WorkerCallback('my_worker')",
        );
      }

      // ── M-01 fix: detect duplicate IDs within this library ──────────────
      final duplicate = workers.where((w) => w.id == id).firstOrNull;
      if (duplicate != null) {
        throw InvalidGenerationSourceError(
          "@WorkerCallback id '$id' is already used by '${duplicate.functionName}' "
          'in this library.\n'
          '"${element.displayName}" cannot reuse the same id.',
          element: element,
          todo: 'Each @WorkerCallback must have a unique id.',
        );
      }

      workers.add(
        _WorkerEntry(
          id: id,
          functionName: element.displayName,
          inputTypeName: annotation.read('inputType').isNull
              ? null
              : annotation
                    .read('inputType')
                    .typeValue
                    .getDisplayString(),
        ),
      );
    }

    if (workers.isEmpty) return '';

    final buf = StringBuffer();

    // ── WorkerIds constants class ─────────────────────────────────────────
    buf
      ..writeln('/// Type-safe worker callback ID constants.')
      ..writeln('///')
      ..writeln('/// Generated from [@WorkerCallback] annotations.')
      ..writeln('/// Use these constants instead of raw strings to prevent')
      ..writeln('/// typos and enable IDE rename-refactoring.')
      ..writeln('// ignore_for_file: type=lint')
      ..writeln('abstract final class WorkerIds {');

    for (final w in workers) {
      final fieldName = _toCamelCase(w.id);
      buf
        ..writeln('  /// Callback ID for `${w.functionName}`.')
        ..writeln("  static const String $fieldName = '${w.id}';");
    }
    buf
      ..writeln('}')
      ..writeln();

    // ── Type-safe Wrappers ────────────────────────────────────────────────
    for (final w in workers) {
      if (w.inputTypeName != null) {
        final wrapperName = 'enqueue${_capitalize(w.functionName)}';
        buf
          ..writeln('/// Type-safe enqueue wrapper for `${w.functionName}`.')
          ..writeln('Future<TaskHandler> $wrapperName(')
          ..writeln('  ${w.inputTypeName} input, {')
          ..writeln('  String? taskId,')
          ..writeln('  String? tag,')
          ..writeln('  TaskTrigger trigger = const TaskTrigger.oneTime(),')
          ..writeln('  Constraints constraints = const Constraints(),')
          ..writeln('}) => NativeWorkManager.enqueue(')
          ..writeln('  taskId: taskId,')
          ..writeln('  tag: tag,')
          ..writeln('  trigger: trigger,')
          ..writeln('  constraints: constraints,')
          ..writeln('  worker: DartWorker(')
          ..writeln("    callbackId: '${w.id}',")
          ..writeln(
            '    input: input is Map<String, dynamic> ? input : (input as dynamic).toMap(),',
          )
          ..writeln('  ),')
          ..writeln(');')
          ..writeln();
      }
    }

    // ── generatedWorkerRegistry map ───────────────────────────────────────
    buf
      ..writeln(
        '/// Worker registry generated from [@WorkerCallback] annotations.',
      )
      ..writeln('///')
      ..writeln('/// Pass this map to [NativeWorkManager.initialize]:')
      ..writeln('///')
      ..writeln('/// ```dart')
      ..writeln('/// await NativeWorkManager.initialize(')
      ..writeln('///   dartWorkers: generatedWorkerRegistry,')
      ..writeln('/// );')
      ..writeln('/// ```')
      ..writeln(
        'final Map<String, DartWorkerCallback> generatedWorkerRegistry = {',
      );

    for (final w in workers) {
      buf.writeln(
        "  '${w.id}': (input) => ${w.functionName}(input == null ? null : ${w.inputTypeName == null || w.inputTypeName == 'Map<String, dynamic>' ? 'input' : '(_decode${w.inputTypeName}(input))'}),",
      );
    }
    buf.writeln('};');

    // ── Decode Helpers ──────────────────────────────────────────────────
    for (final w in workers) {
      if (w.inputTypeName != null &&
          w.inputTypeName != 'Map<String, dynamic>') {
        buf
          ..writeln(
            '${w.inputTypeName} _decode${w.inputTypeName}(Map<String, dynamic> input) {',
          )
          ..writeln('  return ${w.inputTypeName}.fromMap(input);')
          ..writeln('}');
      }
    }

    return buf.toString();
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  /// Converts snake_case / kebab-case to lowerCamelCase.
  ///
  /// Examples:
  ///   'sync_contacts' → 'syncContacts'
  ///   'backup-photos' → 'backupPhotos'
  ///   'myWorker'      → 'myWorker'
  static String _toCamelCase(String id) {
    final parts = id.split(RegExp(r'[_\-]'));
    if (parts.length == 1) return id;
    return parts.first +
        parts
            .skip(1)
            .map((p) => p.isEmpty ? '' : p[0].toUpperCase() + p.substring(1))
            .join();
  }
}

class _WorkerEntry {
  const _WorkerEntry({
    required this.id,
    required this.functionName,
    this.inputTypeName,
  });
  final String id;
  final String functionName;
  final String? inputTypeName;
}
