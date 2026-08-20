import 'package:novident_editor/novident_editor.dart';
import 'package:novident_editor/src/editor/block_component/base_component/block_icon_builder.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

Node quoteNode({
  Delta? delta,
  String? textDirection,
  Attributes? attributes,
  String? styleRef,
  Iterable<Node>? children,
}) {
  attributes ??= {'delta': (delta ?? Delta()).toJson()};
  return Node(
    type: QuoteBlockKeys.type,
    attributes: {
      ...attributes,
      if (styleRef != null) blockComponentStyleRef: styleRef,
      if (textDirection != null) QuoteBlockKeys.textDirection: textDirection,
    },
    children: children ?? [],
  );
}

class QuoteBlockComponentBuilder extends BlockComponentBuilder {
  QuoteBlockComponentBuilder({
    super.configuration,
    this.iconBuilder,
  });

  final BlockIconBuilder? iconBuilder;

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return QuoteBlockComponentWidget(
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

class QuoteBlockComponentWidget extends BlockComponentStatefulWidget {
  const QuoteBlockComponentWidget({
    super.key,
    required super.node,
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
    super.configuration = const BlockComponentConfiguration(),
    this.iconBuilder,
  });

  final BlockIconBuilder? iconBuilder;

  @override
  State<QuoteBlockComponentWidget> createState() =>
      _QuoteBlockComponentWidgetState();
}

class _QuoteBlockComponentWidgetState extends State<QuoteBlockComponentWidget>
    with
        SelectableMixin,
        DefaultSelectableMixin,
        BlockComponentConfigurable,
        BlockComponentBackgroundColorMixin,
        BlockComponentTextDirectionMixin,
        BlockComponentAlignMixin,
        BlockHeightReporter {
  @override
  final forwardKey = GlobalKey(debugLabel: 'flowy_rich_text');

  @override
  GlobalKey<State<StatefulWidget>> get containerKey => widget.node.key;

  @override
  GlobalKey<State<StatefulWidget>> blockComponentKey = GlobalKey(
    debugLabel: QuoteBlockKeys.type,
  );

  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  void initState() {
    super.initState();
    scheduleHeightReport();
  }

  @override
  void didUpdateWidget(covariant QuoteBlockComponentWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    scheduleHeightReport();
  }

  @override
  Node get node => widget.node;

  @override
  late final editorState = Provider.of<EditorState>(context, listen: false);

  @override
  Widget build(BuildContext context) {
    final textDirection = calculateTextDirection(
      layoutDirection: Directionality.maybeOf(context),
    );

    final blockStyle = NovidentBlockStyleResolver.resolve(context, widget.node);

    Widget child = Container(
      width: double.infinity,
      alignment: alignment,
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          textDirection: textDirection,
          children: [
            widget.iconBuilder != null
                ? widget.iconBuilder!(context, node)
                : const _QuoteIcon(),
            Flexible(
              child: NovidentRichText(
                key: forwardKey,
                delegate: this,
                node: widget.node,
                editorConfig: editorState,
                textAlign:
                    alignment?.toTextAlign ?? blockStyle.alignment ?? textAlign,
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
      ),
    );

    child = Container(
      decoration: blockStyle.applyToDecoration(decoration),
      key: blockComponentKey,
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

class _QuoteIcon extends StatelessWidget {
  const _QuoteIcon();

  @override
  Widget build(BuildContext context) {
    final textScaleFactor =
        context.read<EditorState>().editorStyle.textScaleFactor;
    return Container(
      alignment: Alignment.center,
      constraints:
          const BoxConstraints(minWidth: 26, minHeight: 22) * textScaleFactor,
      padding: const EdgeInsets.only(right: 4.0),
      child: Container(
        width: 4 * textScaleFactor,
        color: '#00BCF0'.tryToColor(),
      ),
    );
  }
}
