import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/websocket/websocket_service.dart';
import 'package:frontend/features/game/providers/game_provider.dart';

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
  StreamSubscription? _sub;

  final List<Color> _colors = [
    Colors.black,
    Colors.white,
    Colors.red,
    Colors.green,
    Colors.blue,
    Colors.yellow,
    Colors.orange,
    Colors.purple,
    Colors.brown,
    Colors.pink,
  ];

  @override
  void initState() {
    super.initState();
    // Listen directly to WebSocket stream for fast, isolated drawing updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final wsService = ref.read(webSocketServiceProvider);
      _sub = wsService.messageStream.listen((data) {
        if (data['type'] == 'draw') {
          if (!widget.isDrawer || data['action'] == 'clear') {
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.isDrawer) _buildToolbar(),
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    onPanStart: (details) => _onPanStart(details, constraints),
                    onPanUpdate: (details) =>
                        _onPanUpdate(details, constraints),
                    onPanEnd: _onPanEnd,
                    child: CustomPaint(
                      painter: DrawingPainter(
                        paths: _paths,
                        currentPath: _currentPath,
                      ),
                      size: Size.infinite,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.delete), onPressed: _clearBoard),
          Slider(
            value: _strokeWidth,
            min: 2,
            max: 20,
            onChanged: (v) => setState(() => _strokeWidth = v),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _colors.map((c) {
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = c),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _selectedColor == c
                              ? Colors.black
                              : Colors.grey.shade300,
                          width: 2,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
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
