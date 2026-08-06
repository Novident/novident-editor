import 'package:flutter/material.dart';
import 'package:novident_editor_core/novident_editor_core.dart';
import 'package:novident_editor_document/novident_editor_document.dart';

TextSelection? textSelectionFromEditorSelection(
  Node node,
  Selection? selection,
  int offsetSumFactor,
) {
  if (selection == null) {
    return null;
  }

  final normalized = selection.normalized;
  final path = node.path;
  if (path < normalized.start.path || path > normalized.end.path) {
    return null;
  }

  final length = node.delta?.length;
  if (length == null) {
    return null;
  }

  TextSelection? textSelection;

  if (normalized.isSingle) {
    if (path.equals(normalized.start.path)) {
      if (normalized.isCollapsed) {
        textSelection = TextSelection.collapsed(
          offset: normalized.startIndex + offsetSumFactor,
        );
      } else {
        textSelection = TextSelection(
          baseOffset: normalized.startIndex + offsetSumFactor,
          extentOffset: normalized.endIndex + offsetSumFactor,
        );
      }
    }
  } else {
    if (path.equals(normalized.start.path)) {
      textSelection = TextSelection(
        baseOffset: normalized.startIndex + offsetSumFactor,
        extentOffset: length + offsetSumFactor,
      );
    } else if (path.equals(normalized.end.path)) {
      textSelection = TextSelection(
        baseOffset: offsetSumFactor,
        extentOffset: normalized.endIndex + offsetSumFactor,
      );
    } else {
      textSelection = TextSelection(
        baseOffset: offsetSumFactor,
        extentOffset: length + offsetSumFactor,
      );
    }
  }
  return textSelection;
}
