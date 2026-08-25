import 'dart:convert';

import 'package:novident_editor/novident_editor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

Future<void> onInsert(
  TextEditingDeltaInsertion insertion,
  EditorState editorState,
) async {
  assert(() {
    NovidentEditorLog.input.debug('onInsert: $insertion');
    return true;
  }());

  var selection = editorState.selection;
  if (selection == null) {
    return;
  }

  if (!selection.isCollapsed) {
    await editorState.deleteSelection(selection);
  }

  selection = editorState.selection?.normalized;
  if (selection == null || !selection.isSingle) {
    return;
  }

  // IME
  // single line
  final node = editorState.getNodeAtPath(selection.start.path);
  if (node == null) {
    return;
  }
  assert(node.delta != null);

  if (kDebugMode) {
    // verify the toggled keys are supported.
    assert(
      editorState.toggledStyle.keys.every(
        (element) => RichTextKeys.supportToggled.contains(element),
      ),
    );
  }

  final containsNewLine = insertion.textInserted.length <= 1
      ? false
      : insertion.textInserted.contains('\n');
  late final Selection afterSelection;

  final transaction = editorState.transaction;
  if (!containsNewLine) {
    afterSelection = Selection(
      start: Position(
        path: node.path,
        offset: insertion.selection.baseOffset,
      ),
      end: Position(
        path: node.path,
        offset: insertion.selection.extentOffset,
      ),
    );
    transaction
      ..insertText(
        node,
        selection.startIndex,
        insertion.textInserted,
        toggledAttributes: editorState.toggledStyle,
        sliceAttributes: editorState.sliceUpcomingAttributes,
      )
      ..afterSelection = afterSelection;
    await editorState.apply(transaction);
  } else {
    final split = _lineSplitter.convert(insertion.textInserted);

    transaction.insertText(
      node,
      selection.startIndex,
      split[0],
      toggledAttributes: editorState.toggledStyle,
      sliceAttributes: editorState.sliceUpcomingAttributes,
    );

    if (split.length > 1) {
      final newNodes = <Node>[];
      for (int index = 1; index < split.length; index++) {
        final newNode = paragraphNode(
          delta: Delta()..insert(split[index]),
        );
        newNode
          ..attributes[blockComponentStyleRef] =
              _resolveNextStyleRef(editorState, newNode)
          ..extraInfos = <String, dynamic>{}
          ..extraInfos?['required_revision'] = true;
        newNodes.add(newNode);
      }

      // Insert all new paragraphs as a contiguous block right after the
      // current node. Paths passed to the transaction live in the original
      // coordinate space, so a single `insertNodes` avoids the path-shift
      // that incremental `insertNode` calls would introduce.
      transaction.insertNodes(selection.end.path.next, newNodes);

      // Place the cursor at the end of the last inserted paragraph.
      final lastPath = selection.end.path.next.nextNPath(newNodes.length - 1);
      transaction.afterSelection = Selection.collapsed(
        Position(
          path: lastPath,
          offset: split.last.length,
        ),
      );
    }

    await editorState.apply(transaction);
  }
}

/// Resolves the [NovidentStyleDefinition.next] style ID for [node].
///
/// Returns `null` when no styles are configured, the node has no style,
/// or the resolved style has no [next] defined.
String? _resolveNextStyleRef(EditorState state, Node node) {
  final config = state.editorStyles;
  if (config == null) return null;
  final styleRef = node.attributes[blockComponentStyleRef] as String?;
  if (styleRef != null && styleRef.isNotEmpty) {
    final resolved = config.registry.resolve(
      styleRef,
      baseStyle: config.defaultStyle,
      byTypes: config.defaultStylesByType,
      forType: node.type,
    );
    return resolved?.next;
  }
  final typeDefault = config.defaultStylesByType[node.type];
  if (typeDefault != null) return typeDefault.next;
  return config.defaultStyle.next;
}

const LineSplitter _lineSplitter = LineSplitter();
