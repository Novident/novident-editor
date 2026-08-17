import 'package:flutter/material.dart';
import 'package:novident_editor/novident_editor.dart';

class TableDefaults {
  const TableDefaults._();

  static double colDefaultWeight = kDefaultTableStyle.colDefaultWeight;

  @Deprecated('Use colDefaultWeight instead')
  static double colWidth = 160.0;

  static double rowHeight = kDefaultTableStyle.rowDefaultHeight;

  static double colMinimumWidth = kDefaultTableStyle.colMinimumWidth;

  static double borderWidth = kDefaultTableStyle.borderWidth;

  /// See [TableStyle.cellVerticalPadding].
  static double cellVerticalPadding = kDefaultTableStyle.cellVerticalPadding;

  static final Color borderColor =
      kDefaultTableStyle.borderColor ?? Colors.grey;

  static final Color borderHoverColor =
      kDefaultTableStyle.borderColor ?? Colors.blue;

  static const Widget addIcon = Icon(Icons.add, size: 20);

  static const Widget handlerIcon = Icon(Icons.drag_indicator);
}
