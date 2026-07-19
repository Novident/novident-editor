// Smoke test: boots the workspace and verifies that the
// binder shows the default project structure and that the README file
// (Research ▸ README) is selected/visible on startup.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:example/main.dart';

void main() {
  Future<void> pumpWorkspace(WidgetTester tester) async {
    // Desktop-like viewport so MiddlewareView renders the desktop view.
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MyApp());

    // The editor caret starts a periodic blink timer.
    // pumpAndSettle drains pending timers so _verifyInvariants does
    // not fail at the end of the test.
    await tester.pumpAndSettle();
  }

  testWidgets('Workspace boots with binder and README selected',
      (WidgetTester tester) async {
    await pumpWorkspace(tester);

    // Binder header (project name).
    expect(find.text('The Hollow Forest'), findsWidgets);

    // Default root directories from default_files_nodes.dart.
    expect(find.text('Manuscript'), findsOneWidget);
    expect(find.text('Research'), findsOneWidget);
    expect(find.text('Characters'), findsOneWidget);
    expect(find.text('Places'), findsOneWidget);

    // README is the initial selection (root.atPath([1, 0])): it is
    // opened as the first split view buffer, so its name must appear
    // at least in the pane header (the binder may keep it collapsed).
    expect(find.text('README'), findsWidgets);
  });

  testWidgets('Vim mode is enabled by default in the editor panes',
      (WidgetTester tester) async {
    await pumpWorkspace(tester);

    // The status bar of the pane shows the vim chip, starting in
    // NORMAL mode (vim-like default).
    expect(find.text('NORMAL'), findsOneWidget);
    // And the zen mode toggle is available.
    expect(find.byIcon(CupertinoIcons.moon_stars), findsOneWidget);
    // The word/character counter sits right next to it (the README
    // starts empty).
    expect(find.text('0 words · 0 chars'), findsOneWidget);
  });

  testWidgets('Zen mode hides everything but the centered editor',
      (WidgetTester tester) async {
    await pumpWorkspace(tester);

    // Enter zen mode from the pane status bar.
    await tester.tap(find.byIcon(CupertinoIcons.moon_stars));
    await tester.pumpAndSettle();

    // The binder (tree view) and the pane chrome are gone…
    expect(find.text('Manuscript'), findsNothing);
    expect(find.text('Research'), findsNothing);
    // …only the zen editor remains, with its active toggle, the vim
    // chip and the word counter still visible.
    expect(find.byIcon(CupertinoIcons.moon_stars_fill), findsOneWidget);
    expect(find.text('NORMAL'), findsOneWidget);
    expect(find.textContaining('words'), findsOneWidget);

    // Exit through the discreet top-right affordance.
    await tester.tap(find.byIcon(CupertinoIcons.fullscreen_exit));
    await tester.pumpAndSettle();

    // The workspace is back.
    expect(find.text('Manuscript'), findsOneWidget);
    expect(find.text('README'), findsWidgets);
  });
}
