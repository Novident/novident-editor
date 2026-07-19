import 'package:novident_editor/src/infra/log.dart';
import 'package:flutter_test/flutter_test.dart';

import '../new/infra/testable_editor.dart';

void main() async {
  group('log.dart', () {
    testWidgets('test LogConfiguration in EditorState', (tester) async {
      TestWidgetsFlutterBinding.ensureInitialized();

      const text = 'Welcome to Novident 😁';

      final List<String> logs = [];

      final editor = tester.editor;
      editor.editorState.logConfiguration
        ..level = NovidentEditorLogLevel.all
        ..handler = (message) {
          logs.add(message);
        };

      NovidentEditorLog.editor.debug(text);
      expect(logs.last.contains('DEBUG'), true);
      expect(logs.length, 1);
    });

    test('test LogLevel.all', () {
      const text = 'Welcome to Novident 😁';

      final List<String> logs = [];
      NovidentLogConfiguration()
        ..level = NovidentEditorLogLevel.all
        ..handler = (message) {
          logs.add(message);
        };

      NovidentEditorLog.editor.debug(text);
      expect(logs.last.contains('DEBUG'), true);
      NovidentEditorLog.editor.info(text);
      expect(logs.last.contains('INFO'), true);
      NovidentEditorLog.editor.warn(text);
      expect(logs.last.contains('WARN'), true);
      NovidentEditorLog.editor.error(text);
      expect(logs.last.contains('ERROR'), true);

      expect(logs.length, 4);
    });

    test('test LogLevel.off', () {
      const text = 'Welcome to Novident 😁';

      final List<String> logs = [];
      NovidentLogConfiguration()
        ..level = NovidentEditorLogLevel.off
        ..handler = (message) {
          logs.add(message);
        };

      NovidentEditorLog.editor.debug(text);
      NovidentEditorLog.editor.info(text);
      NovidentEditorLog.editor.warn(text);
      NovidentEditorLog.editor.error(text);

      expect(logs.length, 0);
    });

    test('test LogLevel.error', () {
      const text = 'Welcome to Novident 😁';

      final List<String> logs = [];
      NovidentLogConfiguration()
        ..level = NovidentEditorLogLevel.error
        ..handler = (message) {
          logs.add(message);
        };

      NovidentEditorLog.editor.debug(text);
      NovidentEditorLog.editor.info(text);
      NovidentEditorLog.editor.warn(text);
      NovidentEditorLog.editor.error(text);

      expect(logs.length, 1);
    });

    test('test LogLevel.warn', () {
      const text = 'Welcome to Novident 😁';

      final List<String> logs = [];
      NovidentLogConfiguration()
        ..level = NovidentEditorLogLevel.warn
        ..handler = (message) {
          logs.add(message);
        };

      NovidentEditorLog.editor.debug(text);
      NovidentEditorLog.editor.info(text);
      NovidentEditorLog.editor.warn(text);
      NovidentEditorLog.editor.error(text);

      expect(logs.length, 2);
    });

    test('test LogLevel.info', () {
      const text = 'Welcome to Novident 😁';

      final List<String> logs = [];
      NovidentLogConfiguration()
        ..level = NovidentEditorLogLevel.info
        ..handler = (message) {
          logs.add(message);
        };

      NovidentEditorLog.editor.debug(text);
      NovidentEditorLog.editor.info(text);
      NovidentEditorLog.editor.warn(text);
      NovidentEditorLog.editor.error(text);

      expect(logs.length, 3);
    });

    test('test LogLevel.debug', () {
      const text = 'Welcome to Novident 😁';

      final List<String> logs = [];
      NovidentLogConfiguration()
        ..level = NovidentEditorLogLevel.debug
        ..handler = (message) {
          logs.add(message);
        };

      NovidentEditorLog.editor.debug(text);
      NovidentEditorLog.editor.info(text);
      NovidentEditorLog.editor.warn(text);
      NovidentEditorLog.editor.error(text);

      expect(logs.length, 4);
    });

    test('test logger', () {
      const text = 'Welcome to Novident 😁';

      final List<String> logs = [];
      NovidentLogConfiguration()
        ..level = NovidentEditorLogLevel.all
        ..handler = (message) {
          logs.add(message);
        };

      NovidentEditorLog.editor.debug(text);
      expect(logs.last.contains('editor'), true);

      NovidentEditorLog.selection.debug(text);
      expect(logs.last.contains('selection'), true);

      NovidentEditorLog.keyboard.debug(text);
      expect(logs.last.contains('keyboard'), true);

      NovidentEditorLog.input.debug(text);
      expect(logs.last.contains('input'), true);

      NovidentEditorLog.scroll.debug(text);
      expect(logs.last.contains('scroll'), true);

      NovidentEditorLog.ui.debug(text);
      expect(logs.last.contains('ui'), true);

      expect(logs.length, 6);
    });
  });
}
