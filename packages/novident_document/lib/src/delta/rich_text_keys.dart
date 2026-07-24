/// Well-known rich-text attribute keys used by the Delta operations.
///
/// These constants define the attribute names shared between the document
/// model and editor rendering layer.
class RichTextKeys {
  RichTextKeys._();

  static String bold = 'bold';
  static String italic = 'italic';
  static String underline = 'underline';
  static String strikethrough = 'strikethrough';
  static String textColor = 'font_color';
  static String backgroundColor = 'bg_color';
  static String findBackgroundColor = 'find_bg_color';
  static String code = 'code';
  static String href = 'href';
  static String fontFamily = 'font_family';
  static String fontSize = 'font_size';
  static String autoComplete = 'auto_complete';
  static String transparent = 'transparent';

  /// The attributes supported sliced.
  static List<String> supportSliced = [
    bold,
    italic,
    underline,
    strikethrough,
    textColor,
    backgroundColor,
    code,
  ];

  /// The attributes is partially supported sliced.
  ///
  /// For the code and href attributes, the slice attributes function will
  /// only work if the index is in the range of the code or href.
  static List<String> partialSliced = [
    code,
    href,
  ];

  /// The values supported toggled even if the selection is collapsed.
  static List<String> supportToggled = [
    bold,
    italic,
    underline,
    strikethrough,
    code,
    fontFamily,
    textColor,
    backgroundColor,
  ];
}
