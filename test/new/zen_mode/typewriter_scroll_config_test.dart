import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/novident_editor.dart';

void main() {
  group('TypewriterScrollConfig', () {
    test('defaults enable centering with a 0.45 alignment', () {
      const config = TypewriterScrollConfig();
      expect(config.enabled, isTrue);
      expect(config.centerAlignment, 0.45);
      expect(config.scrollDuration, const Duration(milliseconds: 240));
      expect(config.scrollCurve, Curves.easeOutCubic);
    });

    test('copyWith overrides only the provided fields', () {
      const config = TypewriterScrollConfig();
      final updated = config.copyWith(
        enabled: false,
        centerAlignment: 0.5,
      );
      expect(updated.enabled, isFalse);
      expect(updated.centerAlignment, 0.5);
      expect(updated.scrollDuration, config.scrollDuration);
      expect(updated.scrollCurve, config.scrollCurve);
    });

    test('copyWith without args returns an equal config', () {
      const config = TypewriterScrollConfig();
      expect(config.copyWith(), config);
    });

    test('equality compares all fields', () {
      const a = TypewriterScrollConfig();
      const b = TypewriterScrollConfig();
      const c = TypewriterScrollConfig(enabled: false);
      expect(a, b);
      expect(a == c, isFalse);
      expect(a.hashCode, b.hashCode);
    });

    test('asserts centerAlignment is within [0, 1]', () {
      expect(
        () => TypewriterScrollConfig(centerAlignment: 1.5),
        throwsAssertionError,
      );
    });
  });
}