import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lms/core/theme/app_theme.dart';
import 'package:lms/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:lms/routes/app_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _hasNavigated = false;
  Timer? _minDisplayTimer;
  Timer? _watchdogTimer;
  bool _minDisplayElapsed = false;
  AuthState? _latestState;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AuthBloc>().add(const AuthStarted());
      }
    });

    _minDisplayTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      _minDisplayElapsed = true;
      _checkAndNavigate();
    });

    _watchdogTimer = Timer(const Duration(milliseconds: 2000), () {
      if (!mounted || _hasNavigated) return;
      _forceNavigate();
    });
  }

  void _checkAndNavigate() {
    if (_hasNavigated || !mounted || !_minDisplayElapsed) return;

    final state = _latestState ?? context.read<AuthBloc>().state;
    if (state.status == AuthStatus.authenticated ||
        state.status == AuthStatus.unauthenticated) {
      _executeNavigation(state);
    }
  }

  void _forceNavigate() {
    if (_hasNavigated || !mounted) return;
    final state = _latestState ?? context.read<AuthBloc>().state;
    _executeNavigation(state);
  }

  void _executeNavigation(AuthState state) {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    _minDisplayTimer?.cancel();
    _watchdogTimer?.cancel();

    if (state.status == AuthStatus.authenticated && state.session != null) {
      final role = (state.session?.user.role ?? 'STUDENT').toUpperCase().trim();
      final route = switch (role) {
        'TEACHER' => AppRoutes.teacherDashboard,
        'PARENT' => AppRoutes.parentDashboard,
        'STUDENT' => AppRoutes.studentDashboard,
        _ => AppRoutes.studentDashboard,
      };
      Navigator.pushReplacementNamed(context, route);
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  @override
  void dispose() {
    _minDisplayTimer?.cancel();
    _watchdogTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        _latestState = state;
        if (_minDisplayElapsed) {
          _checkAndNavigate();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppTheme.darkScreenSystemUi,
        child: Scaffold(
          backgroundColor: AppTheme.authBackground,
          body: Stack(
            children: [
              // Background Gradient
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF02170F), // Deep Forest Night
                      Color(0xFF07271B), // Midnight Emerald
                    ],
                  ),
                ),
              ),
              // Neon Glow Blob 1 (Top-Right)
              Positioned(
                top: -120,
                right: -120,
                width: 380,
                height: 380,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppTheme.accent.withValues(alpha: 0.20),
                        AppTheme.accent.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              // Neon Glow Blob 2 (Bottom-Left)
              Positioned(
                bottom: -100,
                left: -100,
                width: 360,
                height: 360,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppTheme.primary.withValues(alpha: 0.30),
                        AppTheme.primary.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              // Centered Contents
              SafeArea(
                child: Center(
                  child: FadeTransition(
                    opacity: CurvedAnimation(
                      parent: _controller,
                      curve: Curves.easeOut,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 248,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: AppTheme.accent.withValues(alpha: 0.55),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.28),
                                blurRadius: 28,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          child: Image.asset(
                            'assets/images/prepzo_logo.webp',
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'SMART PREP, LEARN ANYTIME ANYWHERE',
                          style: TextStyle(
                            color: AppTheme.accent.withValues(alpha: 0.95),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(height: 32),
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: AppTheme.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
