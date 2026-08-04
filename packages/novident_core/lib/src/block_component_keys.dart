/// Shared block component key constants — usable by both the editor
/// and standalone packages without editor dependencies.

// Base constants used by many block components.
const blockComponentDelta = 'delta';
const blockComponentBackgroundColor = 'bgColor';
const blockComponentTextDirection = 'textDirection';
const blockComponentTextDirectionAuto = 'auto';
const blockComponentTextDirectionLTR = 'ltr';
const blockComponentTextDirectionRTL = 'rtl';
const blockComponentAlign = 'align';
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
  static const String level = 'level';
  static const String delta = blockComponentDelta;
  static const String backgroundColor = blockComponentBackgroundColor;
  static const String textDirection = blockComponentTextDirection;
}

class TableBlockKeys {
  const TableBlockKeys._();
  static const String type = 'table';
  static const String colDefaultWeight = 'colDefaultWeight';
  static const String colDefaultWidth = 'colDefaultWidth';
  static const String rowDefaultHeight = 'rowDefaultHeight';
  static const String colMinimumWidth = 'colMinimumWidth';
  static const String borderWidth = 'borderWidth';
  static const String colsLen = 'colsLen';
  static const String rowsLen = 'rowsLen';
  static const String colsHeight = 'colsHeight';
  static const String enableHorizontalScroll = 'enableHorizontalScroll';
  static const String borderColor = 'borderColor';
}

class TableCellBlockKeys {
  const TableCellBlockKeys._();
  static const String type = 'table/cell';
  static const String rowPosition = 'rowPosition';
  static const String colPosition = 'colPosition';
  static const String height = 'height';
  static const String colWeight = 'colWeight';
  static const String width = 'width';
  static const String rowBackgroundColor = 'rowBackgroundColor';
  static const String colBackgroundColor = 'colBackgroundColor';
  static const String cellPadding = 'cellPadding';
  static const String cellAlignment = 'cellAlignment';
  static const String cellVerticalAlignment = 'cellVerticalAlignment';
  static const String cellTextOverflow = 'cellTextOverflow';
  static const String cellBackgroundColor = 'cellBackgroundColor';
}

class DividerBlockKeys {
  const DividerBlockKeys._();
  static const String type = 'divider';
}

class ImageBlockKeys {
  const ImageBlockKeys._();
  static const String type = 'image';
  static const String align = 'align';
  static const String url = 'url';
  static const String width = 'width';
  static const String height = 'height';
}

class TodoListBlockKeys {
  const TodoListBlockKeys._();
  static const String type = 'todo_list';
  static const String checked = 'checked';
  static const String delta = blockComponentDelta;
  static const String backgroundColor = blockComponentBackgroundColor;
  static const String textDirection = blockComponentTextDirection;
}

class QuoteBlockKeys {
  const QuoteBlockKeys._();
  static const String type = 'quote';
  static const String delta = blockComponentDelta;
  static const String backgroundColor = blockComponentBackgroundColor;
  static const String textDirection = blockComponentTextDirection;
}

class BulletedListBlockKeys {
  const BulletedListBlockKeys._();
  static const String type = 'bulleted_list';
  static const String delta = blockComponentDelta;
  static const String backgroundColor = blockComponentBackgroundColor;
  static const String textDirection = blockComponentTextDirection;
}

class NumberedListBlockKeys {
  const NumberedListBlockKeys._();
  static const String type = 'numbered_list';
  static const String number = 'number';
  static const String delta = blockComponentDelta;
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
