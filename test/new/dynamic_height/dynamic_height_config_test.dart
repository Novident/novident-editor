import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/src/editor/editor_component/service/layout/dynamic_height_config.dart';

void main() {
  group('DynamicHeightConfig', () {
    test('defaults are reasonable', () {
      const config = DynamicHeightConfig();
      expect(config.minHeight, 100.0);
      expect(config.defaultBlockHeight, 60.0);
      expect(config.resizeDebounce, Duration.zero);
    });

    test('custom values are preserved', () {
      const config = DynamicHeightConfig(
        minHeight: 200.0,
        defaultBlockHeight: 80.0,
        resizeDebounce: Duration(milliseconds: 100),
      );
      expect(config.minHeight, 200.0);
      expect(config.defaultBlockHeight, 80.0);
      expect(config.resizeDebounce, const Duration(milliseconds: 100));
    });

    test('copyWith overrides specified fields', () {
      const original = DynamicHeightConfig(
        minHeight: 100.0,
        defaultBlockHeight: 60.0,
        resizeDebounce: Duration(milliseconds: 50),
      );

      final modified = original.copyWith(minHeight: 300.0);

      expect(modified.minHeight, 300.0);
      expect(modified.defaultBlockHeight, 60.0); // unchanged
      expect(modified.resizeDebounce, const Duration(milliseconds: 50)); // unchanged
    });

    test('copyWith preserves original when nothing changed', () {
      const config = DynamicHeightConfig(minHeight: 150.0);
      final copy = config.copyWith();
      expect(copy.minHeight, config.minHeight);
      expect(copy.defaultBlockHeight, config.defaultBlockHeight);
      expect(copy.resizeDebounce, config.resizeDebounce);
    });

    test('equality compares all fields', () {
      const a = DynamicHeightConfig(minHeight: 100.0);
      const b = DynamicHeightConfig(minHeight: 100.0);
      const c = DynamicHeightConfig(minHeight: 200.0);

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('hashCode is consistent with equality', () {
      const a = DynamicHeightConfig(minHeight: 100.0);
      const b = DynamicHeightConfig(minHeight: 100.0);

      expect(a.hashCode, equals(b.hashCode));
    });

    test('zero resizeDebounce means instant notifications', () {
      const config = DynamicHeightConfig(resizeDebounce: Duration.zero);
      expect(config.resizeDebounce, Duration.zero);
    });
  });
}
