/// the delta of the block component
///
/// its value is a string of json format, e.g. '{"insert":"Hello World"}'
/// for more information, please refer to https://quilljs.com/docs/delta/
const blockComponentDelta = 'delta';

/// the TextDocument of the block component
///
/// its value is a string of json format, e.g. '{"v": 1, "c": [{"t": "Hello World"}]}'
const blockComponentTextDocument = 'td';

/// the background of the block component
///
/// its value is a string of hex code, e.g. '#00000000'
const blockComponentBackgroundColor = 'bgColor';

/// the text direction of the block component
///
/// its value must be one of the following:
///   - [blockComponentTextDirectionLTR] or 'ltr': left to right
///   - [blockComponentTextDirectionRTL] or 'rtl': right to left
///   - [blockComponentTextDirectionAuto] or auto: depends on the text
///
/// only works for the block with text,
///   e.g. paragraph, heading, quote, to-do list, bulleted list, numbered list
const blockComponentTextDirection = 'textDirection';
const blockComponentTextDirectionAuto = 'auto';
const blockComponentTextDirectionLTR = 'ltr';
const blockComponentTextDirectionRTL = 'rtl';

/// text align
///
/// its value must be one of the following:
///  - left, right, center.
const blockComponentAlign = 'align';

/// References a [NovidentStyleDefinition.id] to apply reusable formatting
/// to this block. Resolved via [NovidentEditorStyles].
const blockComponentStyleRef = 'styleRef';

class ParagraphBlockKeys {
  ParagraphBlockKeys._();
  static const String type = 'paragraph';
  static const String delta = blockComponentDelta;
  static const String backgroundColor = blockComponentBackgroundColor;
  static const String textDirection = blockComponentTextDirection;
}

class HeadingBlockKeys {
  const HeadingBlockKeys._();

  static const String type = 'heading';

  /// The level data of a heading block.
  ///
  /// The value is a int.
  static const String level = 'level';

  @Deprecated("Use textDoc instead")
  static const String delta = blockComponentDelta;
  static const String textDoc = blockComponentTextDocument;

  static const String backgroundColor = blockComponentBackgroundColor;

  static const String textDirection = blockComponentTextDirection;
}

class TableBlockKeys {
  const TableBlockKeys._();

  static const String type = 'table';

  /// Default column weight applied to columns without an explicit
  /// [TableCellBlockKeys.colWeight] attribute.
  static const String colDefaultWeight = 'colDefaultWeight';

  /// Legacy absolute pixel width. Kept for backward compatibility; layout
  /// now uses [colDefaultWeight] and [TableCellBlockKeys.colWeight].
  static const String colDefaultWidth = 'colDefaultWidth';

  static const String rowDefaultHeight = 'rowDefaultHeight';

  static const String colMinimumWidth = 'colMinimumWidth';

  static const String borderWidth = 'borderWidth';

  static const String colsLen = 'colsLen';

  static const String rowsLen = 'rowsLen';

  static const String colsHeight = 'colsHeight';

  /// Per-table override of [TableStyle.enableHorizontalScroll].
  ///
  /// When the attribute is absent, the style value is used. Set it through
  /// [TableActions.setEnableHorizontalScroll].
  static const String enableHorizontalScroll = 'enableHorizontalScroll';

  /// Per-table override of [TableStyle.borderColor], stored as a hex color
  /// string (e.g. `0xFF9C27B0`).
  ///
  /// When the attribute is absent, the style value is used. Set it through
  /// [TableActions.setBorderColor].
  static const String borderColor = 'borderColor';
}

class TableCellBlockKeys {
  const TableCellBlockKeys._();

  static const String type = 'table/cell';

  static const String rowPosition = 'rowPosition';

  static const String colPosition = 'colPosition';

  static const String height = 'height';

  /// Relative weight of the column this cell belongs to.
  ///
  /// Columns with higher [colWeight] get proportionally more horizontal
  /// space. A column without an explicit [colWeight] defaults to 1.0.
  ///
  /// Replaces the legacy [width] attribute for layout purposes, though
  /// [width] is still stored for backward compatibility.
  static const String colWeight = 'colWeight';

  /// Legacy absolute pixel width. Still written by the resize logic for
  /// backward compatibility, but no longer used for layout. Use [colWeight]
  /// instead.
  static const String width = 'width';

  static const String rowBackgroundColor = 'rowBackgroundColor';

  static const String colBackgroundColor = 'colBackgroundColor';

  /// Per-cell padding override. Map with `top`, `bottom`,
  /// `left`, `right` double values.
  static const String cellPadding = 'cellPadding';

  /// Horizontal text alignment for this cell. Stored as String
  /// matching [TextAlign] enum values.
  static const String cellAlignment = 'cellAlignment';

  /// Vertical content alignment. Stored as String matching
  /// [CrossAxisAlignment] enum values.
  static const String cellVerticalAlignment = 'cellVerticalAlignment';

  /// Text overflow behavior. Stored as String matching
  /// [TextOverflow] enum values.
  static const String cellTextOverflow = 'cellTextOverflow';

  /// Background color override for this specific cell (overrides
  /// row/col/even-odd striping). Stored as hex String.
  static const String cellBackgroundColor = 'cellBackgroundColor';
}

class DividerBlockKeys {
  const DividerBlockKeys._();

  static const String type = 'divider';
}

class ImageBlockKeys {
  const ImageBlockKeys._();

  static const String type = 'image';

  /// The align data of a image block.
  ///
  /// The value is a String.
  /// left, center, right
  static const String align = 'align';

  /// The image src of a image block.
  ///
  /// The value is a String.
  /// It can be a url or a base64 string(web).
  static const String url = 'url';

  /// The height of a image block.
  ///
  /// The value is a double.
  static const String width = 'width';

  /// The width of a image block.
  ///
  /// The value is a double.
  static const String height = 'height';
}

class TodoListBlockKeys {
  const TodoListBlockKeys._();

  static const String type = 'todo_list';

  /// The checked data of a todo list block.
  ///
  /// The value is a boolean.
  static const String checked = 'checked';

  @Deprecated("Use textDoc instead")
  static const String delta = blockComponentDelta;
  static const String textDoc = blockComponentTextDocument;

  static const String backgroundColor = blockComponentBackgroundColor;

  static const String textDirection = blockComponentTextDirection;
}

class QuoteBlockKeys {
  const QuoteBlockKeys._();
  static const String type = 'quote';
  @Deprecated("Use textDoc instead")
  static const String delta = blockComponentDelta;
  static const String textDoc = blockComponentTextDocument;
  static const String backgroundColor = blockComponentBackgroundColor;
  static const String textDirection = blockComponentTextDirection;
}

class BulletedListBlockKeys {
  const BulletedListBlockKeys._();

  static const String type = 'bulleted_list';

  @Deprecated("Use textDoc instead")
  static const String delta = blockComponentDelta;
  static const String textDoc = blockComponentTextDocument;

  static const String backgroundColor = blockComponentBackgroundColor;

  static const String textDirection = blockComponentTextDirection;
}

class NumberedListBlockKeys {
  const NumberedListBlockKeys._();
  static const String type = 'numbered_list';
  static const String number = 'number';
  @Deprecated("Use textDoc instead")
  static const String delta = blockComponentDelta;
  static const String textDoc = blockComponentTextDocument;
  static const String backgroundColor = blockComponentBackgroundColor;
  static const String textDirection = blockComponentTextDirection;
}

class PageBlockKeys {
  static const String type = 'page';
}

class ColumnBlockKeys {
  const ColumnBlockKeys._();

  static const String type = 'column';

  static const String width = 'width';
}

class ColumnsBlockKeys {
  const ColumnsBlockKeys._();

  static const String type = 'columns';

  static const String columnCount = 'column_count';
}
