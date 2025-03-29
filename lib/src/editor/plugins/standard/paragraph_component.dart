import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:novident_editor/src/common/mixins/default_selection_capibility.dart';
import 'package:novident_editor/src/common/mixins/selection_capability_mixin.dart';
import 'package:novident_editor/src/document/delta/delta.dart';
import 'package:novident_editor/src/document/keys/node_keys.dart';
import 'package:novident_editor/src/document/node.dart';
import 'package:novident_editor/src/editor/plugins/component_context.dart';
import 'package:novident_editor/src/editor/plugins/component_plugin.dart';
import 'package:novident_editor/src/novident_selectable_text/nov_rich_text_widget.dart';

Node paragraphNode({
  String? id,
  String? text,
  Delta? delta,
  String? textDirection,
  Map<String, dynamic>? attributes,
}) {
  return Node(
    id: id,
    type: NodeKeysDefaults.kDefaultParagraphKey,
    data: <String, dynamic>{
      NodeKeysDefaults.kDefaultTextKey: (delta ?? (Delta()..insert(text ?? ''))),
      ...?attributes,
    },
  );
}

class ParagraphComponent extends ComponentPlugin {
  ParagraphComponent();

  @override
  Widget? render(ComponentContext context) {
    if (context.node.type != NodeKeysDefaults.kDefaultParagraphKey) {
      return null;
    }
    return ParagraphWidget(key: context.node.key, context: context);
  }

  @override
  List<ComponentBlockActionPlugin> renderSettings(ComponentContext context) {
    return [];
  }
}

class ParagraphWidget extends StatefulWidget {
  final ComponentContext context;
  const ParagraphWidget({
    super.key,
    required this.context,
  });

  @override
  State<ParagraphWidget> createState() => _ParagraphWidgetState();
}

class _ParagraphWidgetState extends State<ParagraphWidget>
    with SelectionCapabilityMixin, DefaultSelectionCapibility {

  @override
  GlobalKey<State<StatefulWidget>> get blockComponentKey => GlobalKey();

  @override
  GlobalKey<State<StatefulWidget>> get containerKey => widget.context.node.key;

  @override
  GlobalKey<State<StatefulWidget>> get forwardKey => GlobalKey();

  @override
  Widget build(BuildContext context) {
    final Node node = widget.context.node;
    return Padding(
      key: blockComponentKey,
      padding: const EdgeInsets.all(8.0),
      child: NovRichTextWidget(
        key: forwardKey,
        node: node,
      ),
    );
  }
}
