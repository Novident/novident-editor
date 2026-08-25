import 'package:novident_editor/novident_editor.dart';
import 'package:flutter/material.dart';

mixin BlockComponentAlignMixin {
  Node get node;

  Alignment? get alignment {
    final alignString = node.attributes[blockComponentAlign] as String?;
    switch (alignString) {
      case 'center':
        return Alignment.center;
      case 'right':
        return Alignment.centerRight;
      case 'left':
      case 'justify':
        return Alignment.centerLeft;
      default:
        return null;
    }
  }

  TextAlign? get nodeTextAlign {
    final alignString = node.attributes[blockComponentAlign] as String?;
    switch (alignString) {
      case 'center':
        return TextAlign.center;
      case 'right':
        return TextAlign.end;
      case 'justify':
        return TextAlign.justify;
      case 'left':
        return TextAlign.start;
      default:
        return null;
    }
  }
}
