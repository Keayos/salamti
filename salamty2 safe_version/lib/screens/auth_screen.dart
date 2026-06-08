import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onLogin;
  const AuthScreen({super.key, required this.onLogin});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  bool _isLogin = true;
  bool _showPass = false;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _switchTab(bool login) {
    setState(() => _isLogin = login);
    _animCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 40),
              // Logo + title
              Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.blue,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.blue.withOpacity(0.4),
                            blurRadius: 24,
                            spreadRadius: 2)
                      ],
                    ),
                    child:
                        const Icon(Icons.shield, color: Colors.white, size: 34),
                  ),
                  const SizedBox(height: 14),
                  const Text('Salamati',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          fontFamily: 'Outfit')),
                  const SizedBox(height: 4),
                  const Text('Always connected. Always protected.',
                      style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          fontFamily: 'Outfit')),
                ],
              ),
              const SizedBox(height: 32),
              // Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    // Tab switcher
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.card2,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          _TabButton(
                              label: 'Login',
                              active: _isLogin,
                              onTap: () => _switchTab(true)),
                          _TabButton(
                              label: 'Register',
                              active: !_isLogin,
                              onTap: () => _switchTab(false)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    FadeTransition(
                      opacity: _fadeAnim,
                      child: Column(
                        children: [
                          if (!_isLogin)
                            LabeledInput(
                              label: 'Full Name',
                              hint: 'Ganna El laban',
                              prefixIcon: Icons.person_outline,
                              controller: _nameCtrl,
                            ),
                          LabeledInput(
                            label: 'Email Address',
                            hint: 'name@example.com',
                            prefixIcon: Icons.mail_outline,
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          if (!_isLogin)
                            LabeledInput(
                              label: 'Phone Number',
                              hint: '01076489',
                              prefixIcon: Icons.phone_outlined,
                              controller: _phoneCtrl,
                              keyboardType: TextInputType.phone,
                            ),
                          // Password field
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'PASSWORD',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                    letterSpacing: 1.2,
                                    fontFamily: 'Outfit'),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _passCtrl,
                                obscureText: !_showPass,
                                style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 15,
                                    fontFamily: 'Outfit'),
                                decoration: InputDecoration(
                                  hintText: '••••••••',
                                  prefixIcon: const Icon(Icons.lock_outline,
                                      color: AppColors.textSecondary, size: 20),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _showPass
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: AppColors.textSecondary,
                                      size: 20,
                                    ),
                                    onPressed: () =>
                                        setState(() => _showPass = !_showPass),
                                  ),
                                ),
                              ),
                              if (!_isLogin) ...[
                                const SizedBox(height: 6),
                                const Text(
                                  'Minimum 8 characters with a mix of letters and numbers.',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textMuted,
                                      fontFamily: 'Outfit'),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 14),
                          if (_isLogin) ...[
                            Align(
                              alignment: Alignment.centerRight,
                              child: GestureDetector(
                                child: const Text(
                                  'Forgot password?',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.blueLight,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Outfit'),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ] else
                            const SizedBox(height: 20),
                          PrimaryButton(
                            label: _isLogin ? 'Sign In  →' : 'Create Account',
                            onTap: widget.onLogin,
                          ),
                          if (_isLogin) ...[
                            const SizedBox(height: 18),
                            const Row(
                              children: [
                                Expanded(
                                    child: Divider(
                                        color: AppColors.border, height: 1)),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Text('OR CONTINUE WITH',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textMuted,
                                          letterSpacing: 1,
                                          fontFamily: 'Outfit')),
                                ),
                                Expanded(
                                    child: Divider(
                                        color: AppColors.border, height: 1)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Row(
                              children: [
                                Expanded(
                                    child: _SocialButton(
                                        label: 'Google',
                                        icon: Icons.g_mobiledata_rounded)),
                                SizedBox(width: 12),
                                Expanded(
                                    child: _SocialButton(
                                        label: 'Apple', icon: Icons.apple)),
                              ],
                            ),
                          ] else ...[
                            const SizedBox(height: 16),
                            GestureDetector(
                              onTap: () => _switchTab(true),
                              child: RichText(
                                text: const TextSpan(
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMuted,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                      fontFamily: 'Outfit'),
                                  children: [
                                    TextSpan(
                                        text: 'ALREADY HAVE AN ACCOUNT?  '),
                                    TextSpan(
                                      text: 'LOGIN',
                                      style:
                                          TextStyle(color: AppColors.blueLight),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shield_outlined,
                      size: 14, color: AppColors.textMuted),
                  SizedBox(width: 6),
                  Text(
                    'BANK-GRADE ENCRYPTION FOR YOUR SAFETY DATA',
                    style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted,
                        letterSpacing: 0.5,
                        fontFamily: 'Outfit'),
                  ),
                ],
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TabButton(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.card : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: active
                ? [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: active ? AppColors.textPrimary : AppColors.textMuted,
              fontFamily: 'Outfit',
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final IconData icon;

  const _SocialButton({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.card2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.textPrimary, size: 20),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontFamily: 'Outfit')),
          ],
        ),
      ),
    );
  }
}
