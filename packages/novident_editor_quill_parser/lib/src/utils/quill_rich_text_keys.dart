/// Well-known attribute keys and values used on the **Quill side** of the
/// conversion (the output of `novident -> quill`, the input of the decoder).
///
/// These must not be confused with [RichTextKeys] from
/// `novident_editor_document`, which name the *novident* side of the same
/// concepts. For example, novident stores strikethrough as `strikethrough`
/// while Quill calls it `strike`, and novident's `font_color` maps to
/// Quill's `color`.
class QuillRichTextKeys {
  QuillRichTextKeys._();

  // --- block keys ---------------------------------------------------------

  static const String indent = 'indent';
  static const String heading = 'header';
  static const String list = 'list';
  static const String quote = 'blockquote';
  static const String align = 'align';
  static const String direction = 'direction';
  static const String codeBlock = 'code-block';

  // --- `list` values ------------------------------------------------------

  static const String unordered = 'bullet';
  static const String ordered = 'ordered';
  static const String checkedList = 'checked';
  static const String unCheckedList = 'unchecked';

  // --- inline keys --------------------------------------------------------

  static const String bold = 'bold';
  static const String italic = 'italic';
  static const String underline = 'underline';
  static const String strikethrough = 'strike';
  static const String textColor = 'color';
  static const String backgroundColor = 'background';
  static const String code = 'code';
  static const String href = 'link';
  static const String fontFamily = 'font';
  static const String fontSize = 'size';

  // --- embed keys ---------------------------------------------------------

  static const String image = 'image';
  static const String video = 'video';

  // --- image embed attribute keys -----------------------------------------

  static const String width = 'width';
  static const String height = 'height';
  static const String style = 'style';
}
