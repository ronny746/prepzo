import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:lms/core/theme/app_theme.dart';
import 'package:lms/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:lms/features/authentication/presentation/widgets/auth_layout.dart';
import 'package:lms/routes/app_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  String _selectedRole = 'student'; // mobile app supports student and parent accounts only
  int _currentStep = 0; // 0: Phone Number, 1: OTP / Roll Number
  bool _usePassword = false;

  Timer? _timer;
  // Resend wait; 3 min was too long for a student whose OTP did not arrive.
  static const int _resendSeconds = 60;
  int _startSeconds = _resendSeconds;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _stopTimer();
    super.dispose();
  }

  void _startTimer() {
    _stopTimer();
    setState(() {
      _startSeconds = _resendSeconds;
      _canResend = false;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_startSeconds <= 1) {
        _stopTimer();
        setState(() => _canResend = true);
      } else {
        setState(() => _startSeconds--);
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  String _formattedTime() {
    final minutes = (_startSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_startSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _requestOtp() {
    final identity = _phoneController.text.trim();
    final validIdentity = identity.replaceAll(RegExp(r'\D'), '').length == 10;
    if (!validIdentity) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 10-digit mobile number.'),
        ),
      );
      return;
    }
    if (_usePassword) {
      setState(() => _currentStep = 1);
      return;
    }
    context.read<AuthBloc>().add(
      AuthOtpRequested(mobileNumber: identity, role: _selectedRole),
    );
  }

  void _verifyOtp() {
    final identity = _phoneController.text.trim();
    final otp = _otpController.text.trim();

    if (identity.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your account identifier')),
      );
      return;
    }

    if (otp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _usePassword
                ? 'Please enter your password'
                : 'Please enter 6-digit OTP',
          ),
        ),
      );
      return;
    }

    if (!_usePassword && !RegExp(r'^\d{6}$').hasMatch(otp)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the 6-digit OTP.')),
      );
      return;
    }

    if (_usePassword) {
      context.read<AuthBloc>().add(
        AuthLoginRequested(email: identity, password: otp, role: _selectedRole),
      );
    } else {
      context.read<AuthBloc>().add(
        AuthOtpVerifyRequested(phone: identity, otp: otp, role: _selectedRole),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state.status == AuthStatus.authenticated) {
          final session = state.session;
          final user = session?.user;
          final token = session?.accessToken ?? '';

          if (user != null && user.isProfileIncomplete && token.isNotEmpty) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.completeProfile,
              (route) => false,
            );
          } else {
            final role = (user?.role ?? 'STUDENT').toUpperCase().trim();
            final route = switch (role) {
              'PARENT' => AppRoutes.parentDashboard,
              _ => AppRoutes.studentDashboard,
            };

            Navigator.pushNamedAndRemoveUntil(context, route, (route) => false);
          }
        }

        if (state.otpSent) {
          if (_currentStep == 0) {
            setState(() => _currentStep = 1);
            _startTimer();
          }
          if (state.otpMessage != null && state.otpMessage!.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.otpMessage!),
                backgroundColor: AppTheme.success,
              ),
            );
          }
        }

        if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      },
      child: AuthLayout(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Branding Header
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 180.w,
                      height: 60.h,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: AppTheme.accent.withValues(alpha: 0.55),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: Offset(0, 3.h),
                          ),
                        ],
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 8.h,
                      ),
                      child: Image.asset(
                        'assets/images/prepzo_logo.webp',
                        fit: BoxFit.contain,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'prep',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22.sp,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'zo',
                          style: TextStyle(
                            color: AppTheme.secondary,
                            fontSize: 22.sp,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'smart prep, learn anytime anywhere',
                      style: TextStyle(
                        color: AppTheme.secondary.withValues(alpha: 0.95),
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      _currentStep == 0
                          ? 'Enter your registered mobile number to continue'
                          : (_usePassword
                                ? 'Enter your account password to continue'
                                : 'Verify the OTP sent to your mobile number'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              BlocBuilder<AuthBloc, AuthState>(
                builder: (context, state) {
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _currentStep == 0
                        ? _buildStepPhoneInput(state)
                        : _buildStepOtpInput(state),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // STEP 1: Phone Input UI
  Widget _buildStepPhoneInput(AuthState state) {
    return Column(
      key: const ValueKey('step_phone'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Role Selector Bar
        Container(
          padding: EdgeInsets.all(4.w),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedRole = 'student'),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    decoration: BoxDecoration(
                      color: _selectedRole == 'student'
                          ? Colors.white
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          PhosphorIcon(
                            PhosphorIcons.graduationCap,
                            size: 14.sp,
                            color: _selectedRole == 'student'
                                ? AppTheme.primary
                                : Colors.white70,
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            'Student',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12.sp,
                              color: _selectedRole == 'student'
                                  ? AppTheme.primary
                                  : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedRole = 'parent'),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    decoration: BoxDecoration(
                      color: _selectedRole == 'parent'
                          ? Colors.white
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          PhosphorIcon(
                            PhosphorIcons.usersThree,
                            size: 14.sp,
                            color: _selectedRole == 'parent'
                                ? AppTheme.primary
                                : Colors.white70,
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            'Parent',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12.sp,
                              color: _selectedRole == 'parent'
                                  ? AppTheme.primary
                                  : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 16.h),

        Text(
          'REGISTERED MOBILE NUMBER',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 9.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        SizedBox(height: 6.h),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          // Digits only: a hardware keyboard could previously type letters.
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => setState(() {}),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14.sp,
          ),
          decoration: InputDecoration(
            counterText: '',
            prefixIcon: Icon(
              Icons.phone_iphone_rounded,
              color: Colors.white60,
              size: 20.sp,
            ),
            hintText: 'Enter 10-digit mobile number',
            hintStyle: TextStyle(color: Colors.white38, fontSize: 12.sp),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: AppTheme.secondary, width: 1.5),
            ),
          ),
        ),

        SizedBox(height: 20.h),

        Container(
          width: double.infinity,
          height: 48.h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.r),
            gradient: const LinearGradient(
              colors: [AppTheme.primary, AppTheme.secondary],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.secondary.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: Offset(0, 4.h),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: state.isSendingOtp ? null : _requestOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              shadowColor: Colors.transparent,
              padding: EdgeInsets.symmetric(vertical: 12.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              elevation: 0,
            ),
            child: state.isSendingOtp
                ? SizedBox(
                    height: 18.w,
                    width: 18.w,
                    child: const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    _usePassword ? 'Continue with password' : 'Get OTP',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14.sp,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),

        // Center(
        //   child: TextButton(
        //     onPressed: () => setState(() => _usePassword = !_usePassword),
        //     child: Text(
        //       _usePassword ? 'Use mobile OTP instead' : 'Use password instead',
        //       style: TextStyle(
        //         color: Colors.white,
        //         fontSize: 12.sp,
        //         fontWeight: FontWeight.w700,
        //       ),
        //     ),
        //   ),
        // ),
      ],
    );
  }

  // STEP 2: OTP / Roll Number Input UI with 3-minute Resend Timer
  Widget _buildStepOtpInput(AuthState state) {
    return Column(
      key: const ValueKey('step_otp'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Account identifier & Edit button
        Container(
          padding: EdgeInsets.all(10.w),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.phone_android_rounded,
                    color: Colors.white70,
                    size: 16.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    _phoneController.text,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.sp,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  _stopTimer();
                  setState(() => _currentStep = 0);
                },
                child: Text(
                  'Edit account',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 11.sp,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 16.h),

        Text(
          _usePassword ? 'PASSWORD' : 'ENTER 6-DIGIT OTP',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 9.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        SizedBox(height: 6.h),
        TextField(
          controller: _otpController,
          keyboardType: _usePassword
              ? TextInputType.visiblePassword
              : TextInputType.number,
          textAlign: TextAlign.center,
          obscureText: _usePassword,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16.sp,
            letterSpacing: 3.0,
          ),
          decoration: InputDecoration(
            hintText: _usePassword
                ? 'Enter your password'
                : 'Enter 6-digit OTP',
            hintStyle: TextStyle(
              color: Colors.white38,
              fontSize: 12.sp,
              letterSpacing: 0,
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: AppTheme.secondary, width: 1.5),
            ),
          ),
        ),

        SizedBox(height: 12.h),

        if (!_usePassword)
          Center(
            child: _canResend
                ? TextButton(
                    onPressed: state.isSendingOtp
                        ? null
                        : () {
                            _requestOtp();
                            _startTimer();
                          },
                    child: Text(
                      'Resend OTP',
                      style: TextStyle(
                        color: AppTheme.secondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.sp,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        color: AppTheme.secondary.withValues(alpha: 0.7),
                        size: 14.sp,
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        'Resend OTP in ${_formattedTime()}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),

        SizedBox(height: 16.h),

        Container(
          width: double.infinity,
          height: 48.h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.r),
            gradient: const LinearGradient(
              colors: [AppTheme.primary, AppTheme.secondary],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.secondary.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: Offset(0, 4.h),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: state.status == AuthStatus.loading ? null : _verifyOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              shadowColor: Colors.transparent,
              padding: EdgeInsets.symmetric(vertical: 12.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              elevation: 0,
            ),
            child: state.status == AuthStatus.loading
                ? SizedBox(
                    height: 18.w,
                    width: 18.w,
                    child: const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    _usePassword ? 'Sign in' : 'Verify & Continue',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14.sp,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
