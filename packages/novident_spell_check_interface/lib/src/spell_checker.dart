import 'spell_check_issue.dart';

/// The attribute value stored in a Delta `proofState` attribute to mark a
/// misspelled word.
///
/// Only this value is ever written, and only by the spell-check engine.
/// The base editor ignores the `proofState` key entirely; the
/// spell-check-aware pipeline interprets it.
const String proofStateError = 'err';
const String proofStateGrammarError = 'grammarErr';

/// Contract implemented by any spell-check engine (e.g. the standalone
/// Novident spell-checker library backed by SymSpell).
///
/// Implementations must be synchronous and cheap on the validation path:
/// [isValid] and [check] run on editor-idle analysis, [suggest] is lazy and
/// only used by context menus.
abstract class NovidentSpellChecker {
  const NovidentSpellChecker();

  /// Whether [word] is valid in the active language. Expected O(1).
  bool isValid(String word);

  /// Returns the misspelled ranges of [text].
  ///
  /// Offsets are UTF-16 code units relative to [text]. Issues may be
  /// returned in any order; consumers normalize them (see
  /// `buildProofSegments`).
  List<SpellCheckIssue> check(String text);

  /// Lazy suggestions for [word] (context menu). May be expensive.
  List<String> suggest(String word);

  /// Active language code (e.g. 'en', 'es'), or null when unset.
  String? get language;
}
