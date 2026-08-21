import 'package:novident_editor/novident_editor.dart';
import 'package:flutter/material.dart';

Node paragraphNode({
  String? text,
  Delta? delta,
  String? textDirection,
  Attributes? attributes,
  String? styleRef,
  Iterable<Node> children = const [],
}) {
  return Node(
    type: ParagraphBlockKeys.type,
    attributes: {
      ParagraphBlockKeys.delta:
          (delta ?? (Delta()..insert(text ?? ''))).toJson(),
      if (attributes != null) ...attributes,
      if (styleRef != null) blockComponentStyleRef: styleRef,
      if (textDirection != null)
        ParagraphBlockKeys.textDirection: textDirection,
    },
    children: children,
  );
}

typedef ShowPlaceholder = bool Function(EditorState editorState, Node node);

class ParagraphBlockComponentBuilder extends BlockComponentBuilder {
  ParagraphBlockComponentBuilder({
    super.configuration,
    this.showPlaceholder,
  });

  final ShowPlaceholder? showPlaceholder;

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return ParagraphBlockComponentWidget(
      node: node,
      key: node.key,
      configuration: configuration,
      showActions: showActions(node),
      showPlaceholder: showPlaceholder,
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

class ParagraphBlockComponentWidget extends BlockComponentStatefulWidget {
  const ParagraphBlockComponentWidget({
    super.key,
    required super.node,
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
    super.configuration = const BlockComponentConfiguration(),
    this.showPlaceholder,
  });

  final ShowPlaceholder? showPlaceholder;

  @override
  State<ParagraphBlockComponentWidget> createState() =>
      _ParagraphBlockComponentWidgetState();
}

class _ParagraphBlockComponentWidgetState
    extends State<ParagraphBlockComponentWidget>
    with
        SelectableMixin,
        DefaultSelectableMixin,
        BlockComponentConfigurable,
        BlockComponentBackgroundColorMixin,
        NestedBlockComponentStatefulWidgetMixin,
        BlockComponentTextDirectionMixin,
        BlockComponentAlignMixin {
  @override
  final forwardKey = GlobalKey(debugLabel: 'rich_text');

  @override
  GlobalKey<State<StatefulWidget>> get containerKey => widget.node.key;

  @override
  GlobalKey<State<StatefulWidget>> blockComponentKey = GlobalKey(
    debugLabel: ParagraphBlockKeys.type,
  );

  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;

  bool _showPlaceholder = false;

  @override
  void initState() {
    super.initState();
    editorState.selectionNotifier.addListener(_onSelectionChange);
    _onSelectionChange();
  }

  @override
  void dispose() {
    editorState.selectionNotifier.removeListener(_onSelectionChange);
    super.dispose();
  }

  void _onSelectionChange() {
    final selection = editorState.selection;

    if (widget.showPlaceholder != null) {
      setState(() {
        _showPlaceholder = widget.showPlaceholder!(editorState, node);
      });
    } else {
      final showPlaceholder = selection != null &&
          (selection.isSingle && selection.start.path.equals(node.path));
      if (showPlaceholder != _showPlaceholder) {
        setState(() => _showPlaceholder = showPlaceholder);
      }
    }
  }

  @override
  Widget buildComponent(
    BuildContext context, {
    bool withBackgroundColor = true,
  }) {
    final textDirection = calculateTextDirection(
      layoutDirection: Directionality.maybeOf(context),
    );

    final blockStyle = NovidentBlockStyleResolver.resolve(
      context,
      widget.node,
    );
    final effectivePadding = blockStyle.applyToPadding(padding);
    //TODO: alignment.toTextAlign should be replaced
    // by another method or enum that supports jutify alignment
    final effectiveTextAlign =
        alignment?.toTextAlign ?? blockStyle.alignment ?? textAlign;

    Widget child = Container(
      width: double.infinity,
      alignment: alignment,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        textDirection: textDirection,
        children: [
          NovidentRichText(
            key: forwardKey,
            delegate: this,
            node: widget.node,
            editorConfig: editorState,
            textAlign: effectiveTextAlign,
            placeholderText: _showPlaceholder ? placeholderText : ' ',
            textDirection: textDirection,
            cursorColor: editorState.editorStyle.cursorColor,
            selectionColor: editorState.editorStyle.selectionColor,
            cursorWidth: editorState.editorStyle.cursorWidth,
          ),
        ],
      ),
    );

    var effectiveDecoration = withBackgroundColor ? decoration : null;
    effectiveDecoration = blockStyle.applyToDecoration(effectiveDecoration);

    child = Padding(
      key: blockComponentKey,
      padding: effectivePadding,
      // ignore: use_decorated_box
      child: Container(
        decoration: effectiveDecoration,
        child: child,
      ),
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
