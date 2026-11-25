import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lms/core/theme/app_theme.dart';
import 'package:lms/features/authentication/data/repositories/auth_repository.dart';
import 'package:lms/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class ProfileCompletionDialog extends StatefulWidget {
  final String token;
  final String? initialFirstName;
  final String? initialLastName;
  final String? initialEmail;

  const ProfileCompletionDialog({
    super.key,
    required this.token,
    this.initialFirstName,
    this.initialLastName,
    this.initialEmail,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String token,
    String? initialFirstName,
    String? initialLastName,
    String? initialEmail,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // Non-dismissible until completed
      builder: (ctx) => ProfileCompletionDialog(
        token: token,
        initialFirstName: initialFirstName,
        initialLastName: initialLastName,
        initialEmail: initialEmail,
      ),
    );
  }

  @override
  State<ProfileCompletionDialog> createState() => _ProfileCompletionDialogState();
}

class _ProfileCompletionDialogState extends State<ProfileCompletionDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  final _classController = TextEditingController();
  final _stateController = TextEditingController();
  final _cityController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final first = widget.initialFirstName == 'Student' ? '' : (widget.initialFirstName ?? '');
    final last = widget.initialLastName == '.' ? '' : (widget.initialLastName ?? '');
    final email = (widget.initialEmail?.contains('@skd.com') ?? true) ? '' : (widget.initialEmail ?? '');

    _firstNameController = TextEditingController(text: first);
    _lastNameController = TextEditingController(text: last);
    _emailController = TextEditingController(text: email);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _classController.dispose();
    _stateController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authRepo = context.read<AuthRepository>();
      await authRepo.updateUserProfile(
        token: widget.token,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim(),
        studentClass: _classController.text.trim(),
        state: _stateController.text.trim(),
        city: _cityController.text.trim(),
      );

      if (mounted) {
        context.read<AuthBloc>().add(const AuthStarted());
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: ${e.toString()}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Gradient Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0040DD), Color(0xFF007AFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const PhosphorIcon(
                        PhosphorIcons.userCircle,
                        size: 36,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Complete Your Profile',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Please fill out your details to access the student portal.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // Form Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildInput(
                              label: 'FIRST NAME *',
                              hint: 'First Name',
                              controller: _firstNameController,
                              validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildInput(
                              label: 'LAST NAME',
                              hint: 'Last Name',
                              controller: _lastNameController,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      _buildInput(
                        label: 'EMAIL ADDRESS *',
                        hint: 'you@example.com',
                        icon: PhosphorIcons.envelopeSimple,
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Email is required';
                          if (!val.contains('@') || !val.contains('.')) return 'Enter valid email';
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      _buildInput(
                        label: 'TARGET CLASS',
                        hint: 'e.g. 11th, 12th, Dropper',
                        icon: PhosphorIcons.graduationCap,
                        controller: _classController,
                      ),

                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: _buildInput(
                              label: 'STATE',
                              hint: 'State',
                              icon: PhosphorIcons.mapPin,
                              controller: _stateController,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildInput(
                              label: 'CITY',
                              hint: 'City',
                              controller: _cityController,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 2,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text(
                                  'Save Profile & Continue 🚀',
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput({
    required String label,
    required String hint,
    required TextEditingController controller,
    IconData? icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: Color(0xFF6B7280),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.normal),
            prefixIcon: icon != null ? PhosphorIcon(icon, size: 18, color: Colors.grey) : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primary, width: 1.2),
            ),
          ),
        ),
      ],
    );
  }
}
