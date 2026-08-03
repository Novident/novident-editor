import 'package:novident_editor_document/novident_editor_document.dart';
import 'package:novident_styles/src/editor_styles.dart';
import 'package:novident_styles/src/style_definition.dart';
import 'package:flutter/material.dart';

/// Resolved block-level layout properties from a [NovidentStyleDefinition].
///
/// Produced by [NovidentBlockStyleResolver] by merging style defaults
/// with per-type overrides and the node's own attributes.
class NovidentBlockStyleResolution {
  const NovidentBlockStyleResolution({
    this.spacingBefore,
    this.spacingAfter,
    this.leftIndent,
    this.rightIndent,
    this.border,
    this.keepNext = false,
    this.alignment,
    this.backgroundColor,
  });

  final double? spacingBefore;
  final double? spacingAfter;
  final double? leftIndent;
  final double? rightIndent;
  final Border? border;
  final bool keepNext;
  final TextAlign? alignment;
  final Color? backgroundColor;

  EdgeInsets applyToPadding(EdgeInsets base) {
    return base.copyWith(
      top: (base.top) + (spacingBefore ?? 0),
      bottom: (base.bottom) + (spacingAfter ?? 0),
      left: (base.left) + (leftIndent ?? 0),
      right: (base.right) + (rightIndent ?? 0),
    );
  }

  Decoration? applyToDecoration(Decoration? base) {
    final hasBorder = border != null;
    final hasBgColor = backgroundColor != null;
    if (!hasBorder && !hasBgColor) return base;

    final boxBase = base is BoxDecoration ? base : const BoxDecoration();
    return boxBase.copyWith(
      border: hasBorder ? border : boxBase.border,
      color: hasBgColor ? backgroundColor : boxBase.color,
    );
  }
}

/// Resolves block-level style properties for a [Node] from the
/// [NovidentEditorStyles] provided via the widget tree.
class NovidentBlockStyleResolver {
  const NovidentBlockStyleResolver._();

  static NovidentBlockStyleResolution resolve(
    BuildContext context,
    Node node,
  ) {
    final editorStyles = NovidentEditorStyles.maybeOf(context);
    final style = editorStyles?.resolveStyle(node);

    if (style == null) return const NovidentBlockStyleResolution();

    return NovidentBlockStyleResolution(
      spacingBefore: style.spacing?.before,
      spacingAfter: style.spacing?.after,
      leftIndent: style.indent?.left,
      rightIndent: style.indent?.right,
      border: style.borderStyle?.border,
      keepNext: style.keep?.keepNext ?? false,
      alignment: style.alignment,
      backgroundColor: style.blockBackgroundColor,
    );
  }
}
