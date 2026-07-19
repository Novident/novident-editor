import 'package:novident_editor/novident_editor.dart';
import 'package:flutter/material.dart' hide Overlay, OverlayEntry, OverlayState;

class EditorService {
  // selection service
  final selectionServiceKey = GlobalKey(
    debugLabel: 'novident_editor_selection_service',
  );
  NovidentSelectionService get selectionService {
    assert(
      selectionServiceKey.currentState != null &&
          selectionServiceKey.currentState is NovidentSelectionService,
    );
    return selectionServiceKey.currentState! as NovidentSelectionService;
  }

  // keyboard service
  final keyboardServiceKey = GlobalKey(
    debugLabel: 'novident_editor_keyboard_service',
  );
  NovidentKeyboardService? get keyboardService {
    if (keyboardServiceKey.currentState != null &&
        keyboardServiceKey.currentState is NovidentKeyboardService) {
      return keyboardServiceKey.currentState! as NovidentKeyboardService;
    }
    return null;
  }

  // render plugin service
  // late NovidentRenderPlugin renderPluginService;
  late BlockComponentRendererService rendererService;

  // scroll service
  final scrollServiceKey = GlobalKey(
    debugLabel: 'novident_editor_scroll_service',
  );
  NovidentScrollService? get scrollService {
    if (scrollServiceKey.currentState != null &&
        scrollServiceKey.currentState is NovidentScrollService) {
      return scrollServiceKey.currentState! as NovidentScrollService;
    }
    return null;
  }
}
