import 'package:flutter/material.dart';
import 'package:novident_editor/src/document/node.dart';

class ComponentContext {
  final BuildContext buildContext;
  final int componentIndex;
  final Node node;

  ComponentContext({
    required this.buildContext,
    required this.componentIndex,
    required this.node,
  });
}
