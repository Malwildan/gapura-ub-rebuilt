import 'package:flutter/material.dart';

import '../demo/demo_session.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    super.key,
    required this.onGuest,
    required this.onUbAccount,
    required this.onLocalRole,
  });

  final VoidCallback onGuest;
  final VoidCallback onUbAccount;
  final ValueChanged<DemoRole> onLocalRole;

  static const navy = Color(0xff123653);
  static const orange = Color(0xffe8952d);

  @override
  Widget build(BuildContext context) => Scaffold(
    body: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 600;
        return Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(child: _WelcomeBackground()),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      compact ? 8 : 24,
                      24,
                      compact ? 8 : 28,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: (constraints.maxHeight - 52).clamp(0, 1200),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            children: [
                              Image.asset(
                                'assets/img/app-logo_gapura-logo.png',
                                width: compact ? 150 : 210,
                                height: compact ? 52 : 76,
                                fit: BoxFit.contain,
                              ),
                              SizedBox(height: compact ? 5 : 17),
                              Text(
                                'Satu Aplikasi\nBanyak Kemudahan',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: navy,
                                  fontSize: compact ? 23 : 27,
                                  height: 1.16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: compact ? 5 : 16),
                              Image.asset(
                                'assets/img/welcome-reference-art.png',
                                width: compact ? 110 : 174,
                                height: compact ? 118 : 300,
                                fit: BoxFit.cover,
                              ),
                            ],
                          ),
                          SizedBox(height: compact ? 8 : 24),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _EntryButton(
                                label: 'MASUK SEBAGAI PENGUNJUNG',
                                color: navy,
                                onPressed: onGuest,
                              ),
                              const SizedBox(height: 9),
                              _EntryButton(
                                label: 'MASUK DENGAN AKUN UB',
                                color: orange,
                                onPressed: onUbAccount,
                              ),
                              const SizedBox(height: 13),
                              Row(
                                children: [
                                  Expanded(
                                    child: Divider(
                                      color: navy.withValues(alpha: .24),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    child: Text(
                                      'AKSES PERAN',
                                      style: TextStyle(
                                        color: navy.withValues(alpha: .72),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(
                                      color: navy.withValues(alpha: .24),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 9),
                              Row(
                                children: [
                                  Expanded(
                                    child: _EntryButton(
                                      label: 'TENDIK',
                                      color: navy,
                                      onPressed: () =>
                                          onLocalRole(DemoRole.staff),
                                      compact: true,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _EntryButton(
                                      label: 'DOSEN',
                                      color: navy,
                                      onPressed: () =>
                                          onLocalRole(DemoRole.lecturer),
                                      compact: true,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _EntryButton(
                                      label: 'ORTU',
                                      color: navy,
                                      onPressed: () =>
                                          onLocalRole(DemoRole.parent),
                                      compact: true,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _WelcomeBackground extends StatelessWidget {
  const _WelcomeBackground();

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _WelcomeBackgroundPainter());
}

class _WelcomeBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const gray = Color(0xffefeee9);
    const cream = Color(0xfffff8e9);
    final boundary = Path()
      ..lineTo(0, size.height * .85)
      ..quadraticBezierTo(
        size.width / 2,
        size.height,
        size.width,
        size.height * .85,
      )
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawColor(gray, BlendMode.src);
    canvas.drawPath(
      boundary,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [gray, cream, cream],
          stops: [0, .3, 1],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EntryButton extends StatelessWidget {
  const _EntryButton({
    required this.label,
    required this.color,
    required this.onPressed,
    this.compact = false,
  });

  final String label;
  final Color color;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: compact ? 46 : 54,
    child: FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: EdgeInsets.symmetric(horizontal: compact ? 5 : 16),
      ),
      onPressed: onPressed,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          maxLines: 1,
          style: TextStyle(
            fontSize: compact ? 13 : 16,
            fontWeight: FontWeight.w800,
            letterSpacing: compact ? .6 : .8,
          ),
        ),
      ),
    ),
  );
}
