import 'package:flutter/foundation.dart';
import 'package:novident_editor/novident_editor.dart';

const bool _enableLog = false;

void activateLog() {
  if (!_enableLog) {
    return;
  }
  NovidentLogConfiguration()
    ..handler = debugPrint
    ..level = NovidentEditorLogLevel.all;
}

void deactivateLog() {
  if (!_enableLog) {
    return;
  }
  NovidentLogConfiguration()
    ..handler = null
    ..level = NovidentEditorLogLevel.off;
}
