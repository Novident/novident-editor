// By default, fonts differ depending on the platform.
// * The default font-family for Android,Fuchsia and Linux is Roboto.
// * The default font-family for iOS is SF Pro Display/SF Pro Text.
// * The default font-family for MacOS is .AppleSystemUIFont.
// * The default font-family for Windows is Segoe UI.
//
// Since Flutter’s font discovery for default fonts depends on the fonts present on the device, it is not safe to assume all default fonts will be available or consistent across devices.
// A known example of this is that Samsung devices ship with a CJK font that has smaller line spacing than the Android default. This results in Samsung devices displaying more tightly spaced text than on other Android devices when no custom font is specified.
//
// To avoid this, a custom font should be specified if absolute font consistency is required for your application.
import 'package:novident_editor_core/novident_editor_core.dart';

/// All of these fonts are provided by: [system_fonts](https://android.googlesource.com/platform/frameworks/base/+/lollipop-release/data/fonts/system_fonts.xml)
const String defaultAndroidFont = "roboto";
const String defaultIosFont = "SF Pro";
const String defaultMacOsFont = defaultIosFont;
const String defaultLinuxFont = "Liberation Sans";
const String defaultWindowsFont = "Segoe UI";

/// All of these fonts are provided by: [system_fonts](https://android.googlesource.com/platform/frameworks/base/+/lollipop-release/data/fonts/system_fonts.xml)
const Set<String> androidFonts = {
  "roboto",
  "arial",
  "helvetica",
  "tahoma",
  "verdana",
  "times",
  "times new roman",
  "palatino",
  "georgia",
  "baskerville",
  "goudy",
  "fantasy",
  "ITC Stone Serif",
  "monaco",
  "courier",
  "courier new",
};

const Set<String> iosFonts = {
  "SF Pro",
  "SF Pro Display",
  "SF Pro Text",
  "SF Mono",
  "New York",
  "Helvetica",
  "Helvetica Neue",
  "Arial",
  "Arial Rounded MT Bold",
  "Times New Roman",
  "Georgia",
  "Verdana",
  "Courier New",
  "Palatino",
  "Gill Sans",
  "Trebuchet MS",
  "Baskerville",
  "Didot",
  "Futura",
  "Optima"
};

const Set<String> chineseSimplifiedIosFonts = {"PingFang SC"};
const Set<String> chineseTraditionalTaiwanIosFonts = {"PingFang TC"};
const Set<String> chineseTraditionalHKIosFonts = {"PingFang HC"};
const Set<String> japaneseIosFonts = {"Hiragino Sans", "Hiragino Mincho"};
const Set<String> koreanIosFonts = {"Apple SD Gothic Neo"};

// These next elements are NOT safe at all.
//
// We recommend using [system_fonts] package from pub dev instead of trying to
// resolve standard fons. We provide these elements for example/default cases commonly

/// Most of these fonts are provided by: https://learn.microsoft.com/en-us/typography/fonts/windows_10_font_list
///
/// For production, we suggest using [system_fonts] package
const Set<String> windowsFonts = {
  "arial",
  "times new roman",
  "courier new",
  "georgia",
  "tahoma",
  "verdana",
  "palatino",
};

/// For production, we suggest using [system_fonts] package
const Set<String> macOsFonts = {
  ...iosFonts,
  "Impact",
  "Comic Sans MS",
  "Lucida Grande"
};

/// For production, we suggest using [system_fonts] package
const Set<String> linuxFons = {
  "DejaVu Sans",
  "DejaVu Serif",
  "DejaVu Sans Mono",
  "Liberation Sans",
  "Liberation Serif",
  "Liberation Mono",
  "Noto Sans",
  "Noto Serif",
  "Noto Mono",
  "FreeSans",
  "FreeSerif",
  "FreeMono",
  "Nimbus Sans",
  "Nimbus Roman",
  "Nimbus Mono PS"
};

/// Returns the standard font filtering by the
/// platform using [PlatformExtension]
String getDefaultFont() {
  if (PlatformExtension.isMacOS || PlatformExtension.isWebOnMacOS) {
    return defaultMacOsFont;
  } else if (PlatformExtension.isWindows || PlatformExtension.isWebOnWindows) {
    return defaultWindowsFont;
  } else if (PlatformExtension.isLinux || PlatformExtension.isWebOnLinux) {
    return defaultLinuxFont;
  } else if (PlatformExtension.isIOS) {
    return defaultIosFont;
  } else if (PlatformExtension.isAndroid) {
    return defaultAndroidFont;
  }
  return defaultAndroidFont;
}

/// Returns all the available standard fonts filtering by the
/// platform using [PlatformExtension]
Set<String> getDefaultFonts() {
  if (PlatformExtension.isMacOS || PlatformExtension.isWebOnMacOS) {
    return macOsFonts;
  } else if (PlatformExtension.isWindows || PlatformExtension.isWebOnWindows) {
    return windowsFonts;
  } else if (PlatformExtension.isLinux || PlatformExtension.isWebOnLinux) {
    return linuxFons;
  } else if (PlatformExtension.isIOS) {
    return iosFonts;
  } else if (PlatformExtension.isAndroid) {
    return androidFonts;
  }
  return androidFonts;
}
