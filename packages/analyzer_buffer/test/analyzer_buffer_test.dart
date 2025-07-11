// ignore_for_file: deprecated_member_use

import 'package:analyzer/dart/element/element2.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer_buffer/analyzer_buffer.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('AnalyzerBuffer', () {
    test('handles empty', () async {
      final result = await resolveFiles('''
int value() => 42;
''');
      final type = result.libraryElement2.typeProvider.intType;

      var buffer = AnalyzerBuffer.newLibrary(
        header: 'Foo',
        sourcePath: result.libraryElement2.uri.path,
      );

      expect(buffer.isEmpty, isTrue);
      expect(buffer.toString(), '');
      buffer.write('Hello World');
      expect(buffer.isEmpty, isFalse);
      expect(buffer.toString(), isNotEmpty);

      buffer = AnalyzerBuffer.fromLibrary2(
        result.libraryElement2,
        sourcePath: result.libraryElement2.uri.path,
      );

      expect(buffer.isEmpty, isTrue);
      expect(buffer.toString(), '');
      buffer.writeType(type);
      expect(buffer.isEmpty, isFalse);
      expect(buffer.toString(), isNotEmpty);
    });

    group('writeType', () {
      test('preserves typedefs, if any', () async {
        final result = await resolveFiles('''
typedef MyMap<T> = Map<T, T;

MyMap<int> value() => 42;
''');
        final buffer = AnalyzerBuffer.fromLibrary2(
          result.libraryElement2,
          sourcePath: result.libraryElement2.uri.path,
        );

        final valueElement =
            result.libraryElement2.getTopLevelFunction('value')!;

        buffer.write('Hello(');
        buffer.writeType(valueElement.returnType);
        buffer.write(') World');

        expect(
          buffer.toString(),
          contains('Hello(MyMap<int>) World'),
        );
      });
      test('recursive: controls whether type arguments are written', () async {
        final result = await resolveFiles("import 'dart:async' as async;'");
        final buffer = AnalyzerBuffer.fromLibrary2(
          result.libraryElement2,
          sourcePath: result.libraryElement2.uri.path,
        );

        final controllerElement =
            result.importedElementWithName('StreamController')!;
        controllerElement as ClassElement2;

        final controllerType = controllerElement.instantiate(
          typeArguments: [result.libraryElement2.typeProvider.doubleType],
          nullabilitySuffix: NullabilitySuffix.none,
        );

        buffer.write('Hello(');
        buffer.writeType(controllerType, recursive: false);
        buffer.write(') World');

        expect(
          buffer.toString(),
          contains('Hello(async.StreamController) World'),
        );
      });
      test('respects import prefixes', () async {
        final result = await resolveFiles(
          "import 'dart:async' as async;'\n"
          "import 'dart:io' as io;'\n"
          "import 'package:path/path.dart';",
        );
        final buffer = AnalyzerBuffer.fromLibrary(
          result.libraryElement,
          sourcePath: result.libraryElement2.uri.path,
        );
        final buffer2 = AnalyzerBuffer.fromLibrary2(
          result.libraryElement2,
          sourcePath: result.libraryElement2.uri.path,
        );

        final controllerElement =
            result.importedElementWithName('StreamController')!;
        controllerElement as ClassElement2;
        final fileElement = result.importedElementWithName('File')!;
        fileElement as ClassElement2;
        final contextElement = result.importedElementWithName('Context')!;
        contextElement as ClassElement2;

        final controllerType = controllerElement.instantiate(
          typeArguments: [fileElement.thisType],
          nullabilitySuffix: NullabilitySuffix.none,
        );

        buffer.write('Hello(');
        buffer.writeType(controllerType);
        buffer.write(') World');

        buffer.write('Hello(');
        buffer.writeType(contextElement.thisType);
        buffer.write(') World');

        buffer2.write('Hello(');
        buffer2.writeType(controllerType);
        buffer2.write(') World');

        buffer2.write('Hello(');
        buffer2.writeType(contextElement.thisType);
        buffer2.write(') World');

        expect(
          buffer.toString(),
          contains('Hello(async.StreamController<io.File>) World'),
        );
        expect(
          buffer.toString(),
          contains('Hello(Context) World'),
        );

        expect(
          buffer2.toString(),
          contains('Hello(async.StreamController<io.File>) World'),
        );
        expect(
          buffer2.toString(),
          contains('Hello(Context) World'),
        );
      });
      test('if created with .newLibrary, adds auto-imports for types',
          () async {
        final buffer = AnalyzerBuffer.newLibrary(sourcePath: '');

        final result = await resolveFiles(
          "import 'dart:async' as async;'\n"
          "import 'dart:io' as io;'\n"
          "import 'package:path/path.dart;",
        );

        final controllerElement =
            result.importedElementWithName('StreamController')!;
        controllerElement as ClassElement2;
        final fileElement = result.importedElementWithName('File')!;
        fileElement as ClassElement2;

        final controllerType = controllerElement.instantiate(
          typeArguments: [fileElement.thisType],
          nullabilitySuffix: NullabilitySuffix.none,
        );
        final controllerType2 = controllerElement.instantiate(
          typeArguments: [result.typeProvider.voidType],
          nullabilitySuffix: NullabilitySuffix.none,
        );

        buffer.writeType(controllerType);
        buffer.writeType(controllerType2);

        expect(
          buffer.toString(),
          matchesIgnoringPrefixes(strContainsOnce("import 'dart:async' as _0;")),
        );
        expect(
          buffer.toString(),
          matchesIgnoringPrefixes(strContainsOnce("import 'dart:io' as _0;")),
        );
        expect(
          buffer.toString(),
          isNot(
            matchesIgnoringPrefixes(
              strContainsOnce("import 'package:path/path.dart' as _0;"),
            ),
          ),
        );
      });
    });
    group('toString', () {
      test('includes a top comment, headers, imports and writes', () {
        final buffer = AnalyzerBuffer.newLibrary(
          header: '<Header>',
          sourcePath: '',
        );

        buffer.write('Hello #{{dart:async|StreamController}} World');

        expect(
          buffer.toString(),
          matchesIgnoringPrefixes('''
// GENERATED CODE - DO NOT MODIFY BY HAND
<Header>
import 'dart:async' as _0;
Hello _0.StreamController World'''),
        );
      });
    });
    group('write', () {
      test('handles re-export as prefix', () async {
        final result = await resolveFiles(
          "import 'foo.dart' as foo;",
          files: {'foo.dart': "export 'dart:async';"},
        );
        final buffer = AnalyzerBuffer.fromLibrary(
          result.libraryElement,
          sourcePath: result.libraryElement2.uri.path,
        );
        final buffer2 = AnalyzerBuffer.fromLibrary2(
          result.libraryElement2,
          sourcePath: result.libraryElement2.uri.path,
        );

        buffer.write('Hello #{{dart:async|StreamController}} World');
        buffer2.write('Hello #{{dart:async|StreamController}} World');

        expect(
          buffer.toString(),
          matchesIgnoringPrefixes(
            contains('Hello foo.StreamController World'),
          ),
        );
        expect(
          buffer2.toString(),
          matchesIgnoringPrefixes(
            contains('Hello foo.StreamController World'),
          ),
        );
      });

      test('interpolates #{{uri|name}}', () {
        final file = tempDir().file('test', 'main.dart');
        final buffer = AnalyzerBuffer.newLibrary(
          sourcePath: file.path,
        );

        buffer.write(
          'Hello '
          '#{{dart:core|int}} '
          '#{{dart:async|StreamController}} '
          '#{{dart:async|FutureOr}} '
          '#{{package:example|Name}} '
          '#{{package:example/foo.dart|Name2}} '
          '#{{riverpod|Provider}} '
          '#{{other/bar.dart|Bar}} '
          '#{{other/baz|Baz}} '
          '#{{file://${file.path}|File}} '
          'World',
        );

        expect(buffer.toString(), isNot(contains('dart:core')));
        expect(buffer.toString(), strContainsOnce('dart:async'));
        expect(
          buffer.toString(),
          strContainsOnce('package:example/example.dart'),
        );
        expect(buffer.toString(), strContainsOnce('package:example/foo.dart'));
        expect(
          buffer.toString(),
          strContainsOnce('package:riverpod/riverpod.dart'),
        );
        expect(buffer.toString(), strContainsOnce('package:other/bar.dart'));
        expect(buffer.toString(), strContainsOnce('package:other/baz.dart'));
        expect(
          buffer.toString(),
          strContainsOnce("import 'file://${file.path}'"),
        );

        expect(
          buffer.toString(),
          matchesIgnoringPrefixes(
            allOf([
              contains(' int '),
              contains(' _0.StreamController '),
              contains(' _0.Name '),
              contains(' _0.Name2 '),
              contains(' _0.Provider '),
              contains(' _0.Bar '),
              contains(' _0.Baz '),
              contains(' _0.File '),
            ]),
          ),
        );
      });
      test('interpolates #{{name}} with args', () {
        final buffer = AnalyzerBuffer.newLibrary(sourcePath: '');

        buffer.write(
          'Hello #{{name}} World',
          args: {'name': () => buffer.write('Dart')},
        );

        expect(
          buffer.toString(),
          matchesIgnoringPrefixes(contains('Hello Dart World')),
        );
      });
      test('#{{name}} without a matching arg throws', () {
        final buffer = AnalyzerBuffer.newLibrary(sourcePath: '');

        expect(
          () => buffer.write('Hello #{{name}} World'),
          throwsA(isA<ArgumentError>()),
        );
      });
      test(
          'args that call `write` inherit the current arguments, on top of the new ones',
          () {
        final buffer = AnalyzerBuffer.newLibrary(sourcePath: '');

        buffer.write(
          args: {
            'arg1': () => buffer.write(
                  args: {'arg3': () => buffer.write('World')},
                  'Hello #{{arg2}} from #{{arg3}}',
                ),
            'arg2': () => buffer.write('John'),
          },
          '#{{arg1}}',
        );

        expect(
          buffer.toString(),
          contains('Hello John from World'),
        );
      });
      test(
          'if created with .fromLibrary2, does not add auto-import but respect prefixes',
          () async {
        final result = await resolveFiles("import 'dart:async' as async;");
        final buffer = AnalyzerBuffer.fromLibrary2(
          result.libraryElement2,
          sourcePath: result.libraryElement2.uri.path,
        );

        buffer.write('Hello #{{dart:async|StreamController}} World');

        expect(buffer.toString(), isNot(contains('dart:async')));

        expect(
          buffer.toString(),
          matchesIgnoringPrefixes(
            contains('Hello async.StreamController World'),
          ),
        );
      });
    });
  });

  group('CodeFor', () {
    test('converts Elements2 to code', () async {
      final result = await resolveFiles(
        "import 'dart:async' as async;\n"
        "import 'dart:io' as io;\n",
      );

      final controllerElement =
          result.importedElementWithName('StreamController')!;
      controllerElement as ClassElement2;
      final fileElement = result.importedElementWithName('File')!;
      fileElement as ClassElement2;

      final controllerType = controllerElement.instantiate(
        typeArguments: [fileElement.thisType],
        nullabilitySuffix: NullabilitySuffix.none,
      );

      expect(
        controllerType.toCode(),
        '#{{dart:async|StreamController}}<#{{dart:io|File}}>',
      );
      expect(
        controllerType.toCode(recursive: false),
        '#{{dart:async|StreamController}}',
      );
    });
  });
}

Matcher strContainsOnce(String substring) {
  return predicate<String>(
    (value) {
      final firstMatchIndex = value.indexOf(substring);
      if (firstMatchIndex == -1) return false;

      final lastMatchIndex = value.lastIndexOf(substring);
      return firstMatchIndex == lastMatchIndex;
    },
    'contains "$substring" exactly once',
  );
}
