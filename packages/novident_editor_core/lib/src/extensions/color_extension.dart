import 'package:flutter/material.dart';

const _rgbRegexPattern = r'^rgb\((\d+),\s*(\d+),\s*(\d+)\)$';
const _rgbaRegexPattern = r'^rgba\((\d+),\s*(\d+),\s*(\d+),\s*([\d.]+)\)$';
const _hexRegexPattern = r'^(0x|#)([0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$';

final _rgbRegex = RegExp(_rgbRegexPattern);
final _rgbaRegex = RegExp(_rgbaRegexPattern);
final _hexRegex = RegExp(_hexRegexPattern);

final _colorCache = <String, Color?>{};

extension ColorExtension on String {
  Color? tryToColor() {
    return _colorCache.putIfAbsent(this, _tryToColorUncached);
  }

  Color? _tryToColorUncached() {
    if (_rgbRegex.hasMatch(this)) {
      final match = _rgbRegex.firstMatch(this);
      if (match != null && match.groupCount == 3) {
        final r = int.tryParse(match.group(1)!);
        final g = int.tryParse(match.group(2)!);
        final b = int.tryParse(match.group(3)!);
        if (r != null && g != null && b != null) {
          return Color.fromARGB(255, r, g, b);
        }
      }
    } else if (_rgbaRegex.hasMatch(this)) {
      final match = _rgbaRegex.firstMatch(this);
      if (match != null && match.groupCount == 4) {
        final r = int.tryParse(match.group(1)!);
        final g = int.tryParse(match.group(2)!);
        final b = int.tryParse(match.group(3)!);
        final a = double.tryParse(match.group(4)!);
        if (r != null && g != null && b != null && a != null) {
          return Color.fromARGB((a * 255).toInt(), r, g, b);
        }
      }
    } else if (_hexRegex.hasMatch(this)) {
      final match = _hexRegex.firstMatch(this);
      if (match != null && match.groupCount == 2) {
        final hexValue = int.tryParse(match.group(2)!, radix: 16);
        if (hexValue != null) {
          if (match.group(2)!.length == 6) {
            return Color(hexValue).withAlpha(255);
          } else {
            return Color(hexValue);
          }
        }
      }
    }

    return null;
  }
}

extension HexExtension on Color {
  String toHex() {
    final alpha = (a * 255).toInt().toRadixString(16).padLeft(2, '0');
    final red = (r * 255).toInt().toRadixString(16).padLeft(2, '0');
    final green = (g * 255).toInt().toRadixString(16).padLeft(2, '0');
    final blue = (b * 255).toInt().toRadixString(16).padLeft(2, '0');

    return '0x$alpha$red$green$blue'.toLowerCase();
  }
}
