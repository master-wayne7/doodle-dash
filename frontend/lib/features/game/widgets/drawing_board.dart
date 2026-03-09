import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/websocket/websocket_service.dart';
import 'package:frontend/features/game/providers/game_provider.dart';
import 'package:frontend/features/game/models/game_state.dart';

class DrawnPath {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  DrawnPath({
    required this.points,
    required this.color,
    required this.strokeWidth,
  });
}

class DrawingBoard extends ConsumerStatefulWidget {
  final bool isDrawer;
  const DrawingBoard({super.key, required this.isDrawer});

  @override
  ConsumerState<DrawingBoard> createState() => _DrawingBoardState();
}

class _DrawingBoardState extends ConsumerState<DrawingBoard> {
  final List<DrawnPath> _paths = [];
  DrawnPath? _currentPath;
  Color _selectedColor = Colors.black;
  double _strokeWidth = 5.0;
  String _activeTool = 'pen'; // 'pen' or 'fill'
  StreamSubscription? _sub;
  final LayerLink _brushSizeLink = LayerLink();
  OverlayEntry? _brushSizeOverlay;

  static const List<Color> _palette = [
    Color.fromARGB(255, 255, 255, 255),
    Color.fromARGB(255, 0, 0, 0),
    Color.fromARGB(255, 193, 193, 193),
    Color.fromARGB(255, 80, 80, 80),
    Color.fromARGB(255, 239, 19, 11),
    Color.fromARGB(255, 116, 11, 7),
    Color.fromARGB(255, 255, 113, 0),
    Color.fromARGB(255, 194, 56, 0),
    Color.fromARGB(255, 255, 228, 0),
    Color.fromARGB(255, 232, 162, 0),
    Color.fromARGB(255, 0, 204, 0),
    Color.fromARGB(255, 0, 70, 25),
    Color.fromARGB(255, 0, 255, 145),
    Color.fromARGB(255, 0, 120, 93),
    Color.fromARGB(255, 0, 178, 255),
    Color.fromARGB(255, 0, 86, 158),
    Color.fromARGB(255, 35, 31, 211),
    Color.fromARGB(255, 14, 8, 101),
    Color.fromARGB(255, 163, 0, 186),
    Color.fromARGB(255, 85, 0, 105),
    Color.fromARGB(255, 223, 105, 167),
    Color.fromARGB(255, 135, 53, 84),
    Color.fromARGB(255, 255, 172, 142),
    Color.fromARGB(255, 204, 119, 77),
    Color.fromARGB(255, 160, 82, 45),
    Color.fromARGB(255, 99, 48, 13),
  ];

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

  @override
  void dispose() {
    _sub?.cancel();
    _hideBrushSizeOverlay();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details, BoxConstraints constraints) {
    if (!widget.isDrawer) return;
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
      'color': _selectedColor.value,
      'strokeWidth': _strokeWidth,
    });
    setState(() {});
  }

  void _onPanUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    if (!widget.isDrawer || _currentPath == null) {
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

  void _onPanEnd(DragEndDetails details) {
    if (!widget.isDrawer || _currentPath == null) {
      return;
    }
    _paths.add(_currentPath!);
    _currentPath = null;
    ref.read(gameProvider.notifier).sendDrawAction({'action': 'end'});
    setState(() {});
  }

  void _clearBoard() {
    if (!widget.isDrawer) return;
    _paths.clear();
    _currentPath = null;
    ref.read(gameProvider.notifier).sendDrawAction({'action': 'clear'});
    setState(() {});
  }

  void _undoAction() {
    if (!widget.isDrawer || _paths.isEmpty) return;
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
        'color': path.color.value,
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

  @override
  Widget build(BuildContext context) {
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
                              _VoteButton(
                                image: 'assets/images/thumbsup.gif',

                                onTap: () => ref
                                    .read(gameProvider.notifier)
                                    .vote('like'),
                              ),
                              const SizedBox(width: 8),
                              _VoteButton(
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
                      _buildColorBox(_palette[topColorIdx]),
                      _buildColorBox(_palette[bottomColorIdx]),
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

class DrawingPainter extends CustomPainter {
  final List<DrawnPath> paths;
  final DrawnPath? currentPath;

  DrawingPainter({required this.paths, required this.currentPath});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );
    void drawPath(DrawnPath dp) {
      if (dp.points.isEmpty) return;
      final paint = Paint()
        ..color = dp.color
        ..strokeWidth = dp.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final path = Path()
        ..moveTo(dp.points[0].dx * size.width, dp.points[0].dy * size.height);
      for (int i = 1; i < dp.points.length; i++) {
        path.lineTo(
          dp.points[i].dx * size.width,
          dp.points[i].dy * size.height,
        );
      }
      canvas.drawPath(path, paint);
    }

    for (var path in paths) {
      drawPath(path);
    }
    if (currentPath != null) {
      drawPath(currentPath!);
    }
  }

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) => true;
}

class _VoteButton extends StatelessWidget {
  final String image;
  final VoidCallback onTap;

  const _VoteButton({required this.image, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Image.asset(image, width: 40, height: 40),
    );
  }
}
