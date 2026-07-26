import 'package:novident_editor/src/core/style/novident_style_definition.dart';
import 'package:novident_editor/src/core/style/novident_style_registry.dart';

/// A sensible preset of styles modelled after Microsoft Word defaults.
///
/// Includes:
///   - [normal] — body text (16pt, 8pt spacing after)
///   - [heading-1] through [heading-6] with decreasing font sizes,
///     bold, and proportional spacing
///
/// Usage:
/// ```dart
/// NovidentEditor(
///   styles: NovidentEditorStyles(
///     registry: kDefaultStyleRegistry,
///     // fallback
///     defaultStyle: kDefaultBaseStyle,
///     defaultStylesByType: {
///       'paragraph': kNormalBodyStyle,
///       'heading': kDefaultHeadingStyles[0],
///     },
///   ),
/// )
/// ```
final NovidentStyleRegistry kDefaultStyleRegistry =
    NovidentStyleRegistry(<String, NovidentStyleDefinition>{
  kNormalBodyStyle.id: kNormalBodyStyle,
  _kHeadingDefaultStyles[0].id: _kHeadingDefaultStyles[0],
  _kHeadingDefaultStyles[1].id: _kHeadingDefaultStyles[1],
  _kHeadingDefaultStyles[2].id: _kHeadingDefaultStyles[2],
  _kHeadingDefaultStyles[3].id: _kHeadingDefaultStyles[3],
  _kHeadingDefaultStyles[4].id: _kHeadingDefaultStyles[4],
  _kHeadingDefaultStyles[5].id: _kHeadingDefaultStyles[5],
});

// Default paragraph base style. Must be always used as part of `defaultStyle` property
// since kNormalBodyStyle base it self on the default one
//
// This style acts like a fallback when required
const NovidentStyleDefinition kDefaultBaseStyle =
    NovidentStyleDefinition.nextSame(
  id: '__novident_base__',
  name: 'Base',
  fontSize: 12.0,
  fontFamily: 'Roboto',
  spacing: NovidentStyleSpacing(after: 5.0),
);

final NovidentStyleDefinition kNormalBodyStyle =
    NovidentStyleDefinition.nextSame(
  id: 'normal',
  name: 'Normal',
  basedOn: kDefaultBaseStyle.id,
);

/// Default heading styles matching built-in heading levels from legacy
/// `HeadingBlockComponent`.
const _kHeadingDefaultStyles = <NovidentStyleDefinition>[
  NovidentStyleDefinition(
    id: 'heading-1',
    name: 'Heading 1',
    fontSize: 32,
    bold: true,
    spacing: NovidentStyleSpacing(before: 24, after: 12),
    next: 'normal',
    allowGlobalFirstLineIndent: false,
  ),
  NovidentStyleDefinition(
    id: 'heading-2',
    name: 'Heading 2',
    fontSize: 28,
    bold: true,
    spacing: NovidentStyleSpacing(before: 20, after: 10),
    next: 'normal',
    allowGlobalFirstLineIndent: false,
  ),
  NovidentStyleDefinition(
    id: 'heading-3',
    name: 'Heading 3',
    fontSize: 24,
    bold: true,
    spacing: NovidentStyleSpacing(before: 16, after: 8),
    next: 'normal',
    allowGlobalFirstLineIndent: false,
  ),
  NovidentStyleDefinition(
    id: 'heading-4',
    name: 'Heading 4',
    fontSize: 20,
    bold: true,
    spacing: NovidentStyleSpacing(before: 14, after: 6),
    next: 'normal',
    allowGlobalFirstLineIndent: false,
  ),
  NovidentStyleDefinition(
    id: 'heading-5',
    name: 'Heading 5',
    fontSize: 18,
    bold: true,
    spacing: NovidentStyleSpacing(before: 12, after: 4),
    next: 'normal',
    allowGlobalFirstLineIndent: false,
  ),
  NovidentStyleDefinition(
    id: 'heading-6',
    name: 'Heading 6',
    fontSize: 16,
    bold: true,
    spacing: NovidentStyleSpacing(before: 10, after: 4),
    next: 'normal',
    allowGlobalFirstLineIndent: false,
  ),
];
