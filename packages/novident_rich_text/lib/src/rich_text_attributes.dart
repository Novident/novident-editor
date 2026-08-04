import 'package:flutter/material.dart';
import 'package:novident_core/novident_core.dart';
import 'package:novident_editor_document/novident_editor_document.dart';

/// Extension on [Attributes] for convenient access to rich text styling keys.
extension NovidentRichTextAttributes on Attributes {
  bool get bold => this[RichTextKeys.bold] == true;
  bool get italic => this[RichTextKeys.italic] == true;
  bool get underline => this[RichTextKeys.underline] == true;
  bool get code => this[RichTextKeys.code] == true;

  bool get strikethrough {
    return (containsKey(RichTextKeys.strikethrough) &&
        this[RichTextKeys.strikethrough] == true);
  }

  Color? get color {
    final textColor = this[RichTextKeys.textColor] as String?;
    return textColor?.tryToColor();
  }

  Color? get backgroundColor {
    final highlightColor =
        this[RichTextKeys.backgroundColor] as String?;
    return highlightColor?.tryToColor();
  }

  Color? get findBackgroundColor {
    final findBackgroundColor =
        this[RichTextKeys.findBackgroundColor] as String?;
    return findBackgroundColor?.tryToColor();
  }

  String? get href {
    if (this[RichTextKeys.href] is String) {
      return this[RichTextKeys.href];
    }
    return null;
  }

  String? get fontFamily {
    if (this[RichTextKeys.fontFamily] is String) {
      return this[RichTextKeys.fontFamily];
    }
    return null;
  }

  double? get fontSize {
    if (this[RichTextKeys.fontSize] is double) {
      return this[RichTextKeys.fontSize];
    }
    return null;
  }

  bool get autoComplete => this[RichTextKeys.autoComplete] == true;
  bool get transparent => this[RichTextKeys.transparent] == true;
}
