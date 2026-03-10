import 'dart:async';
import 'package:doodle_dash/core/constants/colors.dart';
import 'package:doodle_dash/core/utils/drawing_painter.dart';
import 'package:doodle_dash/features/game/models/drawn_path.dart';
import 'package:doodle_dash/features/shared/widgets/vote_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:doodle_dash/core/websocket/websocket_service.dart';
import 'package:doodle_dash/features/game/providers/game_provider.dart';
import 'package:doodle_dash/features/game/models/game_state.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DRAWING BOARD WIDGET
// ─────────────────────────────────────────────────────────────────────────────

/// The interactive canvas area where the current drawer sketches and others
/// view the drawing in real-time.
///
/// - If [isDrawer] is true, touch input is enabled and the toolbar is shown.
/// - If [isDrawer] is false, the canvas is read-only and vote buttons appear.
///
/// ## Rendering layers (bottom → top)
///
/// 1. **[DrawingPainter]** inside a [RepaintBoundary] — vector strokes.
/// 2. Vote buttons (non-drawer only, floating overlay).
class DrawingBoard extends ConsumerStatefulWidget {
  final bool isDrawer;
  const DrawingBoard({super.key, required this.isDrawer});

  @override
  ConsumerState<DrawingBoard> createState() => _DrawingBoardState();
}

class _DrawingBoardState extends ConsumerState<DrawingBoard> {
  // ── Vector drawing state ──────────────────────────────────────────────────

  /// All committed strokes rendered by [DrawingPainter].
  final List<DrawnPath> _paths = [];

  /// The stroke currently being drawn (not yet committed to [_paths]).
  DrawnPath? _currentPath;

  // ── Tool state ────────────────────────────────────────────────────────────

  Color _selectedColor = Colors.black;
  double _strokeWidth = 5.0;
  String _activeTool = 'pen'; // 'pen' or 'fill'

  // ── WebSocket subscription ────────────────────────────────────────────────

  /// Direct subscription to the raw WebSocket stream, bypassing Riverpod to
  /// avoid full-widget rebuilds on every pointer/draw event.
  StreamSubscription? _sub;

  // ── Brush size overlay ────────────────────────────────────────────────────

  final LayerLink _brushSizeLink = LayerLink();
  OverlayEntry? _brushSizeOverlay;

  // ─────────────────────────────────────────────────────────────────────────
  // LIFECYCLE
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // Listen directly to WebSocket stream for fast, isolated drawing updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final wsService = ref.read(webSocketServiceProvider);
      _sub = wsService.messageStream.listen((data) {
        if (data['type'] == 'draw') {
          // If we are the drawer, we handle drawing locally to avoid lag/echo duplication,
          // so we ignore echoed draw messages.
          if (!widget.isDrawer) {
            _handleDrawAction(data);
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _hideBrushSizeOverlay();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // REMOTE DRAW ACTION HANDLER
  // ─────────────────────────────────────────────────────────────────────────

  /// Applies a draw action received from the server on non-drawer clients.
  ///
  /// Supported actions:
  /// - `start`  — begins a new remote stroke.
  /// - `update` — appends a point to the active remote stroke.
  /// - `end`    — commits the active stroke to [_paths].
  /// - `clear`  — resets all canvas state (paths, fills, history).
  void _handleDrawAction(Map<String, dynamic> data) {
    if (data['action'] == 'start') {
      _currentPath = DrawnPath(
        points: [
          Offset(
            (data['dx'] as num).toDouble(),
            (data['dy'] as num).toDouble(),
          ),
        ],
        color: Color(data['color']),
        strokeWidth: (data['strokeWidth'] as num).toDouble(),
      );
      if (mounted) {
        setState(() {});
      }
    } else if (data['action'] == 'update' && _currentPath != null) {
      _currentPath!.points.add(
        Offset((data['dx'] as num).toDouble(), (data['dy'] as num).toDouble()),
      );
      if (mounted) {
        setState(() {});
      }
    } else if (data['action'] == 'end' && _currentPath != null) {
      _paths.add(_currentPath!);
      _currentPath = null;
      if (mounted) {
        setState(() {});
      }
    } else if (data['action'] == 'clear') {
      _paths.clear();
      _currentPath = null;
      if (mounted) {
        setState(() {});
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LOCAL GESTURE HANDLERS (drawer only)
  // ─────────────────────────────────────────────────────────────────────────

  /// Handles a single tap (dot) from the drawer.
  void _onTapDown(TapDownDetails details, BoxConstraints constraints) {
    if (!widget.isDrawer || ref.read(gameProvider).state != GameState.drawing) {
      return;
    }
    final x = details.localPosition.dx / constraints.maxWidth;
    final y = details.localPosition.dy / constraints.maxHeight;

    _currentPath = DrawnPath(
      points: [Offset(x, y)],
      color: _selectedColor,
      strokeWidth: _strokeWidth,
    );
    ref.read(gameProvider.notifier).sendDrawAction({
      'action': 'start',
      'dx': x,
      'dy': y,
      'color': _selectedColor.toARGB32(),
      'strokeWidth': _strokeWidth,
    });
    // Send immediate end to make it a dot
    ref.read(gameProvider.notifier).sendDrawAction({'action': 'end'});
    _paths.add(_currentPath!);
    _currentPath = null;
    setState(() {});
  }

  /// Begins a new stroke at the drag start position.
  void _onPanStart(DragStartDetails details, BoxConstraints constraints) {
    if (!widget.isDrawer || ref.read(gameProvider).state != GameState.drawing) {
      return;
    }
    final x = details.localPosition.dx / constraints.maxWidth;
    final y = details.localPosition.dy / constraints.maxHeight;

    _currentPath = DrawnPath(
      points: [Offset(x, y)],
      color: _selectedColor,
      strokeWidth: _strokeWidth,
    );
    ref.read(gameProvider.notifier).sendDrawAction({
      'action': 'start',
      'dx': x,
      'dy': y,
      'color': _selectedColor.toARGB32(),
      'strokeWidth': _strokeWidth,
    });
    setState(() {});
  }

  /// Appends a point to the current stroke as the user drags.
  void _onPanUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    if (!widget.isDrawer ||
        _currentPath == null ||
        ref.read(gameProvider).state != GameState.drawing) {
      return;
    }
    final x = details.localPosition.dx / constraints.maxWidth;
    final y = details.localPosition.dy / constraints.maxHeight;

    _currentPath!.points.add(Offset(x, y));
    ref.read(gameProvider.notifier).sendDrawAction({
      'action': 'update',
      'dx': x,
      'dy': y,
    });
    setState(() {});
  }

  /// Commits the current stroke when the drag ends.
  void _onPanEnd(DragEndDetails details) {
    if (!widget.isDrawer || _currentPath == null) {
      return;
    }
    _paths.add(_currentPath!);
    _currentPath = null;
    ref.read(gameProvider.notifier).sendDrawAction({'action': 'end'});
    setState(() {});
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TOOLBAR ACTIONS
  // ─────────────────────────────────────────────────────────────────────────

  /// Clears all canvas state and broadcasts `clear` to all clients.
  void _clearBoard() {
    if (!widget.isDrawer || ref.read(gameProvider).state != GameState.drawing) {
      return;
    }
    _paths.clear();
    _currentPath = null;
    ref.read(gameProvider.notifier).sendDrawAction({'action': 'clear'});
    setState(() {});
  }

  /// Undoes the last [CanvasAction] and replays the remaining history.
  void _undoAction() {
    if (!widget.isDrawer ||
        _paths.isEmpty ||
        ref.read(gameProvider).state != GameState.drawing) {
      return;
    }
    // Basic local undo without full server history sync out of scope for now,
    // but we can pop local and send a clear + full redraw sequence if we want to be robust.
    // For simplicity, just pop local array.
    _paths.removeLast();
    ref.read(gameProvider.notifier).sendDrawAction({'action': 'clear'});
    for (var path in _paths) {
      ref.read(gameProvider.notifier).sendDrawAction({
        'action': 'start',
        'dx': path.points.first.dx,
        'dy': path.points.first.dy,
        'color': path.color.toARGB32(),
        'strokeWidth': path.strokeWidth,
      });
      for (int i = 1; i < path.points.length; i++) {
        ref.read(gameProvider.notifier).sendDrawAction({
          'action': 'update',
          'dx': path.points[i].dx,
          'dy': path.points[i].dy,
        });
      }
      ref.read(gameProvider.notifier).sendDrawAction({'action': 'end'});
    }
    setState(() {});
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BRUSH SIZE OVERLAY
  // ─────────────────────────────────────────────────────────────────────────
  void _toggleBrushSizeOverlay() {
    if (_brushSizeOverlay != null) {
      _hideBrushSizeOverlay();
    } else {
      _showBrushSizeOverlay();
    }
  }

  void _hideBrushSizeOverlay() {
    _brushSizeOverlay?.remove();
    _brushSizeOverlay = null;
  }

  /// Inserts a floating overlay with four selectable stroke widths above the
  /// brush size button. Tapping outside dismisses it.
  void _showBrushSizeOverlay() {
    final sizes = [4.0, 10.0, 20.0, 32.0];
    _brushSizeOverlay = OverlayEntry(
      builder: (context) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _hideBrushSizeOverlay,
          child: Stack(
            children: [
              Positioned.fill(child: Container(color: Colors.transparent)),
              CompositedTransformFollower(
                link: _brushSizeLink,
                showWhenUnlinked: false,
                offset: const Offset(0, -150), // Pop upwards
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    width: 48,
                    height: 150,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: sizes
                          .map((s) {
                            return GestureDetector(
                              onTap: () {
                                setState(() => _strokeWidth = s);
                                _hideBrushSizeOverlay();
                              },
                              child: Container(
                                width: 32,
                                height: 32,
                                color: _strokeWidth == s
                                    ? Colors.grey.shade200
                                    : Colors.transparent,
                                child: Center(
                                  child: Container(
                                    width: s,
                                    height: s,
                                    decoration: const BoxDecoration(
                                      color: Colors.black,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          })
                          .toList()
                          .reversed
                          .toList(), // Largest at top
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    Overlay.of(context).insert(_brushSizeOverlay!);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Clear the canvas when the drawing phase ends so the board is ready for
    // the next drawer without leftover strokes.
    ref.listen(gameProvider, (previous, next) {
      if (previous?.state == GameState.drawing &&
          next.state != GameState.drawing) {
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _paths.clear();
              _currentPath = null;
            });
          });
        }
      }
    });

    final gameState = ref.watch(gameProvider);
    return Column(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ClipRRect(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      GestureDetector(
                        onTapDown: widget.isDrawer
                            ? (details) => _onTapDown(details, constraints)
                            : null,
                        onPanStart: widget.isDrawer
                            ? (details) => _onPanStart(details, constraints)
                            : null,
                        onPanUpdate: widget.isDrawer
                            ? (details) => _onPanUpdate(details, constraints)
                            : null,
                        onPanEnd: widget.isDrawer ? _onPanEnd : null,
                        child: CustomPaint(
                          painter: DrawingPainter(
                            paths: _paths,
                            currentPath: _currentPath,
                          ),
                          size: Size.infinite,
                        ),
                      ),
                      if (!widget.isDrawer &&
                          gameState.state == GameState.drawing &&
                          !gameState.players
                              .firstWhere(
                                (p) => p.nickname == gameState.nickname,
                              )
                              .voted)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Row(
                            children: [
                              VoteButton(
                                image: 'assets/images/thumbsup.gif',

                                onTap: () => ref
                                    .read(gameProvider.notifier)
                                    .vote('like'),
                              ),
                              const SizedBox(width: 8),
                              VoteButton(
                                image: 'assets/images/thumbsdown.gif',
                                onTap: () => ref
                                    .read(gameProvider.notifier)
                                    .vote('dislike'),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        if (widget.isDrawer)
          _buildToolbar()
        else
          Container(height: 52, color: Colors.transparent),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TOOLBAR
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      height: 52,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left: Current Color Indicator
          Container(
            width: 36,
            decoration: BoxDecoration(
              color: _selectedColor,
              border: Border.all(color: Colors.black, width: 2),
            ),
          ),
          const SizedBox(width: 8),

          // Center: Color Grid
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(13, (colIndex) {
                  final topColorIdx = colIndex * 2;
                  final bottomColorIdx = topColorIdx + 1;
                  return Column(
                    children: [
                      _buildColorBox(AppColors.palette[topColorIdx]),
                      _buildColorBox(AppColors.palette[bottomColorIdx]),
                    ],
                  );
                }),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Right Tools
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Brush Size
              CompositedTransformTarget(
                link: _brushSizeLink,
                child: GestureDetector(
                  onTap: _toggleBrushSizeOverlay,
                  child: Container(
                    width: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Container(
                        width: _strokeWidth,
                        height: _strokeWidth,
                        decoration: const BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Tool Icons
              _buildToolIcon(
                'assets/images/pen.gif',
                'pen',
                onTap: () => setState(() => _activeTool = 'pen'),
              ),
              const SizedBox(width: 16),

              // Action Icons
              _buildToolIcon(
                'assets/images/undo.gif',
                '',
                onTap: _undoAction,
                isButton: true,
              ),
              const SizedBox(width: 4),
              _buildToolIcon(
                'assets/images/clear.gif',
                '',
                onTap: _clearBoard,
                isButton: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColorBox(Color color) {
    return GestureDetector(
      onTap: () => setState(() => _selectedColor = color),
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(color: color),
      ),
    );
  }

  /// Builds a single toolbar icon button.
  ///
  /// [toolId] drives the active-highlight (purple border) when it matches
  /// [_activeTool]. [isButton] disables highlighting for stateless action
  /// buttons like undo and clear.
  Widget _buildToolIcon(
    String imagePath,
    String toolId, {
    required VoidCallback onTap,
    bool isButton = false,
  }) {
    final isActive = !isButton && _activeTool == toolId;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        decoration: BoxDecoration(
          color: isActive ? Colors.purple.shade200 : Colors.white,
          border: isActive
              ? Border.all(color: Colors.purple.shade700, width: 2)
              : Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(child: Image.asset(imagePath, width: 30, height: 30)),
      ),
    );
  }
}
