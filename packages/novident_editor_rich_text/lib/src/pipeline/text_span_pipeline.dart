import 'package:flutter/material.dart';
import 'package:novident_editor_core/novident_editor_core.dart';
import 'package:novident_editor_document/novident_editor_document.dart';

import 'contexts.dart';

/// Builds the text content of a [NovidentRichText] node.
///
/// The widget orchestrates the phases in this order and only delegates the
/// *content* decisions here; layout, caret, geometry and selection
/// bookkeeping stay in the widget:
///
/// ```
/// per TextInsert:  1 resolveStyle → 2 transformText → 3 emitSpans
/// per node:        4 paintSelectionContrast (over the emitted spans)
/// placeholder:     5 buildPlaceholder
/// per node:        6 adjustSpan (over the root span)
/// ```
///
/// Implementations must be stateless w.r.t. the phases: the widget may call
/// any phase any number of times per build.
///
/// [DefaultNovidentTextSpanPipeline] reproduces the legacy behavior exactly,
/// including the legacy decorator callbacks.
abstract class NovidentTextSpanPipeline {
  const NovidentTextSpanPipeline();

  /// Phase 1 — converts a [TextInsert]'s attributes into a [TextStyle]
  /// combined over [base]. Replaces the legacy `_attributesToStyle`.
  ///
  /// [node] and [context] are optional and may be `null` when resolving
  /// outside a widget build (e.g. pure unit tests). Implementations that
  /// need to react to the node or its surroundings (e.g. zen-mode color
  /// dimming) can use them; the default pipeline ignores them.
  TextStyle resolveStyle(
    Attributes? attributes,
    TextStyle base,
    TextStyleConfiguration textStyleConfiguration, {
    Node? node,
    BuildContext? context,
  });

  /// Phase 2 — textual transformation before rendering (caps/smallCaps).
  ///
  /// Must NOT change the text length in UTF-16 code units: document offsets
  /// are measured on the original text.
  String transformText(
    TextInsert insert,
    String displayText, {
    required bool caps,
    required bool smallCaps,
  });

  /// Phase 3 — emits the spans of a single [TextInsert].
  ///
  /// Returns a list to allow splitting the text (spell-check marking,
  /// syntax highlighting, mentions...). The returned spans must cover
  /// `displayText` exactly: their UTF-16 lengths must sum to
  /// `displayText.length`.
  List<InlineSpan> emitSpans(SpanEmitContext context);

  /// Phase 4 — applies selection contrast over the spans already emitted
  /// by phase 3. Must preserve the style of non-selected pieces and of
  /// non-[TextSpan] spans.
  List<InlineSpan> paintSelectionContrast(SelectionContrastContext context);

  /// Phase 5 — builds the placeholder span of an empty node.
  TextSpan buildPlaceholder(PlaceholderContext context);

  /// Phase 6 — final adjustment of the root span (caret-height workaround
  /// in the legacy implementation).
  TextSpan adjustSpan(AdjustSpanContext context);
}
