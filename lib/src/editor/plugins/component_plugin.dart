import 'package:flutter/widgets.dart';
import 'package:novident_editor/src/editor/editor_context.dart';
import 'package:novident_editor/src/editor/plugins/component_context.dart';

abstract class ComponentBlockActionPlugin {
  void onPress(EditorContext context);
  Widget component(EditorContext context);
}

abstract class ComponentPlugin {
  ComponentPlugin();

  /// All you need to know for doing a Block settings is a renderSettings 
  /// method. It will called when user clicks on the Block Actions menu.  
  List<ComponentBlockActionPlugin> renderSettings(ComponentContext context);

  Widget? render(ComponentContext context);
}
