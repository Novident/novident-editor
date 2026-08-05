import 'package:novident_editor/novident_editor.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

Node headingNode({
  required int level,
  String? text,
  Delta? delta,
  String? textDirection,
  Attributes? attributes,
  String? styleRef,
}) {
  assert(level >= 1 && level <= 6);
  return Node(
    type: HeadingBlockKeys.type,
    attributes: {
      HeadingBlockKeys.delta: (delta ?? (Delta()..insert(text ?? ''))).toJson(),
      HeadingBlockKeys.level: level.clamp(1, 6),
      if (attributes != null) ...attributes,
      if (styleRef != null) blockComponentStyleRef: styleRef,
      if (textDirection != null) HeadingBlockKeys.textDirection: textDirection,
    },
  );
}

class HeadingBlockComponentBuilder extends BlockComponentBuilder {
  HeadingBlockComponentBuilder({
    super.configuration,
    this.textStyleBuilder,
  });

  /// The text style of the heading block.
  final TextStyle Function(int level)? textStyleBuilder;

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return HeadingBlockComponentWidget(
      key: node.key,
      node: node,
      configuration: configuration,
      textStyleBuilder: textStyleBuilder,
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
}

class HeadingBlockComponentWidget extends BlockComponentStatefulWidget {
  const HeadingBlockComponentWidget({
    super.key,
    required super.node,
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
    super.configuration = const BlockComponentConfiguration(),
    this.textStyleBuilder,
  });

  /// The text style of the heading block.
  final TextStyle Function(int level)? textStyleBuilder;

  @override
  State<HeadingBlockComponentWidget> createState() =>
      _HeadingBlockComponentWidgetState();
}

class _HeadingBlockComponentWidgetState
    extends State<HeadingBlockComponentWidget>
    with
        SelectableMixin,
        DefaultSelectableMixin,
        BlockComponentConfigurable,
        BlockComponentBackgroundColorMixin,
        BlockComponentTextDirectionMixin,
        BlockComponentAlignMixin {
  @override
  final forwardKey = GlobalKey(debugLabel: 'flowy_rich_text');

  @override
  GlobalKey<State<StatefulWidget>> get containerKey => widget.node.key;

  @override
  GlobalKey<State<StatefulWidget>> blockComponentKey = GlobalKey(
    debugLabel: HeadingBlockKeys.type,
  );

  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;

  @override
  late final editorState = Provider.of<EditorState>(context, listen: false);

  int get level => widget.node.attributes[HeadingBlockKeys.level] as int? ?? 1;

  @override
  Widget build(BuildContext context) {
    final textDirection = calculateTextDirection(
      layoutDirection: Directionality.maybeOf(context),
    );

    final blockStyle =
        NovidentBlockStyleResolver.resolve(context, widget.node);

    Widget child = Container(
      width: double.infinity,
      alignment: alignment,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        textDirection: textDirection,
        children: [
          Flexible(
            child: NovidentRichText(
              key: forwardKey,
              delegate: this,
              node: widget.node,
              editorConfig: editorState,
              textAlign: blockStyle.alignment ??
                  alignment?.toTextAlign ??
                  textAlign,
              useFirstLineIndent: false,
              textSpanDecorator: (textSpan) {
                var result = textSpan.updateTextStyle(
                  textStyleWithTextSpan(textSpan: textSpan),
                );
                result = result.updateTextStyle(
                  widget.textStyleBuilder?.call(level) ??
                      defaultTextStyle(level),
                );
                return result;
              },
              placeholderText: placeholderText,
              placeholderTextSpanDecorator: (textSpan) => textSpan
                  .updateTextStyle(
                    widget.textStyleBuilder?.call(level) ??
                        defaultTextStyle(level),
                  )
                  .updateTextStyle(
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

    child = BlockSelectionContainer(
      node: node,
      key: blockComponentKey,
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

    final effectivePadding = blockStyle.applyToPadding(padding);
    final effectiveDecoration = blockStyle.applyToDecoration(decoration);

    child = Container(
      padding: effectivePadding,
      decoration: effectiveDecoration,
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

  TextStyle? defaultTextStyle(int level) {
    final fontSizes = [32.0, 28.0, 24.0, 18.0, 18.0, 18.0];
    final fontSize = fontSizes.elementAtOrNull(level) ?? 18.0;
    return TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
    );
  }
}
