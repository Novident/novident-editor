import 'package:flutter/services.dart';

export 'delta_input_on_action_update_impl.dart';
export 'delta_input_on_delete_impl.dart';
export 'delta_input_on_insert_impl.dart';
export 'delta_input_on_non_text_update_impl.dart';
export 'delta_input_on_replace_impl.dart';
export 'non_delta_input_service.dart';
export 'text_input_service.dart';

/// Converts a [TextEditingDeltaReplacement] into the equivalent insertion.
///
/// Used by the IME channel when the replaced selection spans multiple
/// nodes: the selection is deleted and the text is treated as an insertion.
extension TextEditingDeltaReplacementToInsertion
    on TextEditingDeltaReplacement {
  TextEditingDeltaInsertion toInsertion() {
    final text = oldText.replaceRange(
      replacedRange.start,
      replacedRange.end,
      '',
    );
    return TextEditingDeltaInsertion(
      oldText: text,
      textInserted: replacementText,
      insertionOffset: replacedRange.start,
      selection: selection,
      composing: composing,
    );
  }
}
