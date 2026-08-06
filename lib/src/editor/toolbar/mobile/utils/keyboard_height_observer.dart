import 'package:novident_editor/src/editor/util/platform_extension.dart';
import 'package:keyboard_height/keyboard_height.dart';

typedef KeyboardHeightCallback = void Function(double height);

// the KeyboardHeightPlugin only accepts one listener, so we need to create a
//  singleton class to manage the multiple listeners.
class KeyboardHeightObserver {
  KeyboardHeightObserver._() {
    if (!_hasListener) {
      _hasListener = true;
      _keyboardHeightPlugin.addListener(() {
        notify(_keyboardHeightPlugin.height);
      });
    }
  }

  static bool _hasListener = false;

  static final KeyboardHeightObserver instance = KeyboardHeightObserver._();
  static double get currentKeyboardHeight => _keyboardHeightPlugin.height;

  final List<KeyboardHeightCallback> _listeners = [];
  static final KeyboardHeight _keyboardHeightPlugin = KeyboardHeight.instance;

  void addListener(KeyboardHeightCallback listener) {
    _listeners.add(listener);
  }

  void removeListener(KeyboardHeightCallback listener) {
    _listeners.remove(listener);
  }

  void dispose() {
    _listeners.clear();
    _keyboardHeightPlugin.dispose();
  }

  void notify(double height) {
    // the keyboard height will notify twice with the same value on Android
    if (PlatformExtension.isAndroid && height == currentKeyboardHeight) {
      return;
    }

    for (final listener in _listeners) {
      listener(height);
    }
  }
}
