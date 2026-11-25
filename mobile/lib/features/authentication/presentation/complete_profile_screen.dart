import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lms/core/theme/app_theme.dart';
import 'package:lms/core/data/india_locations.dart';
import 'package:lms/features/authentication/data/repositories/auth_repository.dart';
import 'package:lms/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:lms/features/authentication/presentation/widgets/auth_layout.dart';
import 'package:lms/routes/app_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
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
    final authState = context.read<AuthBloc>().state;
    final user = authState.session?.user;

    final first = user?.firstName == 'Student' ? '' : (user?.firstName ?? '');
    final last = user?.lastName == '.' ? '' : (user?.lastName ?? '');
    final email = (user?.email.contains('@skd.com') ?? true)
        ? ''
        : (user?.email ?? '');

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
      final authBloc = context.read<AuthBloc>();
      final token = authBloc.state.session?.accessToken ?? '';
      final authRepo = context.read<AuthRepository>();

      await authRepo.updateUserProfile(
        token: token,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim(),
        studentClass: _classController.text.trim(),
        state: _stateController.text.trim(),
        city: _cityController.text.trim(),
      );

      authBloc.add(const AuthStarted());

      if (mounted) {
        final role = (authBloc.state.session?.user.role ?? 'STUDENT')
            .toUpperCase()
            .trim();
        final route = switch (role) {
          'TEACHER' => AppRoutes.teacherDashboard,
          'PARENT' => AppRoutes.parentDashboard,
          _ => AppRoutes.studentDashboard,
        };

        Navigator.pushNamedAndRemoveUntil(context, route, (route) => false);
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
    return AuthLayout(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Branding Header
            Center(
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Image.asset(
                      'assets/images/app_icon.webp',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const PhosphorIcon(
                        PhosphorIcons.userCircle,
                        size: 40,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Complete Your Profile',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Please fill out your details to access the student portal.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Form Container
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildInputField(
                            label: 'FIRST NAME *',
                            hint: 'First Name',
                            // icon: PhosphorIcons.user,
                            controller: _firstNameController,
                            validator: (val) =>
                                val == null || val.trim().isEmpty
                                ? 'Required'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInputField(
                            label: 'LAST NAME',
                            hint: 'Last Name',
                            controller: _lastNameController,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    _buildInputField(
                      label: 'EMAIL ADDRESS *',
                      hint: 'you@example.com',
                      // icon: PhosphorIcons.envelopeSimple,
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty)
                          return 'Email is required';
                        if (!val.contains('@') || !val.contains('.'))
                          return 'Enter valid email';
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    _buildInputField(
                      label: 'TARGET CLASS',
                      hint: 'e.g. 11th, 12th, Dropper',
                      // icon: PhosphorIcons.graduationCap,
                      controller: _classController,
                    ),

                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _buildLocationDropdown(
                            label: 'STATE',
                            hint: 'Select state',
                            value: _stateController.text,
                            items: indiaStates,
                            onChanged: (value) => setState(() {
                              _stateController.text = value ?? '';
                              _cityController.clear();
                            }),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildLocationDropdown(
                            label: 'CITY',
                            hint: 'Select city',
                            value: _cityController.text,
                            items: citiesForState(_stateController.text),
                            onChanged: (value) => setState(() {
                              _cityController.text = value ?? '';
                            }),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 26),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 3,
                          shadowColor: AppTheme.primary.withValues(alpha: 0.4),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Save & Continue',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
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
    );
  }

  Widget _buildInputField({
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
            color: Color(0xFF4B5563),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF111827),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              fontSize: 13,
              color: Colors.grey,
              fontWeight: FontWeight.normal,
            ),
            prefixIcon: icon != null
                ? PhosphorIcon(icon, size: 18, color: const Color(0xFF9CA3AF))
                : null,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 5,
            ),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationDropdown({
    required String label,
    required String hint,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final selected = items.contains(value) ? value : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: Color(0xFF4B5563),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: selected,
          isExpanded: true,
          hint: Text(
            hint,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          items: items
              .map(
                (item) => DropdownMenuItem(
                  value: item,
                  child: Text(item, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: items.isEmpty ? null : onChanged,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 5,
            ),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
          ),
        ),
      ],
    );
  }
}
