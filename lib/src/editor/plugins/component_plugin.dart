import 'package:flutter/widgets.dart';
import 'package:novident_editor/src/editor/plugins/component_context.dart';

abstract class ComponentPlugin {
  ComponentPlugin();

  Widget? render(ComponentContext context);
}
