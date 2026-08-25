import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novident_editor/novident_editor.dart';

void main() {
  group('ZenModeScope', () {
    testWidgets('maybeOf returns null without a scope', (tester) async {
      late BuildContext buildContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              buildContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(ZenModeScope.maybeOf(buildContext), isNull);
    });

    testWidgets('maybeOf finds the nearest scope', (tester) async {
      late BuildContext buildContext;
      await tester.pumpWidget(
        MaterialApp(
          home: ZenModeScope(
            dimmed: true,
            unfocusedOpacity: 0.35,
            configuration: const ZenModeConfiguration(),
            child: Builder(
              builder: (context) {
                buildContext = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      final scope = ZenModeScope.maybeOf(buildContext);
      expect(scope, isNotNull);
      expect(scope!.dimmed, isTrue);
    });

    test('updateShouldNotify only on dimmed/opacity/config changes', () {
      const base = ZenModeScope(
        dimmed: true,
        unfocusedOpacity: 0.35,
        configuration: ZenModeConfiguration(),
        child: SizedBox.shrink(),
      );
      const same = ZenModeScope(
        dimmed: true,
        unfocusedOpacity: 0.35,
        configuration: ZenModeConfiguration(),
        child: SizedBox.shrink(),
      );
      const different = ZenModeScope(
        dimmed: false,
        unfocusedOpacity: 0.35,
        configuration: ZenModeConfiguration(),
        child: SizedBox.shrink(),
      );
      expect(base.updateShouldNotify(same), isFalse);
      expect(base.updateShouldNotify(different), isTrue);
    });
  });
}
