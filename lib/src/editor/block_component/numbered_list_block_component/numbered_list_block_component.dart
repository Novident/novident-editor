import 'package:novident_editor/novident_editor.dart';
import 'package:flutter/material.dart';
import 'package:numerus/roman/roman.dart';
import 'package:provider/provider.dart';

Node numberedListNode({
  Delta? delta,
  Attributes? attributes,
  int? number,
  String? textDirection,
  String? styleRef,
  Iterable<Node>? children,
}) {
  attributes ??= {
    'delta': (delta ?? Delta()).toJson(),
    NumberedListBlockKeys.number: number,
  };
  return Node(
    type: NumberedListBlockKeys.type,
    attributes: {
      ...attributes,
      if (styleRef != null) blockComponentStyleRef: styleRef,
      if (textDirection != null)
        NumberedListBlockKeys.textDirection: textDirection,
    },
    children: children ?? [],
  );
}

typedef NumberedListIconBuilder = Widget Function(
  BuildContext context,
  Node node,
  TextDirection direction,
);

class NumberedListBlockComponentBuilder extends BlockComponentBuilder {
  NumberedListBlockComponentBuilder({
    super.configuration,
    this.iconBuilder,
  });

  final NumberedListIconBuilder? iconBuilder;

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return NumberedListBlockComponentWidget(
      key: node.key,
      node: node,
      configuration: configuration,
      iconBuilder: iconBuilder,
      showActions: showActions(node),
      actionBuilder: (context, state) => actionBuilder(
        blockComponentContext,
        state,
      ),
      actionTrailingBuilder: (context, state) => actionTrailingBuilder(
        blockComponentContext,
        state,
      ),
    );
  }

  @override
  BlockComponentValidate get validate => (node) => node.delta != null;
}

class NumberedListBlockComponentWidget extends BlockComponentStatefulWidget {
  const NumberedListBlockComponentWidget({
    super.key,
    required super.node,
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
    super.configuration = const BlockComponentConfiguration(),
    this.iconBuilder,
  });

  final NumberedListIconBuilder? iconBuilder;

  @override
  State<NumberedListBlockComponentWidget> createState() =>
      _NumberedListBlockComponentWidgetState();
}

class _NumberedListBlockComponentWidgetState
    extends State<NumberedListBlockComponentWidget>
    with
        SelectableMixin,
        DefaultSelectableMixin,
        BlockComponentConfigurable,
        BlockComponentBackgroundColorMixin,
        NestedBlockComponentStatefulWidgetMixin,
        BlockComponentTextDirectionMixin,
        BlockComponentAlignMixin,
        BlockHeightReporter {
  @override
  final forwardKey = GlobalKey(debugLabel: 'rich_text');

  @override
  GlobalKey<State<StatefulWidget>> get containerKey => widget.node.key;

  @override
  GlobalKey<State<StatefulWidget>> blockComponentKey = GlobalKey(
    debugLabel: NumberedListBlockKeys.type,
  );

  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;

  @override
  void initState() {
    super.initState();
    scheduleHeightReport();
  }

  @override
  void didUpdateWidget(
    covariant NumberedListBlockComponentWidget oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);
    scheduleHeightReport();
  }

  @override
  Widget buildComponent(
    BuildContext context, {
    bool withBackgroundColor = true,
  }) {
    final textDirection = calculateTextDirection(
      layoutDirection: Directionality.maybeOf(context),
    );

    final blockStyle = NovidentBlockStyleResolver.resolve(context, widget.node);

    final effectiveTextAlign =
        nodeTextAlign ?? blockStyle.alignment ?? textAlign;

    Widget child = Container(
      width: double.infinity,
      alignment: alignment,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        textDirection: textDirection,
        children: [
          widget.iconBuilder != null
              ? widget.iconBuilder!(
                  context,
                  node,
                  textDirection,
                )
              : _NumberedListIcon(
                  node: node,
                  textStyle: textStyleWithTextSpan(),
                  direction: textDirection,
                ),
          Flexible(
            child: NovidentRichText(
              key: forwardKey,
              delegate: this,
              node: widget.node,
              editorConfig: editorState,
              textAlign: effectiveTextAlign,
              placeholderText: placeholderText,
              useFirstLineIndent: false,
              textSpanDecorator: (textSpan) => textSpan.updateTextStyle(
                textStyleWithTextSpan(textSpan: textSpan),
              ),
              placeholderTextSpanDecorator: (textSpan) =>
                  textSpan.updateTextStyle(
                placeholderTextStyleWithTextSpan(textSpan: textSpan),
              ),
              textDirection: textDirection,
              cursorColor: editorState.editorStyle.cursorColor,
              selectionColor: editorState.editorStyle.selectionColor,
              cursorWidth: editorState.editorStyle.cursorWidth,
            ),
          ),
        ],
      ),
    );

    child = Container(
      key: blockComponentKey,
      decoration:
          blockStyle.applyToDecoration(withBackgroundColor ? decoration : null),
      padding: blockStyle.applyToPadding(padding),
      child: child,
    );

    child = BlockSelectionContainer(
      node: node,
      delegate: this,
      listenable: editorState.selectionNotifier,
      host: editorState,
      renderer: editorState.editorStyle.selectionRenderer,
      remoteSelection: editorState.remoteSelections,
      blockColor: editorState.editorStyle.selectionColor,
      supportTypes: const [
        BlockSelectionType.block,
      ],
      child: child,
    );

    if (widget.showActions && widget.actionBuilder != null) {
      child = BlockComponentActionWrapper(
        node: node,
        actionBuilder: widget.actionBuilder!,
        actionTrailingBuilder: widget.actionTrailingBuilder,
        child: child,
      );
    }

    return child;
  }
}

class _NumberedListIcon extends StatelessWidget {
  const _NumberedListIcon({
    required this.node,
    required this.textStyle,
    required this.direction,
  });

  final Node node;
  final TextStyle textStyle;
  final TextDirection direction;

  @override
  Widget build(BuildContext context) {
    final editorState = context.read<EditorState>();
    final defaultText = DefaultTextStyle.of(context).style;
    final textScaleFactor = editorState.editorStyle.textScaleFactor;
    return Container(
      constraints:
          const BoxConstraints(minWidth: 26, minHeight: 22) * textScaleFactor,
      padding: const EdgeInsets.only(right: 4.0),
      child: Center(
        child: Text.rich(
          textScaler: TextScaler.linear(textScaleFactor),
          textHeightBehavior: const TextHeightBehavior(
            applyHeightToFirstAscent: false,
            applyHeightToLastDescent: false,
          ),
          TextSpan(
            text: node.levelString,
            style: defaultText.combine(textStyle),
          ),
          textDirection: direction,
        ),
      ),
    );
  }
}

extension on Node {
  String get levelString {
    final builder = _NumberedListIconBuilder(node: this);
    final indexInRootLevel = builder.indexInRootLevel;
    final indexInSameLevel = builder.indexInSameLevel;
    final level = indexInRootLevel % 3;
    final levelString = switch (level) {
      1 => indexInSameLevel.latin,
      2 => indexInSameLevel.roman,
      _ => '$indexInSameLevel',
    };
    return '$levelString.';
  }
}

class _NumberedListIconBuilder {
  _NumberedListIconBuilder({
    required this.node,
  });

  final Node node;

  // the level of the current node
  int get indexInRootLevel {
    var level = 0;
    var parent = node.parent;
    while (parent != null) {
      if (parent.type == NumberedListBlockKeys.type) {
        level++;
      }
      parent = parent.parent;
    }
    return level;
  }

  // the index of the current level
  int get indexInSameLevel {
    int level = 1;
    Node? previous = node.previous;

    // if the previous one is not a numbered list, then it is the first one
    if (previous == null || previous.type != NumberedListBlockKeys.type) {
      return node.attributes[NumberedListBlockKeys.number] ?? level;
    }

    int? startNumber;
    while (previous != null && previous.type == NumberedListBlockKeys.type) {
      startNumber = previous.attributes[NumberedListBlockKeys.number] as int?;
      level++;
      previous = previous.previous;
    }
    if (startNumber != null) {
      return startNumber + level - 1;
    }
    return level;
  }
}

extension on int {
  String get latin {
    String result = '';
    int number = this;
    while (number > 0) {
      final int remainder = (number - 1) % 26;
      result = String.fromCharCode(remainder + 65) + result;
      number = (number - 1) ~/ 26;
    }
    return result.toLowerCase();
  }

  String get roman {
    return toRomanNumeralString() ?? '$this';
  }
}
