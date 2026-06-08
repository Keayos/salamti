import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onDone;
  const SplashScreen({super.key, required this.onDone});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  double _progress = 0;
  String _status = 'Initializing system...';
  late AnimationController _glowController;
  late Animation<double> _glowAnim;

  static const _statuses = [
    'Initializing system...',
    'Syncing with detector...',
    'Loading safety data...',
    'Ready!',
  ];

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    _startLoading();
  }

  void _startLoading() async {
    final steps = [
      (400, 0.15, _statuses[0]),
      (500, 0.40, _statuses[1]),
      (600, 0.70, _statuses[2]),
      (500, 1.00, _statuses[3]),
    ];
    for (final step in steps) {
      await Future.delayed(Duration(milliseconds: step.$1));
      if (!mounted) return;
      setState(() {
        _progress = step.$2;
        _status = step.$3;
      });
    }
    await Future.delayed(const Duration(milliseconds: 400));
    widget.onDone();
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Glow background
          AnimatedBuilder(
            animation: _glowAnim,
            builder: (_, __) => Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.blue.withOpacity(0.25 * _glowAnim.value),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              AnimatedBuilder(
                animation: _glowAnim,
                builder: (_, child) => Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: AppColors.blue,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.blue
                            .withOpacity(0.6 * _glowAnim.value),
                        blurRadius: 40,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: child,
                ),
                child: const Icon(Icons.shield, color: Colors.white, size: 54),
              ),
              const SizedBox(height: 28),
              const Text(
                'Salamty',
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'YOUR SAFETY, ALWAYS CONNECTED',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.blue,
                  letterSpacing: 2.5,
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(height: 60),
              // Progress
              SizedBox(
                width: 200,
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _progress,
                        backgroundColor: AppColors.border,
                        valueColor: const AlwaysStoppedAnimation(AppColors.blue),
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.card2,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const StatusDot(),
                          const SizedBox(width: 8),
                          Text(
                            _status,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class StatusDot extends StatelessWidget {
  const StatusDot({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: AppColors.blueLight,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: AppColors.blueLight.withOpacity(0.5), blurRadius: 6)
        ],
      ),
    );
  }
}
