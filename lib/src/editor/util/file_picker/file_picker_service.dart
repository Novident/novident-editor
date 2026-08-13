import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/foundation.dart';

class FilePickerResult {
  const FilePickerResult(this.files);

  /// Picked files.
  final List<fp.PlatformFile> files;
}

/// Abstract file picker as a service to implement dependency injection.
abstract class FilePickerService {
  Future<String?> getDirectoryPath({
    String? title,
  }) async =>
      throw UnimplementedError('getDirectoryPath() has not been implemented.');

  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    fp.FileType type = fp.FileType.any,
    List<String>? allowedExtensions,
    Function(fp.FilePickerStatus p1)? onFileLoading,
    bool lockParentWindow = false,
  }) async =>
      throw UnimplementedError('pickFiles() has not been implemented.');

  Future<String?> saveFile({
    required Uint8List bytes,
    required String fileName,
    String? dialogTitle,
    String? initialDirectory,
    fp.FileType type = fp.FileType.any,
    List<String>? allowedExtensions,
    bool lockParentWindow = false,
    dynamic Function(fp.FilePickerStatus)? onFileLoading,
  }) async =>
      throw UnimplementedError('saveFile() has not been implemented.');
}
