import 'package:novident_editor/novident_editor.dart';

class TableConfig {
  TableConfig({
    double? colDefaultWeight,
    double? colDefaultWidth,
    double? rowDefaultHeight,
    double? colMinimumWidth,
    double? borderWidth,
  }) {
    this.colDefaultWeight = colDefaultWeight ?? TableDefaults.colDefaultWeight;
    this.colDefaultWidth = colDefaultWidth ?? TableDefaults.colWidth;
    this.rowDefaultHeight = rowDefaultHeight ?? TableDefaults.rowHeight;
    this.colMinimumWidth = colMinimumWidth ?? TableDefaults.colMinimumWidth;
    this.borderWidth = borderWidth ?? TableDefaults.borderWidth;
  }

  static double parseAttributeToDouble(
    String key,
    double defaultVal,
    Map<String, dynamic> json,
  ) =>
      json.containsKey(key)
          ? double.tryParse(json[key].toString())!
          : defaultVal;

  static TableConfig fromJson(Map<String, dynamic> json) {
    return TableConfig(
      colDefaultWeight: parseAttributeToDouble(
        TableBlockKeys.colDefaultWeight,
        TableDefaults.colDefaultWeight,
        json,
      ),
      colDefaultWidth: parseAttributeToDouble(
        TableBlockKeys.colDefaultWidth,
        TableDefaults.colWidth,
        json,
      ),
      rowDefaultHeight: parseAttributeToDouble(
        TableBlockKeys.rowDefaultHeight,
        TableDefaults.rowHeight,
        json,
      ),
      colMinimumWidth: parseAttributeToDouble(
        TableBlockKeys.colMinimumWidth,
        TableDefaults.colMinimumWidth,
        json,
      ),
      borderWidth: parseAttributeToDouble(
        TableBlockKeys.borderWidth,
        TableDefaults.borderWidth,
        json,
      ),
    );
  }

  Map<String, Object> toJson() {
    return {
      TableBlockKeys.colDefaultWeight: colDefaultWeight,
      TableBlockKeys.colDefaultWidth: colDefaultWidth,
      TableBlockKeys.rowDefaultHeight: rowDefaultHeight,
      TableBlockKeys.colMinimumWidth: colMinimumWidth,
      TableBlockKeys.borderWidth: borderWidth,
    };
  }

  late final double colDefaultWeight,
      colDefaultWidth,
      rowDefaultHeight,
      colMinimumWidth,
      borderWidth;
}
