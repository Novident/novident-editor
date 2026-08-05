import 'package:flutter/animation.dart';
import 'package:novident_editor_core/novident_editor_core.dart';

/// Direction of a cursor or selection movement, triggered by user input
/// (arrows, Home/End, PgUp/PgDn, Ctrl+arrows for word navigation).
enum MoveDirection {
  /// Arrow up.
  up,

  /// Arrow down.
  down,

  /// Arrow left.
  left,

  /// Arrow right.
  right,

  /// Home key — start of visual line.
  lineStart,

  /// End key — end of visual line.
  lineEnd,

  /// Page up.
  pageUp,

  /// Page down.
  pageDown,

  /// Ctrl+Arrow left — previous word boundary.
  wordLeft,

  /// Ctrl+Arrow right — next word boundary.
  wordRight,
}

/// Returned by [SelectionRenderer.onTryMove] to control how the editor
/// handles a cursor transition.
///
/// Three factory constructors cover common cases:
/// - [MoveIntention.pass] — let the editor move normally.
/// - [MoveIntention.cancel] — block the movement entirely.
/// - [MoveIntention.animated] — request a smooth animated transition.
class MoveIntention {
  /// The final position after the move.
  /// When `null`, the movement is cancelled entirely.
  final Position? target;

  /// When non-null, the editor should animate the cursor transition over
  /// this duration instead of moving instantly.
  final Duration? animationDuration;

  /// The animation curve for [animationDuration].
  final Curve? animationCurve;

  /// When `true`, the editor skips its default movement logic and trusts
  /// the renderer to handle everything — including updating the selection
  /// in [EditorState]. Set this to `true` when you need full control over
  /// the movement lifecycle (e.g. custom animation with manual selection
  /// updates at specific frames).
  final bool takeFullControl;

  /// Allow the editor to move the cursor normally (no override).
  const MoveIntention.pass()
      : target = null,
        animationDuration = null,
        animationCurve = null,
        takeFullControl = false;

  /// Cancel the movement entirely. The cursor stays in place.
  const MoveIntention.cancel()
      : target = null,
        animationDuration = null,
        animationCurve = null,
        takeFullControl = false;

  /// Create a custom intention with explicit control over all fields.
  const MoveIntention({
    this.target,
    this.animationDuration,
    this.animationCurve,
    this.takeFullControl = false,
  });
}
