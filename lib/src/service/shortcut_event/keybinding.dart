import 'dart:convert';

import 'package:novident_editor/src/service/shortcut_event/key_mapping.dart';
import 'package:flutter/services.dart';

/// Maps single-character symbols (used in vim keybindings) to their
/// Flutter logical key names, so [Keybinding.keyCode] can look them up
/// in [keyToCodeMapping].
final _charToKeyName = {
  '{': 'brace left',
  '}': 'brace right',
  '[': 'bracket left',
  ']': 'bracket right',
  '(': 'parenthesis left',
  ')': 'parenthesis right',
  '\$': 'dollar',
  '!': 'exclamation',
  '#': 'number sign',
  '%': 'percent',
  '^': 'caret',
  '&': 'ampersand',
  '*': 'asterisk',
  '-': 'minus',
  '+': 'add',
  '=': 'equal',
  '~': 'tilde',
  '`': 'backquote',
  "'": 'quote',
  '"': 'quote',
  ':': 'colon',
  ';': 'semicolon',
  '<': 'less',
  '>': 'greater',
  ',': 'comma',
  '.': 'period',
  '/': 'slash',
  '?': 'question',
  '\\': 'backslash',
  '|': 'bar',
  ' ': 'space',
  '@': 'at',
  '_': 'underscore',
  '0': 'digit 0',
  '1': 'digit 1',
  '2': 'digit 2',
  '3': 'digit 3',
  '4': 'digit 4',
  '5': 'digit 5',
  '6': 'digit 6',
  '7': 'digit 7',
  '8': 'digit 8',
  '9': 'digit 9',
};

/// Translates a raw command token into the key-label form expected by
/// [keyToCodeMapping].  Single-character symbols (e.g. `{`) become their
/// key name (e.g. `brace left`); everything else stays as-is.
String _normalizeKeyLabel(String raw) {
  return _charToKeyName[raw.toLowerCase()] ?? raw;
}

extension KeybindingsExtension on List<Keybinding> {
  bool containsKeyEvent(KeyEvent keyEvent) {
    for (final keybinding in this) {
      final keyCode = keybinding.keyCode;
      if (keyCode == null) continue;
      if (keybinding.isMetaPressed == HardwareKeyboard.instance.isMetaPressed &&
          keybinding.isControlPressed ==
              HardwareKeyboard.instance.isControlPressed &&
          keybinding.isAltPressed == HardwareKeyboard.instance.isAltPressed &&
          keybinding.isShiftPressed ==
              HardwareKeyboard.instance.isShiftPressed &&
          keyCode == keyEvent.logicalKey.keyId) {
        return true;
      }
    }
    return false;
  }
}

class Keybinding {
  Keybinding({
    required this.isAltPressed,
    required this.isControlPressed,
    required this.isMetaPressed,
    required this.isShiftPressed,
    required this.keyLabel,
  });

  factory Keybinding.parse(String command) {
    command = command.toLowerCase().trim();

    var isAltPressed = false;
    var isControlPressed = false;
    var isMetaPressed = false;
    var isShiftPressed = false;

    var matchedModifier = false;

    do {
      matchedModifier = false;
      if (RegExp(r'^alt(\+|\-)').hasMatch(command)) {
        isAltPressed = true;
        command = command.substring(4); // 4 = 'alt '.length
        matchedModifier = true;
      }
      if (RegExp(r'^ctrl(\+|\-)').hasMatch(command)) {
        isControlPressed = true;
        command = command.substring(5); // 5 = 'ctrl '.length
        matchedModifier = true;
      }
      if (RegExp(r'^shift(\+|\-)').hasMatch(command)) {
        isShiftPressed = true;
        command = command.substring(6); // 6 = 'shift '.length
        matchedModifier = true;
      }
      if (RegExp(r'^meta(\+|\-)').hasMatch(command)) {
        isMetaPressed = true;
        command = command.substring(5); // 5 = 'meta '.length
        matchedModifier = true;
      }
      if (RegExp(r'^cmd(\+|\-)').hasMatch(command) ||
          RegExp(r'^win(\+|\-)').hasMatch(command)) {
        isMetaPressed = true;
        command = command.substring(4); // 4 = 'win '.length
        matchedModifier = true;
      }
    } while (matchedModifier);

    return Keybinding(
      isAltPressed: isAltPressed,
      isControlPressed: isControlPressed,
      isMetaPressed: isMetaPressed,
      isShiftPressed: isShiftPressed,
      keyLabel: _normalizeKeyLabel(command),
    );
  }

  final bool isAltPressed;
  final bool isControlPressed;
  final bool isMetaPressed;
  final bool isShiftPressed;
  final String keyLabel;

  int? get keyCode => keyToCodeMapping[keyLabel.toLowerCase()];

  Keybinding copyWith({
    bool? isAltPressed,
    bool? isControlPressed,
    bool? isMetaPressed,
    bool? isShiftPressed,
    String? keyLabel,
  }) {
    return Keybinding(
      isAltPressed: isAltPressed ?? this.isAltPressed,
      isControlPressed: isControlPressed ?? this.isControlPressed,
      isMetaPressed: isMetaPressed ?? this.isMetaPressed,
      isShiftPressed: isShiftPressed ?? this.isShiftPressed,
      keyLabel: keyLabel ?? this.keyLabel,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isAltPressed': isAltPressed,
      'isControlPressed': isControlPressed,
      'isMetaPressed': isMetaPressed,
      'isShiftPressed': isShiftPressed,
      'keyLabel': keyLabel,
    };
  }

  factory Keybinding.fromMap(Map<String, dynamic> map) {
    return Keybinding(
      isAltPressed: map['isAltPressed'] ?? false,
      isControlPressed: map['isControlPressed'] ?? false,
      isMetaPressed: map['isMetaPressed'] ?? false,
      isShiftPressed: map['isShiftPressed'] ?? false,
      keyLabel: map['keyLabel'] ?? '',
    );
  }

  String toJson() => json.encode(toMap());

  factory Keybinding.fromJson(String source) =>
      Keybinding.fromMap(json.decode(source));

  @override
  String toString() {
    return 'Keybinding(isAltPressed: $isAltPressed, isControlPressed: $isControlPressed, isMetaPressed: $isMetaPressed, isShiftPressed: $isShiftPressed, keyLabel: $keyLabel)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Keybinding &&
        other.isAltPressed == isAltPressed &&
        other.isControlPressed == isControlPressed &&
        other.isMetaPressed == isMetaPressed &&
        other.isShiftPressed == isShiftPressed &&
        other.keyLabel == keyLabel;
  }

  @override
  int get hashCode {
    return isAltPressed.hashCode ^
        isControlPressed.hashCode ^
        isMetaPressed.hashCode ^
        isShiftPressed.hashCode ^
        keyLabel.hashCode;
  }
}
