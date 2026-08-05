import 'package:flutter/material.dart';

/// only for the common config of text style
class TextStyleConfiguration {
  const TextStyleConfiguration({
    this.href = const TextStyle(
      color: Colors.lightBlue,
      decoration: TextDecoration.underline,
    ),
    this.code = const TextStyle(
      color: Colors.red,
      backgroundColor: Color.fromARGB(98, 0, 195, 255),
    ),
    this.autoComplete = const TextStyle(
      color: Colors.grey,
    ),
    this.applyHeightToFirstAscent = false,
    this.applyHeightToLastDescent = false,
    this.leadingDistribution = TextLeadingDistribution.even,
  });

  /// href text style
  final TextStyle href;

  /// code text style
  final TextStyle code;

  /// auto complete text style
  final TextStyle autoComplete;

  /// apply line height to the first or the last ascent
  final bool applyHeightToFirstAscent;
  final bool applyHeightToLastDescent;

  final TextLeadingDistribution leadingDistribution;

  TextStyleConfiguration copyWith({
    TextStyle? href,
    TextStyle? code,
    TextStyle? autoComplete,
    bool? applyHeightToFirstAscent,
    bool? applyHeightToLastDescent,
    TextLeadingDistribution? leadingDistribution,
  }) {
    return TextStyleConfiguration(
      href: href ?? this.href,
      code: code ?? this.code,
      autoComplete: autoComplete ?? this.autoComplete,
      applyHeightToFirstAscent:
          applyHeightToFirstAscent ?? this.applyHeightToFirstAscent,
      applyHeightToLastDescent:
          applyHeightToLastDescent ?? this.applyHeightToLastDescent,
      leadingDistribution: leadingDistribution ?? this.leadingDistribution,
    );
  }
}
