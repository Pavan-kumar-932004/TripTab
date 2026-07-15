import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';

/// Entry screen — sign in / sign up with email, or continue as guest.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _nameFocus = FocusNode();

  late final AnimationController _entryAnim;
  late final AnimationController _bgAnim;

  bool _isSignUp = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _entryAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();

    _bgAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _nameFocus.dispose();
    _entryAnim.dispose();
    _bgAnim.dispose();
    super.dispose();
  }

  Future<void> _handleAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all fields');
      return;
    }
    if (_isSignUp && name.isEmpty) {
      setState(() => _errorMessage = 'Please enter your name');
      return;
    }
    if (password.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isSignUp) {
        await ref.read(authProvider.notifier).signUp(
              email: email,
              password: password,
              displayName: name,
            );
      } else {
        await ref.read(authProvider.notifier).signIn(
              email: email,
              password: password,
            );
      }
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        String msg = e.toString();
        // Clean up common Supabase error messages
        if (msg.contains('Invalid login credentials')) {
          msg = 'Wrong email or password. Try again.';
        } else if (msg.contains('User already registered')) {
          msg = 'Account already exists. Try signing in.';
        } else if (msg.contains('Email not confirmed')) {
          msg = 'Check your email for the confirmation link.';
        } else if (msg.contains('Exception:')) {
          msg = msg.replaceAll('Exception: ', '');
        }
        setState(() => _errorMessage = msg);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _continueAsGuest() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authProvider.notifier).loginAsGuest('Guest');
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to continue: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // While the session restore is in progress, show a clean splash
    // instead of the login form — avoids the flash-to-login bug.
    final isRestoring = ref.watch(authLoadingProvider);
    if (isRestoring) {
      return Scaffold(
        body: Stack(
          children: [
            _AnimatedBackground(animation: _bgAnim, size: size),
            const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF009688),
                strokeWidth: 2.5,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // ── Animated background ─────────────────────────────────
          _AnimatedBackground(animation: _bgAnim, size: size),

          // ── Content ─────────────────────────────────────────────
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: AnimatedBuilder(
                  animation: _entryAnim,
                  builder: (context, child) {
                    final opacity = CurvedAnimation(
                      parent: _entryAnim,
                      curve: const Interval(0, 0.5, curve: Curves.easeOut),
                    ).value;
                    final slide = CurvedAnimation(
                      parent: _entryAnim,
                      curve: const Interval(0.15, 1, curve: Curves.easeOutCubic),
                    ).value;

                    return Opacity(
                      opacity: opacity,
                      child: Transform.translate(
                        offset: Offset(0, 40 * (1 - slide)),
                        child: child,
                      ),
                    );
                  },
                  child: _buildForm(context),
                ),
              ),
            ),

          ),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 32),

        // ── Logo ────────────────────────────────────────────
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF26A69A), Color(0xFF00796B)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF009688).withValues(alpha: 0.35),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Center(
            child: Text(
              '₹',
              style: GoogleFonts.inter(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // ── App name ────────────────────────────────────────
        Text(
          'TripTab',
          style: GoogleFonts.inter(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.8,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          'Split expenses. Not friendships.',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Colors.white.withValues(alpha: 0.55),
            letterSpacing: 0.2,
          ),
        ),

        const SizedBox(height: 44),

        // ── Auth card ───────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sign in / Sign up toggle
              Row(
                children: [
                  _tabButton('Sign In', !_isSignUp, () {
                    setState(() {
                      _isSignUp = false;
                      _errorMessage = null;
                    });
                  }),
                  const SizedBox(width: 16),
                  _tabButton('Sign Up', _isSignUp, () {
                    setState(() {
                      _isSignUp = true;
                      _errorMessage = null;
                    });
                  }),
                ],
              ),

              const SizedBox(height: 24),

              // Name field (only for sign up)
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: _isSignUp
                    ? Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _inputField(
                          controller: _nameController,
                          focusNode: _nameFocus,
                          hint: 'Your name',
                          icon: Icons.person_outline_rounded,
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) =>
                              FocusScope.of(context).requestFocus(_emailFocus),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              // Email
              _inputField(
                controller: _emailController,
                focusNode: _emailFocus,
                hint: 'Email',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) =>
                    FocusScope.of(context).requestFocus(_passwordFocus),
              ),

              const SizedBox(height: 14),

              // Password
              _inputField(
                controller: _passwordController,
                focusNode: _passwordFocus,
                hint: 'Password',
                icon: Icons.lock_outline_rounded,
                obscure: _obscurePassword,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _handleAuth(),
                suffixIcon: GestureDetector(
                  onTap: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  child: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.white.withValues(alpha: 0.35),
                    size: 20,
                  ),
                ),
              ),

              // Error message
              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 22),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleAuth,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF009688),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        const Color(0xFF009688).withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : Text(
                          _isSignUp ? 'Create Account' : 'Sign In',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Divider ─────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: Container(
                height: 1,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'or',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ),
            ),
            Expanded(
              child: Container(
                height: 1,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // ── Guest button ────────────────────────────────────
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: _isLoading ? null : _continueAsGuest,
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: Colors.white.withValues(alpha: 0.15),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            child: Text(
              'Continue without account',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.65),
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        Text(
          'Guest data stays on this device only',
          style: GoogleFonts.inter(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.3),
          ),
        ),

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _tabButton(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            color: active
                ? Colors.white
                : Colors.white.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscure,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      style: GoogleFonts.inter(
        color: Colors.white,
        fontSize: 14,
      ),
      cursorColor: const Color(0xFF26A69A),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(
          color: Colors.white.withValues(alpha: 0.3),
          fontSize: 14,
        ),
        prefixIcon: Icon(
          icon,
          color: Colors.white.withValues(alpha: 0.35),
          size: 20,
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFF26A69A),
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Subtle animated background with floating shapes
// ─────────────────────────────────────────────────────────────────────────────

class _AnimatedBackground extends AnimatedWidget {
  final Size size;

  const _AnimatedBackground({
    required Animation<double> animation,
    required this.size,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    final t = (listenable as Animation<double>).value;

    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(
              const Color(0xFF0A0F1A),
              const Color(0xFF0D1420),
              t,
            )!,
            Color.lerp(
              const Color(0xFF0D1B2A),
              const Color(0xFF101D28),
              t,
            )!,
            Color.lerp(
              const Color(0xFF0A2922),
              const Color(0xFF0D2E28),
              t,
            )!,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: CustomPaint(
        painter: _OrbPainter(t: t, size: size),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  final double t;
  final Size size;

  _OrbPainter({required this.t, required this.size});

  @override
  void paint(Canvas canvas, Size _) {
    // Soft teal orb — top right
    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF009688).withValues(alpha: 0.08),
          const Color(0xFF009688).withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(
            size.width * 0.85 + sin(t * pi) * 20,
            size.height * 0.18 + cos(t * pi) * 15,
          ),
          radius: 180,
        ),
      );
    canvas.drawCircle(
      Offset(
        size.width * 0.85 + sin(t * pi) * 20,
        size.height * 0.18 + cos(t * pi) * 15,
      ),
      180,
      paint1,
    );

    // Warm accent orb — bottom left
    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF00BCD4).withValues(alpha: 0.05),
          const Color(0xFF00BCD4).withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(
            size.width * 0.15 + cos(t * pi) * 25,
            size.height * 0.75 + sin(t * pi) * 20,
          ),
          radius: 200,
        ),
      );
    canvas.drawCircle(
      Offset(
        size.width * 0.15 + cos(t * pi) * 25,
        size.height * 0.75 + sin(t * pi) * 20,
      ),
      200,
      paint2,
    );
  }

  @override
  bool shouldRepaint(_OrbPainter old) => old.t != t;
}
