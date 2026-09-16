import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Langit malam Mikazuki: base #030014 + 3 radial gradient + bintang
/// twinkle + meteor berekor. Full port dari Starfield.vue + GuestLayout.
class NightSkyBackground extends StatefulWidget {
  const NightSkyBackground({super.key});

  @override
  State<NightSkyBackground> createState() => _NightSkyBackgroundState();
}

class _NightSkyBackgroundState extends State<NightSkyBackground>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const int _maxMeteors = 12;
  static const double _frameMs = 1000 / 60;
  static const double _maxDtMs = 50;

  final math.Random _random = math.Random();
  final List<_Star> _stars = [];
  final List<_Meteor> _meteors = [];
  Timer? _meteorTimer;
  Size _lastSize = Size.zero;
  double _elapsed = 0;
  DateTime? _lastTick;

  late Ticker _ticker;
  bool _paused = false;
  bool _reducedMotion = false;

  double _rand(double min, double max) =>
      min + _random.nextDouble() * (max - min);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_onTick)..start();
    _scheduleMeteors(const Duration(milliseconds: 1500),
        const Duration(milliseconds: 4000));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced == _reducedMotion) return;
    _reducedMotion = reduced;
    if (reduced) {
      _meteorTimer?.cancel();
      _meteors.clear();
    } else if (!_paused) {
      _scheduleMeteors(
          const Duration(milliseconds: 2500), const Duration(milliseconds: 7000));
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _meteorTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final hidden = state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden;
    if (hidden) {
      _paused = true;
      _meteorTimer?.cancel();
      _meteors.clear();
      _lastTick = null;
    } else if (state == AppLifecycleState.resumed) {
      _paused = false;
      _lastTick = null;
      _scheduleMeteors(
          const Duration(milliseconds: 2500), const Duration(milliseconds: 7000));
    }
  }

  void _onTick(Duration elapsed) {
    if (_paused || !mounted) return;
    final now = DateTime.now();
    final dtMs = _lastTick == null
        ? _frameMs
        : math.min(now.difference(_lastTick!).inMicroseconds / 1000, _maxDtMs);
    _lastTick = now;
    setState(() {
      _elapsed += dtMs / 1000;
      _ageMeteors(dtMs / _frameMs);
    });
  }

  void _buildStars(Size size) {
    final area = size.width * size.height;
    final count = (math.min(260, math.max(140, area / 8500))).round();
    _stars
      ..clear()
      ..addAll(List.generate(count, (_) {
        final tint = _random.nextDouble();
        return _Star(
          x: _random.nextDouble(),
          y: _random.nextDouble(),
          r: _rand(0.3, 1.4),
          phase: _random.nextDouble() * math.pi * 2,
          speed: _rand(0.5, 2),
          color: tint < 0.9
              ? const Color(0xFFFFFFFF)
              : tint < 0.95
                  ? const Color(0xFF7CB3FF)
                  : const Color(0xFFC4B5FD),
        );
      }));
    _lastSize = size;
  }

  void _ageMeteors(double step) {
    _meteors.removeWhere((m) => m.age >= m.life);
    for (final m in _meteors) {
      m.age += step;
      if (m.age < 0) continue;
      m.x += m.vx * step;
      m.y += m.vy * step;
    }
  }

  void _spawnMeteorBatch(Size size) {
    if (_reducedMotion || _paused || !mounted) return;
    final roll = _random.nextDouble();
    final batch = roll < 0.7 ? 1 : roll < 0.95 ? 2 : 3;
    for (var i = 0; i < batch; i++) {
      _meteors.add(_Meteor(
        x: _rand(size.width * 0.1, size.width * 0.95) + i * _rand(40, 120),
        y: _rand(-20, size.height * 0.25),
        vx: -_rand(6, 10),
        vy: _rand(3, 5),
        life: _rand(50, 75),
        age: -i * _rand(4, 10),
        width: _rand(1.5, 2.5),
      ));
    }
    if (_meteors.length > _maxMeteors) {
      _meteors.removeRange(0, _meteors.length - _maxMeteors);
    }
    _scheduleMeteors(
        const Duration(milliseconds: 2500), const Duration(milliseconds: 7000));
  }

  void _scheduleMeteors(Duration min, Duration max) {
    _meteorTimer?.cancel();
    if (_reducedMotion) return;
    final ms = min.inMilliseconds +
        _random.nextInt(max.inMilliseconds - min.inMilliseconds);
    final size = _lastSize;
    _meteorTimer = Timer(Duration(milliseconds: ms), () {
      if (size.width > 0) _spawnMeteorBatch(size);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (size.width > 0 &&
            (size.width - _lastSize.width).abs() > 1) {
          _buildStars(size);
        }
        return Container(
          decoration: const BoxDecoration(color: Color(0xFF030014)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 3 radial gradient ala GuestLayout.
              Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.7, -1.0),
                    radius: 0.6,
                    colors: [
                      const Color(0xFF4C1D95).withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.7],
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.7, -0.6),
                    radius: 0.5,
                    colors: [
                      const Color(0xFF2A6FDF).withValues(alpha: 0.22),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.7],
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.0, 1.0),
                    radius: 0.7,
                    colors: [
                      const Color(0xFF1E1B4B).withValues(alpha: 0.5),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.7],
                  ),
                ),
              ),
              CustomPaint(
                painter: _StarfieldPainter(
                  stars: _stars,
                  meteors: _reducedMotion ? const [] : _meteors,
                  elapsed: _elapsed,
                  reducedMotion: _reducedMotion,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Star {
  final double x;
  final double y;
  final double r;
  final double phase;
  final double speed;
  final Color color;

  const _Star({
    required this.x,
    required this.y,
    required this.r,
    required this.phase,
    required this.speed,
    required this.color,
  });
}

class _Meteor {
  double x;
  double y;
  final double vx;
  final double vy;
  final double life;
  double age;
  final double width;

  _Meteor({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.age,
    required this.width,
  });
}

class _StarfieldPainter extends CustomPainter {
  final List<_Star> stars;
  final List<_Meteor> meteors;
  final double elapsed;
  final bool reducedMotion;

  const _StarfieldPainter({
    required this.stars,
    required this.meteors,
    required this.elapsed,
    required this.reducedMotion,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in stars) {
      final alpha = reducedMotion
          ? 0.8
          : 0.25 + 0.75 * (math.sin(elapsed * s.speed + s.phase).abs());
      canvas.drawCircle(
        Offset(s.x * size.width, s.y * size.height),
        s.r * (size.width / 390).clamp(0.8, 2.0),
        Paint()..color = s.color.withValues(alpha: alpha),
      );
    }
    for (final m in meteors) {
      if (m.age < 0) continue;
      final fade = (1 - m.age / m.life).clamp(0.0, 1.0);
      final tail = 90 * fade + 20;
      final head = Offset(m.x, m.y);
      final tailEnd = Offset(
        m.x - m.vx * (tail / 10),
        m.y - m.vy * (tail / 10),
      );
      final paint = Paint()
        ..shader = LinearGradient(colors: [
          Colors.white.withValues(alpha: 0.95 * fade),
          Colors.white.withValues(alpha: 0.0),
        ]).createShader(Rect.fromPoints(head, tailEnd))
        ..strokeWidth = m.width
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(head, tailEnd, paint);
    }
  }

  @override
  bool shouldRepaint(_StarfieldPainter oldDelegate) => true;
}
