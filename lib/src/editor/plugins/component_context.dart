import 'package:flutter/material.dart';
import 'package:novident_editor/src/document/node.dart';
import 'package:novident_editor/src/editor/editor_context.dart';

class ComponentContext {
  final BuildContext buildContext;
  final EditorContext editorContext;
  final int componentIndex;
  final Node node;

  ComponentContext({
    required this.buildContext,
    required this.componentIndex,
    required this.node,
    required this.editorContext,
  });
}
