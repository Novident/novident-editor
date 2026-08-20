import 'package:flutter/foundation.dart';
import 'package:novident_editor_core/novident_editor_core.dart';

export 'package:novident_editor_core/src/extensions/platform_extension.dart';

/// Platform indirection used by the editor's IME layer.
///
/// By default every getter delegates to [PlatformExtension] (backed by
/// `UniversalPlatform`). Tests can install an [override] to make the IME code
/// path deterministic regardless of the host OS — e.g. force the Linux branch
/// of `onNonTextUpdate` without running on Linux.
abstract final class EditorPlatform {
  /// Active override, or `null` to fall back to the real platform.
  @visibleForTesting
  static EditorPlatformOverride? override;

  @visibleForTesting
  static void reset() => override = null;

  static bool get isMacOS => override?.isMacOS ?? PlatformExtension.isMacOS;
  static bool get isWindows => override?.isWindows ?? PlatformExtension.isWindows;
  static bool get isLinux => override?.isLinux ?? PlatformExtension.isLinux;
  static bool get isIOS => override?.isIOS ?? PlatformExtension.isIOS;
  static bool get isAndroid => override?.isAndroid ?? PlatformExtension.isAndroid;

  static bool get isWebOnMacOS =>
      override?.isWebOnMacOS ?? PlatformExtension.isWebOnMacOS;
  static bool get isWebOnWindows =>
      override?.isWebOnWindows ?? PlatformExtension.isWebOnWindows;
  static bool get isWebOnLinux =>
      override?.isWebOnLinux ?? PlatformExtension.isWebOnLinux;

  static bool get isDesktopOrWeb =>
      override?.isDesktopOrWeb ?? PlatformExtension.isDesktopOrWeb;
  static bool get isDesktop => override?.isDesktop ?? PlatformExtension.isDesktop;
  static bool get isMobile => override?.isMobile ?? PlatformExtension.isMobile;
  static bool get isNotMobile =>
      override?.isNotMobile ?? PlatformExtension.isNotMobile;
}

/// Immutable platform snapshot used to override [EditorPlatform] in tests.
@immutable
class EditorPlatformOverride {
  const EditorPlatformOverride({
    this.isMacOS = false,
    this.isWindows = false,
    this.isLinux = false,
    this.isIOS = false,
    this.isAndroid = false,
    this.isWebOnMacOS = false,
    this.isWebOnWindows = false,
    this.isWebOnLinux = false,
    this.isDesktopOrWeb = false,
    this.isDesktop = false,
    this.isMobile = false,
    this.isNotMobile = false,
  });

  final bool isMacOS;
  final bool isWindows;
  final bool isLinux;
  final bool isIOS;
  final bool isAndroid;

  final bool isWebOnMacOS;
  final bool isWebOnWindows;
  final bool isWebOnLinux;

  final bool isDesktopOrWeb;
  final bool isDesktop;
  final bool isMobile;
  final bool isNotMobile;
}
