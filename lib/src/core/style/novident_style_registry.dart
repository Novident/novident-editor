import 'package:flutter/foundation.dart';

import 'novident_style_definition.dart';
import 'novident_table_style_definition.dart';

/// Immutable registry of [NovidentStyleDefinition] keyed by [NovidentStyleDefinition.id].
///
/// Style resolution walks the [NovidentStyleDefinition.basedOn] chain
/// to produce a fully resolved merged style or returns the raw definition
/// when no [basedOn] is set.
class NovidentStyleRegistry {
  NovidentStyleRegistry(Map<String, NovidentStyleDefinition> styles)
      : _styles = Map.unmodifiable(styles);

  final Map<String, NovidentStyleDefinition> _styles;

  Map<String, NovidentStyleDefinition> get styles => _styles;

  /// Looks up a style by [id].
  NovidentStyleDefinition? operator [](String id) => _styles[id];

  /// Resolves a style by [id], walking the [basedOn] chain and merging all
  /// ancestor styles into a single [NovidentStyleDefinition].
  ///
  /// Returns `null` when the style ID is not registered.
  /// Cyclic [basedOn] references are detected and broken.
  NovidentStyleDefinition? resolve(String id) {
    final definition = _styles[id];
    if (definition == null) return null;
    return _resolveChain(definition, <String>{});
  }

  NovidentStyleDefinition _resolveChain(
    NovidentStyleDefinition definition,
    Set<String> visited,
  ) {
    final basedOnId = definition.basedOn;
    if (basedOnId == null) return definition;

    if (visited.contains(basedOnId)) {
      debugPrint(
        'NovidentStyleRegistry: cyclic basedOn reference detected '
        'in style "${definition.id}" → "$basedOnId". Breaking chain.',
      );
      return definition;
    }

    final parent = _styles[basedOnId];
    if (parent == null) return definition;

    visited.add(basedOnId);
    final resolvedParent = _resolveChain(parent, visited);

    // Use the table-aware merge when the base is a table style.
    if (resolvedParent is NovidentTableStyleDefinition) {
      return resolvedParent.mergeTable(definition);
    }
    return resolvedParent.merge(definition);
  }

  /// Returns a new [NovidentStyleRegistry] with [styles] added/overridden.
  NovidentStyleRegistry copyWith(Map<String, NovidentStyleDefinition> styles) {
    final merged = Map<String, NovidentStyleDefinition>.from(_styles);
    merged.addAll(styles);
    return NovidentStyleRegistry(merged);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NovidentStyleRegistry &&
          mapEquals(other._styles, _styles);

  @override
  int get hashCode => _styles.hashCode;
}
