import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NovidentClipboardData {
  const NovidentClipboardData({
    this.text,
    this.html,
  });
  final String? text;
  final String? html;
}

//TODO: @CatHood0 this class require more customization and 
// a full refactor to work with html 
class NovidentClipboard {
  static NovidentClipboardData? _mockData;

  @visibleForTesting
  static String? lastText;

  static Future<void> setData({
    String? text,
    String? html,
  }) async {
    if (text == null) {
      return;
    }

    lastText = text;

    return Clipboard.setData(
      ClipboardData(
        text: text,
      ),
    );
  }

  static Future<NovidentClipboardData> getData() async {
    if (_mockData != null) {
      return _mockData!;
    }

    final data = await Clipboard.getData(Clipboard.kTextPlain);
    return NovidentClipboardData(
      text: data?.text,
    );
  }

  @visibleForTesting
  static void mockSetData(NovidentClipboardData? data) {
    _mockData = data;
  }
}
