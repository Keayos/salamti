import 'dart:async';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

// ─────────────────────────────────────────────
//  Blood type options — UI label → API value
// ─────────────────────────────────────────────
const _kBloodTypes = [
  ('A+', 'A_PLUS'),
  ('A-', 'A_MINUS'),
  ('B+', 'B_PLUS'),
  ('B-', 'B_MINUS'),
  ('AB+', 'AB_PLUS'),
  ('AB-', 'AB_MINUS'),
  ('O+', 'O_PLUS'),
  ('O-', 'O_MINUS'),
];

// ─────────────────────────────────────────────
//  Page enum
// ─────────────────────────────────────────────
enum _Page { login, step1, step2 }

// ═════════════════════════════════════════════════════════════════════════════
//  AuthScreen
// ═════════════════════════════════════════════════════════════════════════════
class AuthScreen extends StatefulWidget {
  final VoidCallback onLogin;
  const AuthScreen({super.key, required this.onLogin});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  _Page _page = _Page.login;

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();

  String? _bloodTypeApi; // e.g. "AB_PLUS"
  bool _showPass = false;
  bool _isLoading = false;
  String? _errorMsg;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 260));
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
    _ageCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────

  void _go(_Page page) {
    setState(() {
      _page = page;
      _errorMsg = null;
    });
    _animCtrl.forward(from: 0);
  }

  void _clearError() {
    if (_errorMsg != null) setState(() => _errorMsg = null);
  }

  // ── Login ──────────────────────────────────────────────────

  Future<void> _login() async {
    _clearError();
    if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _errorMsg = 'Please fill in all fields.');
      return;
    }
    setState(() => _isLoading = true);
    final err = await AuthService.login(
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (err != null) {
      setState(() => _errorMsg = err);
    } else {
      widget.onLogin();
    }
  }

  // ── Register step 1 → step 2 ───────────────────────────────

  void _proceedToStep2() {
    _clearError();
    if (_nameCtrl.text.trim().isEmpty ||
        _emailCtrl.text.trim().isEmpty ||
        _phoneCtrl.text.trim().isEmpty ||
        _passCtrl.text.isEmpty) {
      setState(() => _errorMsg = 'Please fill in all fields.');
      return;
    }
    _go(_Page.step2);
  }

  // ── Register submit ────────────────────────────────────────

  Future<void> _register() async {
    _clearError();
    if (_bloodTypeApi == null) {
      setState(() => _errorMsg = 'Please select your blood type.');
      return;
    }
    final ageInt = int.tryParse(_ageCtrl.text.trim());
    if (ageInt == null || ageInt < 15 || ageInt > 100) {
      setState(() => _errorMsg = 'Please enter a valid age (15–100).');
      return;
    }
    setState(() => _isLoading = true);
    final err = await AuthService.register(
      fullName: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      password: _passCtrl.text,
      age: ageInt,
      bloodType: _bloodTypeApi!,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (err != null) {
      setState(() => _errorMsg = err);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VerifyEmailScreen(
            email: _emailCtrl.text.trim(),
            onDone: () {
              Navigator.of(context).pop();
              _go(_Page.login);
            },
          ),
        ),
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────

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

              // ── Logo ──
              Column(
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: AppColors.blue,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.blue.withOpacity(0.45),
                          blurRadius: 28,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child:
                        const Icon(Icons.shield, color: Colors.white, size: 36),
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
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontFamily: 'Outfit')),
                ],
              ),
              const SizedBox(height: 32),

              // ── Card ──
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: _buildPage(),
                ),
              ),

              const SizedBox(height: 20),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shield_outlined,
                      size: 13, color: AppColors.textMuted),
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

  Widget _buildPage() {
    return switch (_page) {
      _Page.login => _buildLogin(),
      _Page.step1 => _buildStep1(),
      _Page.step2 => _buildStep2(),
    };
  }

  // ── Login form ─────────────────────────────────────────────

  Widget _buildLogin() {
    return Column(
      children: [
        _TabBar(
            isLogin: true, onLogin: () {}, onRegister: () => _go(_Page.step1)),
        const SizedBox(height: 20),
        LabeledInput(
          label: 'Email Address',
          hint: 'name@example.com',
          prefixIcon: Icons.mail_outline,
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
        ),
        _PassField(
          controller: _passCtrl,
          show: _showPass,
          onToggle: () => setState(() => _showPass = !_showPass),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: Text('Forgot password?',
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.blueLight,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Outfit')),
        ),
        const SizedBox(height: 20),
        if (_errorMsg != null) _ErrorBanner(_errorMsg!),
        PrimaryButton(
          label: _isLoading ? 'Signing in…' : 'Sign In  →',
          onTap: _isLoading ? null : _login,
        ),
        const SizedBox(height: 18),
        const _OrDivider(),
        const SizedBox(height: 14),
        Row(
          children: const [
            Expanded(
                child: _SocialBtn(
                    label: 'Google', icon: Icons.g_mobiledata_rounded)),
            SizedBox(width: 10),
            Expanded(child: _SocialBtn(label: 'Apple', icon: Icons.apple)),
          ],
        ),
      ],
    );
  }

  // ── Register step 1 ────────────────────────────────────────

  Widget _buildStep1() {
    return Column(
      children: [
        _TabBar(
            isLogin: false, onLogin: () => _go(_Page.login), onRegister: () {}),
        const SizedBox(height: 20),
        _StepBar(current: 1),
        const SizedBox(height: 20),
        LabeledInput(
          label: 'Full Name',
          hint: 'Name',
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
        LabeledInput(
          label: 'Phone Number',
          hint: '01 000 000 000',
          prefixIcon: Icons.phone_outlined,
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
        ),
        _PassField(
          controller: _passCtrl,
          show: _showPass,
          onToggle: () => setState(() => _showPass = !_showPass),
          hint: true,
        ),
        const SizedBox(height: 20),
        if (_errorMsg != null) _ErrorBanner(_errorMsg!),
        PrimaryButton(label: 'Continue  →', onTap: _proceedToStep2),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () => _go(_Page.login),
          child: RichText(
            text: const TextSpan(
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  fontFamily: 'Outfit'),
              children: [
                TextSpan(text: 'Already have an account?  '),
                TextSpan(
                    text: 'Login',
                    style: TextStyle(
                        color: AppColors.blueLight,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Register step 2 ────────────────────────────────────────

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row with back button
        Row(
          children: [
            GestureDetector(
              onTap: () => _go(_Page.step1),
              child: const Icon(Icons.arrow_back_ios,
                  color: AppColors.blueLight, size: 20),
            ),
            const SizedBox(width: 8),
            const Text('Almost there!',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontFamily: 'Outfit')),
          ],
        ),
        const SizedBox(height: 16),
        _StepBar(current: 2),
        const SizedBox(height: 24),

        // Age
        const Text('AGE',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 1.2,
                fontFamily: 'Outfit')),
        const SizedBox(height: 8),
        TextFormField(
          controller: _ageCtrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(
              color: AppColors.textPrimary, fontSize: 15, fontFamily: 'Outfit'),
          decoration: const InputDecoration(
            hintText: 'Enter your age (15–100)',
            prefixIcon: Icon(Icons.cake_outlined,
                color: AppColors.textSecondary, size: 20),
          ),
        ),
        const SizedBox(height: 24),

        // Blood type grid
        const Text('BLOOD TYPE',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 1.2,
                fontFamily: 'Outfit')),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.8,
          children: _kBloodTypes.map((opt) {
            final selected = _bloodTypeApi == opt.$2;
            return GestureDetector(
              onTap: () => setState(() {
                _bloodTypeApi = opt.$2;
                _clearError();
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: selected ? AppColors.blue : AppColors.card2,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: selected ? AppColors.blue : AppColors.border),
                ),
                child: Center(
                  child: Text(opt.$1,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color:
                              selected ? Colors.white : AppColors.textSecondary,
                          fontFamily: 'Outfit')),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),

        if (_errorMsg != null) _ErrorBanner(_errorMsg!),
        PrimaryButton(
          label: _isLoading ? 'Creating account…' : 'Create Account',
          onTap: _isLoading ? null : _register,
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  Verify Email Screen
// ═════════════════════════════════════════════════════════════════════════════
class VerifyEmailScreen extends StatefulWidget {
  final String email;
  final VoidCallback onDone;

  const VerifyEmailScreen({
    super.key,
    required this.email,
    required this.onDone,
  });

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  static const _cooldown = 30;
  int _secondsLeft = 0;
  Timer? _timer;
  bool _isSending = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    // Send the first email automatically on arrival
    _sendEmail();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _secondsLeft = _cooldown);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          t.cancel();
        }
      });
    });
  }

  Future<void> _sendEmail() async {
    setState(() {
      _isSending = true;
      _errorMsg = null;
    });
    final err = await AuthService.sendVerificationEmail(widget.email);
    if (!mounted) return;
    setState(() => _isSending = false);
    if (err != null) {
      setState(() => _errorMsg = err);
    } else {
      _startCooldown();
    }
  }

  @override
  Widget build(BuildContext context) {
    final canResend = !_isSending && _secondsLeft == 0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.blue.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.blue.withOpacity(0.3), width: 2),
                ),
                child: const Icon(Icons.mark_email_unread_outlined,
                    color: AppColors.blueLight, size: 38),
              ),
              const SizedBox(height: 28),

              const Text('Check your email',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      fontFamily: 'Outfit')),
              const SizedBox(height: 10),

              const Text('We sent a verification link to',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      fontFamily: 'Outfit')),
              const SizedBox(height: 4),
              Text(widget.email,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.blueLight,
                      fontFamily: 'Outfit')),
              const SizedBox(height: 10),
              const Text(
                'Click the link in the email to activate your account,\nthen come back to log in.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    height: 1.5,
                    fontFamily: 'Outfit'),
              ),
              const SizedBox(height: 32),

              if (_errorMsg != null) ...[
                _ErrorBanner(_errorMsg!),
                const SizedBox(height: 12),
              ],

              // Resend state
              if (_isSending)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      color: AppColors.blueLight, strokeWidth: 2),
                )
              else if (_secondsLeft > 0)
                Text('Resend in ${_secondsLeft}s',
                    style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Outfit'))
              else if (canResend)
                GestureDetector(
                  onTap: _sendEmail,
                  child: const Text('Resend verification email',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.blueLight,
                          fontFamily: 'Outfit')),
                ),

              const SizedBox(height: 32),
              SecondaryButton(label: '← Back to Login', onTap: widget.onDone),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  Private widgets
// ═════════════════════════════════════════════════════════════════════════════

class _TabBar extends StatelessWidget {
  final bool isLogin;
  final VoidCallback onLogin, onRegister;
  const _TabBar({
    required this.isLogin,
    required this.onLogin,
    required this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.card2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        _Tab(label: 'Login', active: isLogin, onTap: onLogin),
        _Tab(label: 'Register', active: !isLogin, onTap: onRegister),
      ]),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Tab({required this.label, required this.active, required this.onTap});

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
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2))
                  ]
                : null,
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: active ? AppColors.textPrimary : AppColors.textMuted,
                  fontFamily: 'Outfit')),
        ),
      ),
    );
  }
}

class _PassField extends StatelessWidget {
  final TextEditingController controller;
  final bool show;
  final VoidCallback onToggle;
  final bool hint;
  const _PassField({
    required this.controller,
    required this.show,
    required this.onToggle,
    this.hint = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('PASSWORD',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 1.2,
                fontFamily: 'Outfit')),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: !show,
          style: const TextStyle(
              color: AppColors.textPrimary, fontSize: 15, fontFamily: 'Outfit'),
          decoration: InputDecoration(
            hintText: '••••••••',
            prefixIcon: const Icon(Icons.lock_outline,
                color: AppColors.textSecondary, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                show
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.textSecondary,
                size: 20,
              ),
              onPressed: onToggle,
            ),
          ),
        ),
        if (hint) ...[
          const SizedBox(height: 6),
          const Text(
            'Min. 8 characters with a mix of letters, numbers & symbols.',
            style: TextStyle(
                fontSize: 11, color: AppColors.textMuted, fontFamily: 'Outfit'),
          ),
        ],
        const SizedBox(height: 14),
      ],
    );
  }
}

class _StepBar extends StatelessWidget {
  final int current; // 1 or 2
  const _StepBar({required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(2, (i) {
        final active = i + 1 <= current;
        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: i == 0 ? 6 : 0),
            decoration: BoxDecoration(
              color: active ? AppColors.blue : AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String msg;
  const _ErrorBanner(this.msg);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.red, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(msg,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.red, fontFamily: 'Outfit')),
          ),
        ],
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();
  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: AppColors.border, height: 1)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('OR CONTINUE WITH',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                  letterSpacing: 1,
                  fontFamily: 'Outfit')),
        ),
        Expanded(child: Divider(color: AppColors.border, height: 1)),
      ],
    );
  }
}

class _SocialBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SocialBtn({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
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
    );
  }
}
