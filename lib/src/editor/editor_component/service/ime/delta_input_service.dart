import 'dart:math';

import 'package:novident_editor/novident_editor.dart';
import 'package:novident_editor/src/editor/editor_component/service/ime/text_input_service.dart';
import 'package:flutter/services.dart';

const String _deleteBackwardSelectorName = 'deleteBackward:';

class DeltaTextInputService extends TextInputService with DeltaTextInputClient {
  DeltaTextInputService({
    required super.onInsert,
    required super.onDelete,
    required super.onReplace,
    required super.onNonTextUpdate,
    required super.onPerformAction,
    super.contentInsertionConfiguration,
    super.onFloatingCursor,
  });

  @override
  TextRange? composingTextRange;

  @override
  bool get attached => _textInputConnection?.attached ?? false;

  @override
  AutofillScope? get currentAutofillScope => throw UnimplementedError();

  @override
  TextEditingValue? currentTextEditingValue;

  TextInputConnection? _textInputConnection;

  final String debounceKey = 'updateEditingValue';

  // when using gesture to move cursor on mobile, the floating cursor will be visible
  bool _isFloatingCursorVisible = false;

  @override
  // Returning `attached` signals that focus was handled whenever an IME
  // connection is active. Default implementation returns false.
  bool onFocusReceived() => attached;

  @override
  Future<bool> apply(List<TextEditingDelta> deltas) async {
    final formattedDeltas = deltas.map((e) => e.format()).toList();
    bool willApply = true;
    for (final delta in formattedDeltas) {
      _updateComposing(delta);
      switch (delta) {
        case TextEditingDeltaInsertion _:
          if (!(await onInsert(delta))) willApply = false;
        case TextEditingDeltaDeletion _:
          if (!(await onDelete(delta))) willApply = false;
        case TextEditingDeltaReplacement _:
          if (!(await onReplace(delta))) willApply = false;
        case TextEditingDeltaNonTextUpdate _:
          if (!(await onNonTextUpdate(delta))) willApply = false;
      }
    }
    return willApply;
  }

  @override
  void attach(
    TextEditingValue textEditingValue,
    TextInputConfiguration configuration,
  ) {
    // On Windows, the IME (e.g. Korean / other CJK) owns the editing state
    // while a composing region is active. Pushing `setEditingState` back to the
    // engine mid-composition cancels/forks the composition and corrupts the
    // text (jamo get scrambled / duplicated). The text ime connection is
    // already attached at this point, so we simply skip re-attaching while a
    // composition is in progress and let the IME drive the state.
    final composing = composingTextRange;
    if (EditorPlatform.isWindows &&
        composing != null &&
        composing.isValid &&
        !composing.isCollapsed) {
      assert(() {
        NovidentEditorLog.ime
            .debug('ignore Windows attaching by active composing: $composing');
        return true;
      }());
      return;
    }

    if (!attached) {
      _textInputConnection = TextInput.attach(
        this,
        configuration,
      );
    }

    final formattedValue = textEditingValue.format();
    _textInputConnection!
      ..setEditingState(formattedValue)
      ..show();
    currentTextEditingValue = formattedValue;
  }

  @override
  void close() {
    composingTextRange = null;
    _textInputConnection?.close();
    _textInputConnection = null;
  }

  @override
  void updateEditingValueWithDeltas(List<TextEditingDelta> textEditingDeltas) {
    assert(() {
      // NovidentEditorLog.ime.debug(
      //   textEditingDeltas.map((delta) => delta.toString()).toString(),
      // );
      return true;
    }());
    apply(textEditingDeltas);
  }

  @override
  void updateCaretPosition(Size size, Matrix4 transform, Rect rect) {
    _textInputConnection
      ?..setEditableSizeAndTransform(size, transform)
      ..setCaretRect(rect)
      ..setComposingRect(rect.translate(0, rect.height));
  }

  @override
  void clearComposingTextRange() {
    composingTextRange = TextRange.empty;
  }

  @override
  void connectionClosed() {}

  @override
  void insertTextPlaceholder(Size size) {}

  @override
  Future<void> performAction(TextInputAction action) async {
    assert(() {
      NovidentEditorLog.ime.debug("performAction: $action");
      return true;
    }());
    return onPerformAction(action);
  }

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {
    assert(() {
      NovidentEditorLog.ime
          .debug("performPrivateCommand: $action, data: $data");
      return true;
    }());
  }

  @override
  void removeTextPlaceholder() {}

  @override
  void showAutocorrectionPromptRect(int start, int end) {
    assert(() {
      NovidentEditorLog.ime
          .debug("showAutocorrectionPromptRect: start: $start, end: $end");
      return true;
    }());
  }

  @override
  void showToolbar() {
    assert(() {
      NovidentEditorLog.ime.debug("showToolbar executed");
      return true;
    }());
  }

  @override
  void updateEditingValue(TextEditingValue value) {
    if (EditorPlatform.isIOS && _isFloatingCursorVisible) {
      // on iOS, when using gesture to move cursor, this function will be called
      // which may cause the unneeded delta being applied
      // so we ignore the updateEditingValue event when the floating cursor is visible
      assert(() {
        NovidentEditorLog.ime.debug(
          'ignore updateEditingValue event when the floating cursor is visible',
        );
        return true;
      }());
      return;
    }
  }

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {
    switch (point.state) {
      case FloatingCursorDragState.Start:
        _isFloatingCursorVisible = true;
        break;
      case FloatingCursorDragState.Update:
        _isFloatingCursorVisible = true;
        break;
      case FloatingCursorDragState.End:
        _isFloatingCursorVisible = false;
        break;
    }

    onFloatingCursor?.call(point);
  }

  @override
  void didChangeInputControl(
    TextInputControl? oldControl,
    TextInputControl? newControl,
  ) {
    assert(() {
      NovidentEditorLog.ime.debug(
        'didChangeInputControl => old: $oldControl, new: $newControl',
      );
      return true;
    }());
  }

  @override
  void performSelector(String selectorName) {
    assert(() {
      NovidentEditorLog.editor.debug('performSelector: $selectorName');
      return true;
    }());
    final currentTextEditingValue = this.currentTextEditingValue;
    if (currentTextEditingValue == null) {
      return;
    }

    // magic string from flutter callback
    if (selectorName == _deleteBackwardSelectorName) {
      final oldText = currentTextEditingValue.text;
      final selection = currentTextEditingValue.selection;
      final deleteRange = selection.isCollapsed
          ? TextRange(
              start: selection.start - 1,
              end: selection.end,
            )
          : selection;
      onDelete(
        TextEditingDeltaDeletion(
          oldText: oldText,
          deletedRange: deleteRange,
          selection: const TextSelection.collapsed(
            offset: -1,
          ),
          // just pass a invalid value, because we don't use this selection inside.
          composing: TextRange.empty,
        ),
      );
    }
  }

  @override
  void insertContent(KeyboardInsertedContent content) {
    assert(
      contentInsertionConfiguration?.allowedMimeTypes
              .contains(content.mimeType) ??
          false,
    );
    contentInsertionConfiguration?.onContentInserted.call(content);

    assert(() {
      NovidentEditorLog.ime.debug('insertContent: $content');
      return true;
    }());
  }

  void _updateComposing(TextEditingDelta delta) {
    if (delta is! TextEditingDeltaNonTextUpdate) {
      if (composingTextRange != null &&
          composingTextRange!.start != -1 &&
          delta.composing.end != -1) {
        composingTextRange = TextRange(
          start: composingTextRange!.start,
          end: delta.composing.end,
        );
      } else {
        composingTextRange = delta.composing;
      }
    }
  }
}

const String _whitespace = ' ';
const int _len = 1;

extension on TextEditingValue {
  // The IME will not report the backspace button if the cursor is at the beginning of the text.
  // Therefore, we need to add a transparent symbol at the start to ensure that we can capture the backspace event.
  TextEditingValue format() {
    final text = _whitespace + this.text;
    final selection = this.selection >> _len;
    final composing = this.composing >> _len;

    return TextEditingValue(
      text: text,
      selection: selection,
      composing: composing,
    );
  }
}

extension on TextEditingDelta {
  TextEditingDelta format() {
    if (this is TextEditingDeltaInsertion) {
      return (this as TextEditingDeltaInsertion).format();
    } else if (this is TextEditingDeltaDeletion) {
      return (this as TextEditingDeltaDeletion).format();
    } else if (this is TextEditingDeltaReplacement) {
      return (this as TextEditingDeltaReplacement).format();
    } else if (this is TextEditingDeltaNonTextUpdate) {
      return (this as TextEditingDeltaNonTextUpdate).format();
    }
    throw UnimplementedError();
  }
}

extension on TextEditingDeltaInsertion {
  TextEditingDeltaInsertion format() => TextEditingDeltaInsertion(
        oldText: oldText << _len,
        textInserted: textInserted,
        insertionOffset: insertionOffset - _len,
        selection: selection << _len,
        composing: composing << _len,
      );
}

extension on TextEditingDeltaDeletion {
  TextEditingDeltaDeletion format() => TextEditingDeltaDeletion(
        oldText: oldText << _len,
        deletedRange: deletedRange << _len,
        selection: selection << _len,
        composing: composing << _len,
      );
}

extension on TextEditingDeltaReplacement {
  TextEditingDeltaReplacement format() => TextEditingDeltaReplacement(
        oldText: oldText << _len,
        replacementText: replacementText,
        replacedRange: replacedRange << _len,
        selection: selection << _len,
        composing: composing << _len,
      );
}

extension on TextEditingDeltaNonTextUpdate {
  TextEditingDeltaNonTextUpdate format() => TextEditingDeltaNonTextUpdate(
        oldText: oldText << _len,
        selection: selection << _len,
        composing: composing << _len,
      );
}

extension on TextSelection {
  TextSelection operator <<(int shiftAmount) => shift(-shiftAmount);

  TextSelection operator >>(int shiftAmount) => shift(shiftAmount);

  TextSelection shift(int shiftAmount) => TextSelection(
        baseOffset: max(0, baseOffset + shiftAmount),
        extentOffset: max(0, extentOffset + shiftAmount),
      );
}

extension on TextRange {
  TextRange operator <<(int shiftAmount) => shift(-shiftAmount);

  TextRange operator >>(int shiftAmount) => shift(shiftAmount);

  TextRange shift(int shiftAmount) => !isValid
      ? this
      : TextRange(
          start: max(0, start + shiftAmount),
          end: max(0, end + shiftAmount),
        );
}

extension on String {
  String operator <<(int shiftAmount) => shift(shiftAmount);

  String shift(int shiftAmount) {
    if (shiftAmount > length) {
      return '';
    }
    return substring(shiftAmount);
  }
}
