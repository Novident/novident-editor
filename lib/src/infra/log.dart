import 'package:logging/logging.dart';

enum NovidentEditorLogLevel {
  off,
  error,
  warn,
  info,
  debug,
  all,
}

typedef NovidentEditorLogHandler = void Function(String message);

/// Manages log service for [NovidentEditor]
///
/// Set the log level and config the handler depending on your need.
class NovidentLogConfiguration {
  NovidentLogConfiguration._() {
    Logger.root.onRecord.listen((record) {
      if (handler != null) {
        handler!(
          '[${record.level.toLogLevel().name}][${record.loggerName}]: ${record.time}: ${record.message}',
        );
      }
    });
  }

  factory NovidentLogConfiguration() => _logConfiguration;

  static final NovidentLogConfiguration _logConfiguration =
      NovidentLogConfiguration._();

  NovidentEditorLogHandler? handler;

  NovidentEditorLogLevel _level = NovidentEditorLogLevel.off;

  NovidentEditorLogLevel get level => _level;
  set level(NovidentEditorLogLevel level) {
    _level = level;
    Logger.root.level = level.toLevel();
  }
}

/// For logging message in NovidentEditor
class NovidentEditorLog {
  NovidentEditorLog._({
    required this.name,
  }) : _logger = Logger(name);

  final String name;
  late final Logger _logger;

  /// For logging message related to [NovidentEditor].
  ///
  /// For example, uses the logger when registering plugins
  ///   or handling something related to [EditorState].
  static NovidentEditorLog editor = NovidentEditorLog._(name: 'editor');

  /// For logging message related to [NovidentSelectionService].
  ///
  /// For example, uses the logger when updating or clearing selection.
  static NovidentEditorLog selection = NovidentEditorLog._(name: 'selection');

  /// For logging message related to [NovidentKeyboardService].
  ///
  /// For example, uses the logger when processing shortcut events.
  static NovidentEditorLog keyboard = NovidentEditorLog._(name: 'keyboard');

  /// For logging message related to [NovidentInputService].
  ///
  /// For example, uses the logger when processing text inputs.
  static NovidentEditorLog input = NovidentEditorLog._(name: 'input');

  /// For logging message related to [NovidentScrollService].
  ///
  /// For example, uses the logger when processing scroll events.
  static NovidentEditorLog scroll = NovidentEditorLog._(name: 'scroll');

  /// For logging message related to [FloatingToolbar] or [MobileToolbar].
  ///
  /// For example, uses the logger when processing toolbar events.
  static NovidentEditorLog toolbar = NovidentEditorLog._(name: 'toolbar');

  /// For logging message related to UI.
  ///
  /// For example, uses the logger when building the widget.
  static NovidentEditorLog ui = NovidentEditorLog._(name: 'ui');

  void error(String message) => _logger.severe(message);
  void warn(String message) => _logger.warning(message);
  void info(String message) => _logger.info(message);
  void debug(String message) => _logger.fine(message);
}

extension on NovidentEditorLogLevel {
  Level toLevel() {
    switch (this) {
      case NovidentEditorLogLevel.off:
        return Level.OFF;
      case NovidentEditorLogLevel.error:
        return Level.SEVERE;
      case NovidentEditorLogLevel.warn:
        return Level.WARNING;
      case NovidentEditorLogLevel.info:
        return Level.INFO;
      case NovidentEditorLogLevel.debug:
        return Level.FINE;
      case NovidentEditorLogLevel.all:
        return Level.ALL;
    }
  }

  String get name {
    switch (this) {
      case NovidentEditorLogLevel.off:
        return 'OFF';
      case NovidentEditorLogLevel.error:
        return 'ERROR';
      case NovidentEditorLogLevel.warn:
        return 'WARN';
      case NovidentEditorLogLevel.info:
        return 'INFO';
      case NovidentEditorLogLevel.debug:
        return 'DEBUG';
      case NovidentEditorLogLevel.all:
        return 'ALL';
    }
  }
}

extension on Level {
  NovidentEditorLogLevel toLogLevel() {
    if (this == Level.SEVERE) {
      return NovidentEditorLogLevel.error;
    } else if (this == Level.WARNING) {
      return NovidentEditorLogLevel.warn;
    } else if (this == Level.INFO) {
      return NovidentEditorLogLevel.info;
    } else if (this == Level.FINE) {
      return NovidentEditorLogLevel.debug;
    }
    return NovidentEditorLogLevel.off;
  }
}
