Map<String, dynamic>? composeAttributes(
  Map<String, dynamic>? base,
  Map<String, dynamic>? other, {
  keepNull = false,
}) {
  base ??= {};
  other ??= {};
  Map<String, dynamic> attributes = {
    ...base,
    ...other,
  };

  if (!keepNull) {
    attributes = Map<String, dynamic>.from(attributes)
      ..removeWhere((_, value) => value == null);
  }

  return attributes.isNotEmpty ? attributes : null;
}

Map<String, dynamic> invertAttributes(Map<String, dynamic>? from, Map<String, dynamic>? to) {
  from ??= {};
  to ??= {};
  final attributes = Map<String, dynamic>.from({});

  // key in from but not in to, or value is different
  for (final entry in from.entries) {
    if ((!to.containsKey(entry.key) && entry.value != null) ||
        to[entry.key] != entry.value) {
      attributes[entry.key] = entry.value;
    }
  }

  // key in to but not in from, or value is different
  for (final entry in to.entries) {
    if (!from.containsKey(entry.key) && entry.value != null) {
      attributes[entry.key] = null;
    }
  }

  return attributes;
}

Map<String, dynamic>? diffAttributes(
  Map<String, dynamic>? from,
  Map<String, dynamic>? to,
) {
  from ??= const {};
  to ??= const {};
  final attributes = Map<String, dynamic>.from({});

  for (final key in (from.keys.toList()..addAll(to.keys))) {
    if (from[key] != to[key]) {
      attributes[key] = to.containsKey(key) ? to[key] : null;
    }
  }

  return attributes;
}

int hashAttributes(Map<String, dynamic> base) => Object.hashAllUnordered(
      base.entries.map((e) => Object.hash(e.key, e.value)),
    );
