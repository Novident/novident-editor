import 'package:flutter/foundation.dart';
import 'package:novident_editor/src/editor/util/file_picker/file_picker_service.dart';
import 'package:file_picker/file_picker.dart' as fp;

class FilePicker implements FilePickerService {
  @override
  Future<String?> getDirectoryPath({String? title}) {
    return fp.FilePicker.getDirectoryPath();
  }

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    fp.FileType type = fp.FileType.any,
    List<String>? allowedExtensions,
    Function(fp.FilePickerStatus p1)? onFileLoading,
    bool lockParentWindow = false,
  }) async {
    final result = await fp.FilePicker.pickFiles(
      dialogTitle: dialogTitle,
      initialDirectory: initialDirectory,
      type: type,
      allowedExtensions: allowedExtensions,
      onFileLoading: onFileLoading,
      lockParentWindow: lockParentWindow,
    );
    return FilePickerResult(result?.files ?? []);
  }

  @override
  Future<String?> saveFile({
    required List<int> bytes,
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    fp.FileType type = fp.FileType.any,
    List<String>? allowedExtensions,
    bool lockParentWindow = false,
  }) {
    return fp.FilePicker.saveFile(
      dialogTitle: dialogTitle,
      bytes: Uint8List.fromList([]),
      fileName: fileName ?? '${DateTime.now().toUtc()}',
      initialDirectory: initialDirectory,
      type: type,
      allowedExtensions: allowedExtensions,
      lockParentWindow: lockParentWindow,
    );
  }
}
