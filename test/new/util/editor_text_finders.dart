import 'package:flutter/widgets.dart' show Text;
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor_core/novident_editor_flutter.dart'
    as core_flutter;

/// Finds editor text rendered either by the editor's own
/// [core_flutter.RichText] (the fork defined in `novident_editor_core`) or by
/// a Flutter [Text]/[Text.rich] widget.
///
/// The editor renders body text with the custom `RichText` fork from
/// `novident_editor_core` (`novident_editor_flutter.dart`), a different class
/// from Flutter's `RichText`, so `find.text(..., findRichText: true)` never
/// matches it. Some editor chrome (e.g. numbered-list prefixes) renders with
/// plain [Text.rich] instead. This finder is the drop-in replacement for
/// `find.text(..., findRichText: true)` in editor widget tests.
Finder findEditorRichText(
  String text, {
  bool skipOffstage = true,
}) {
  return find.byWidgetPredicate(
    (widget) {
      if (widget is core_flutter.RichText) {
        return widget.text.toPlainText() == text;
      }
      if (widget is Text) {
        return widget.data == text ||
            (widget.data == null && widget.textSpan?.toPlainText() == text);
      }
      return false;
    },
    skipOffstage: skipOffstage,
  );
}

/// Like [findEditorRichText] but matches text containing [pattern].
Finder findEditorRichTextContaining(
  Pattern pattern, {
  bool skipOffstage = true,
}) {
  bool contains(String plain) => pattern is RegExp
      ? pattern.hasMatch(plain)
      : plain.contains(pattern.toString());

  return find.byWidgetPredicate(
    (widget) {
      if (widget is core_flutter.RichText) {
        return contains(widget.text.toPlainText());
      }
      if (widget is Text) {
        if (widget.data != null) {
          return contains(widget.data!);
        }
        return contains(widget.textSpan?.toPlainText() ?? '');
      }
      return false;
    },
    skipOffstage: skipOffstage,
  );
}
