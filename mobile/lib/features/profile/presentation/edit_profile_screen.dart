import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lms/core/theme/app_theme.dart';
import 'package:lms/l10n/app_localizations.dart';
import 'package:lms/core/data/india_locations.dart';
import 'package:lms/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:lms/features/profile/data/models/profile_details.dart';
import 'package:lms/features/profile/data/repositories/profile_repository.dart';
import 'package:lms/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class EditProfileScreen extends StatefulWidget {
  final ProfileDetails? initialProfile;

  const EditProfileScreen({super.key, this.initialProfile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _mobileController;
  late TextEditingController _classController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _addressController;

  String _gender = 'Male';
  String? _avatarUrl;
  File? _localImageFile;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.initialProfile;
    final nameParts = (profile?.name ?? '').trim().split(' ');
    final first =
        profile?.firstName ?? (nameParts.isNotEmpty ? nameParts.first : '');
    final last =
        profile?.lastName ??
        (nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '');

    _firstNameController = TextEditingController(text: first);
    _lastNameController = TextEditingController(text: last);
    _emailController = TextEditingController(text: profile?.email ?? '');
    _mobileController = TextEditingController(text: profile?.mobile ?? '');
    _classController = TextEditingController(text: profile?.studentClass ?? '');
    _cityController = TextEditingController(text: profile?.city ?? '');
    _stateController = TextEditingController(text: profile?.state ?? '');
    _addressController = TextEditingController(text: profile?.address ?? '');

    if (profile?.gender != null && profile!.gender.isNotEmpty) {
      final g = profile.gender.toLowerCase();
      if (g.contains('female')) {
        _gender = 'Female';
      } else if (g.contains('other')) {
        _gender = 'Other';
      } else {
        _gender = 'Male';
      }
    } else {
      _gender = 'Male';
    }

    _avatarUrl = profile?.avatarUrl;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _classController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _localImageFile = File(pickedFile.path);
          _avatarUrl = pickedFile.path;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                source == ImageSource.camera
                    ? 'Photo captured successfully!'
                    : 'Image selected from gallery!',
              ),
              backgroundColor: AppTheme.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to select image: ${e.toString()}'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showImagePickerModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Material(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Profile Photo',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    IconButton(
                      icon: const PhosphorIcon(PhosphorIcons.x, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Option 1: Take Photo from Camera
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const PhosphorIcon(
                        PhosphorIcons.camera,
                        color: AppTheme.primary,
                        size: 22,
                      ),
                    ),
                    title: const Text(
                      'Take Photo from Camera',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    subtitle: const Text(
                      'Capture a new picture using device camera',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                ),
                const SizedBox(height: 8),

                // Option 2: Select Photo from Gallery
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const PhosphorIcon(
                        PhosphorIcons.image,
                        color: Color(0xFF4F46E5),
                        size: 22,
                      ),
                    ),
                    title: const Text(
                      'Select Photo from Gallery',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    subtitle: const Text(
                      'Choose an existing photo from photo library',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final token = context.read<AuthBloc>().state.session?.accessToken ?? '';
      String? finalAvatarUrl = _avatarUrl;
      var avatarUploadFailed = false;

      // If user selected a local file, upload it to the backend first
      if (_localImageFile != null && _localImageFile!.existsSync()) {
        final profileRepo = context.read<ProfileRepository>();
        final uploadedUrl = await profileRepo.uploadImage(
          token: token,
          filePath: _localImageFile!.path,
        );
        if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
          finalAvatarUrl = uploadedUrl;
        } else {
          // Keep saving the other fields; warn about the avatar afterwards.
          avatarUploadFailed = true;
        }
      }

      if (mounted) {
        await context.read<ProfileCubit>().updateProfile(
          token: token,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          email: _emailController.text.trim(),
          mobile: _mobileController.text.trim(),
          gender: _gender,
          studentClass: _classController.text.trim(),
          city: _cityController.text.trim(),
          stateName: _stateController.text.trim(),
          address: _addressController.text.trim(),
          avatarUrl: finalAvatarUrl,
        );

        if (!mounted) return;
        // Cubit reports API failure via state; show it instead of fake success.
        final result = context.read<ProfileCubit>().state;
        if (result.status == ProfileStatus.failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result.errorMessage ??
                    AppLocalizations.of(context)!.profileUpdateFailed,
              ),
              backgroundColor: AppTheme.error,
            ),
          );
          return;
        }

        if (mounted) {
          context.read<AuthBloc>().add(const AuthStarted());
          await context.read<ProfileCubit>().loadProfile(token);
          if (mounted) {
            if (avatarUploadFailed) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    AppLocalizations.of(context)!.profileAvatarUploadFailed,
                  ),
                  backgroundColor: AppTheme.error,
                ),
              );
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profile updated successfully!'),
                backgroundColor: AppTheme.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
            Navigator.pop(context, true);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.profileUpdateFailed),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  ImageProvider? _getAvatarImage() {
    if (_localImageFile != null && _localImageFile!.existsSync()) {
      return FileImage(_localImageFile!);
    }
    if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      if (_avatarUrl!.startsWith('http')) {
        return NetworkImage(_avatarUrl!);
      }
      final file = File(_avatarUrl!);
      if (file.existsSync()) {
        return FileImage(file);
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final avatarImageProvider = _getAvatarImage();

    return Scaffold(
      backgroundColor: isDark
          ? AppTheme.darkBackground
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(
          icon: const PhosphorIcon(PhosphorIcons.arrowLeft, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Edit Personal Info',
          style: Theme.of(context).appBarTheme.titleTextStyle,
        ),
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar Header Section
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [AppTheme.primary, AppTheme.secondary],
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 46,
                          backgroundColor: Colors.white24,
                          backgroundImage: avatarImageProvider,
                          child: avatarImageProvider == null
                              ? const PhosphorIcon(
                                  PhosphorIcons.user,
                                  size: 48,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ),
                      Material(
                        color: AppTheme.primary,
                        shape: const CircleBorder(),
                        elevation: 4,
                        child: InkWell(
                          onTap: _showImagePickerModal,
                          customBorder: const CircleBorder(),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            child: const PhosphorIcon(
                              PhosphorIcons.camera,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    onPressed: _showImagePickerModal,
                    icon: const PhosphorIcon(PhosphorIcons.camera, size: 16),
                    label: const Text('Change Profile Photo'),
                  ),
                ),
                const SizedBox(height: 20),

                // Form Cards: Personal Details
                _buildCard(
                  title: 'Personal Info',
                  icon: PhosphorIcons.user,
                  isDark: isDark,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _firstNameController,
                            decoration: const InputDecoration(
                              labelText: 'First Name',
                              prefixIcon: PhosphorIcon(
                                PhosphorIcons.user,
                                size: 18,
                              ),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Required'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _lastNameController,
                            decoration: const InputDecoration(
                              labelText: 'Last Name',
                              prefixIcon: PhosphorIcon(
                                PhosphorIcons.user,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: PhosphorIcon(
                          PhosphorIcons.envelope,
                          size: 18,
                        ),
                        helperText: 'Your registered email address',
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Email address is required';
                        }
                        final emailRegex = RegExp(
                          r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$',
                        );
                        if (!emailRegex.hasMatch(val.trim())) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _mobileController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Mobile Number',
                        prefixIcon: PhosphorIcon(PhosphorIcons.phone, size: 18),
                        helperText:
                            'Note: Changing this will require you to log in with the new number next time.',
                        helperMaxLines: 2,
                        helperStyle: TextStyle(
                          color: Color(0xFFEA580C),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _classController,
                      decoration: const InputDecoration(
                        labelText: 'Class',
                        prefixIcon: PhosphorIcon(
                          PhosphorIcons.chalkboard,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _gender,
                      decoration: const InputDecoration(
                        labelText: 'Gender',
                        prefixIcon: PhosphorIcon(
                          PhosphorIcons.genderIntersex,
                          size: 18,
                        ),
                      ),
                      items: ['Male', 'Female', 'Other'].map((g) {
                        return DropdownMenuItem(value: g, child: Text(g));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _gender = val);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Form Cards: Location & Address
                _buildCard(
                  title: 'Location & Address',
                  icon: PhosphorIcons.mapPin,
                  isDark: isDark,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildLocationDropdown(
                            label: 'State',
                            value: _stateController.text,
                            items: indiaStates,
                            onChanged: (value) => setState(() {
                              _stateController.text = value ?? '';
                              _cityController.clear();
                            }),
                            icon: PhosphorIcons.mapTrifold,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildLocationDropdown(
                            label: 'City',
                            value: _cityController.text,
                            items: citiesForState(_stateController.text),
                            onChanged: (value) => setState(
                              () => _cityController.text = value ?? '',
                            ),
                            icon: PhosphorIcons.buildings,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _addressController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Full Address',
                        prefixIcon: PhosphorIcon(
                          PhosphorIcons.mapPin,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              PhosphorIcon(PhosphorIcons.floppyDisk, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Save Profile Changes',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required IconData icon,
  }) {
    final selected = items.contains(value) ? value : null;
    return DropdownButtonFormField<String>(
      initialValue: selected,
      isExpanded: true,
      hint: Text('Select $label'.toLowerCase()),
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
        labelText: label,
        prefixIcon: PhosphorIcon(icon, size: 18),
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PhosphorIcon(icon, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
