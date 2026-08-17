import 'dart:async';

import 'package:novident_editor/novident_editor.dart';

/// Out-of-band spell-check analysis for a document.
///
/// Lifecycle (Word-like):
/// - listens to the document's delta changes and marks the affected nodes
///   as pending;
/// - a single GLOBAL inactivity timer is restarted on every change — the
///   pending nodes accumulate while the user keeps typing;
/// - when the timer expires, each pending node is re-analyzed ENTIRELY and
///   the `proofState: 'error'` marks are injected into its delta.
///
/// The policy is deliberately coarse: any delta change re-analyzes the
/// whole node. Granular (per-range) analysis requires exact change metadata
/// on EVERY mutation path — undo/redo, paste, node insertion and
/// multi-node replacements don't provide it, so range-based marks went
/// stale. Whole-node validation is cheap (O(1) per word against a Trie)
/// and runs only after the idle timeout, never on the typing hot path.
///
/// The marks are written exclusively by this service, directly through
/// `node.updateAttributes` — never through transactions, and never through
/// `Document.emitChanges` — so the analysis can never loop on itself.
///
/// One service per document.
class SpellCheckService {
  SpellCheckService({
    required this.document,
    required this.checker,
    required this.debounce,
  });

  final Document document;
  final NovidentSpellChecker checker;
  final Duration debounce;

  /// Nodes pending a full re-analysis.
  final Set<Node> _pending = {};

  Timer? _idleTimer;

  void resetIfNeeded() {
    if (_idleTimer == null || !_idleTimer!.isActive) {
      return;
    }
    _idleTimer?.cancel();
    _idleTimer = Timer(debounce, _runAnalysis);
  }

  /// Subscribes to the document and schedules the initial full pass.
  void attach() {
    for (final node in _allNodes()) {
      final delta = node.delta;
      if (delta != null && delta.isNotEmpty) {
        _pending.add(node);
      }
    }
    _scheduleIdleTimerIfNeeded();
    document.listenDeltaChanges(_onDeltaChanges);
  }

  /// The active checker language changed: everything must be re-analyzed.
  void onLanguageChanged() {
    for (final node in _allNodes()) {
      if (node.delta != null && node.delta!.isNotEmpty) {
        _pending.add(node);
      }
    }
    _scheduleIdleTimerIfNeeded();
  }

  /// Encodes [node] for immediate re-analysis — used when the validity of
  /// its words changed outside the delta (e.g. a word was learned or
  /// forgotten in the personal dictionary).
  void requestAnalysis(Node node) {
    _pending.add(node);
    _scheduleIdleTimerIfNeeded();
  }

  void _onDeltaChanges(DeltaChangeEvent event) {
    // Any delta change → re-analyze the whole node.
    _pending.add(event.node);
    _scheduleIdleTimerIfNeeded();
  }

  void _scheduleIdleTimerIfNeeded() {
    if (_pending.isEmpty) {
      return;
    }
    _startTimer();
  }

  void _startTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(debounce, _runAnalysis);
  }

  void _runAnalysis() {
    final pending = List.of(_pending);
    _pending.clear();
    for (final node in pending) {
      _analyzeNode(node);
    }
    _idleTimer = null;
  }

  void _analyzeNode(Node node) {
    final delta = node.delta;
    if (delta == null || delta.isEmpty) {
      return;
    }

    final text = delta.toPlainText();
    final issues = checker.check(text);
    final segments = buildProofSegments(text, issues);

    // 1. Clear every existing mark in the node (compose with a null
    // attribute removes it — verified).
    var proofed = delta.compose(
      Delta()
        ..retain(
          text.length,
          attributes: {RichTextKeys.proofState: null},
        ),
    );

    // 2. Re-apply the current errors.
    if (segments.any((segment) => segment.isError)) {
      final proofFormat = Delta();
      var cursor = 0;
      for (final segment in segments.where((s) => s.isError)) {
        if (segment.startOffset > cursor) {
          proofFormat.retain(segment.startOffset - cursor);
        }
        proofFormat.retain(
          segment.length,
          attributes: {RichTextKeys.proofState: proofStateError},
        );
        cursor = segment.startOffset + segment.length;
      }
      proofed = proofed.compose(proofFormat);
    }

    // 3. Exclusive write: no transaction, no delta-change emission.
    node.updateAttributes({'delta': proofed.toJson()});
  }

  List<Node> _allNodes() =>
      NodeIterator(document: document, startNode: document.root).toList();

  void dispose() {
    _idleTimer?.cancel();
    document.removeDeltaChangesListener(_onDeltaChanges);
    _pending.clear();
  }
}
