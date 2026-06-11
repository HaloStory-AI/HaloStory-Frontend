import 'dart:math' as math;
import 'package:flutter/material.dart';

class BondExplosionEffect extends StatefulWidget {
  final VoidCallback onFinished;
  const BondExplosionEffect({super.key, required this.onFinished});

  @override
  State<BondExplosionEffect> createState() => _BondExplosionEffectState();
}

class _BondExplosionEffectState extends State<BondExplosionEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = [];
  final int _count = 50;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    final random = math.Random();
    for (int i = 0; i < _count; i++) {
      _particles.add(_Particle(random));
    }

    _controller.addListener(() {
      if (mounted) setState(() {});
    });

    _controller.forward().then((_) => widget.onFinished());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _ParticlePainter(_particles, _controller.value),
        child: Container(),
      ),
    );
  }
}

class _Particle {
  late double x, y;
  late double vx, vy;
  late double size;
  late Color color;

  _Particle(math.Random rand) {
    x = 0.5;
    y = 0.4;
    final angle = rand.nextDouble() * 2 * math.pi;
    final speed = 0.05 + rand.nextDouble() * 0.15;
    vx = math.cos(angle) * speed;
    vy = math.sin(angle) * speed;
    size = 12.0 + rand.nextDouble() * 20.0;
    color = rand.nextBool() ? Colors.pinkAccent : Colors.redAccent;
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  _ParticlePainter(this.particles, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var p in particles) {
      final t = progress;
      final dx = size.width * (p.x + p.vx * t);
      final dy = size.height * (p.y + p.vy * t - 0.15 * t * t);

      final fade = (1.0 - t).clamp(0.0, 1.0);
      paint.color = p.color.withValues(alpha: fade);

      final heartSize = p.size * (0.5 + t);
      _drawHeart(canvas, Offset(dx, dy), heartSize, paint);
    }
  }

  void _drawHeart(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    final width = size;
    final height = size;

    path.moveTo(center.dx, center.dy + height * 0.35);
    path.cubicTo(
      center.dx + width * 0.1,
      center.dy,
      center.dx + width * 0.5,
      center.dy,
      center.dx + width * 0.5,
      center.dy + height * 0.35,
    );
    path.cubicTo(
      center.dx + width * 0.5,
      center.dy + height * 0.6,
      center.dx + width * 0.25,
      center.dy + height * 0.85,
      center.dx,
      center.dy + height,
    );
    path.cubicTo(
      center.dx - width * 0.25,
      center.dy + height * 0.85,
      center.dx - width * 0.5,
      center.dy + height * 0.6,
      center.dx - width * 0.5,
      center.dy + height * 0.35,
    );
    path.cubicTo(
      center.dx - width * 0.5,
      center.dy,
      center.dx - width * 0.1,
      center.dy,
      center.dx,
      center.dy + height * 0.35,
    );
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
