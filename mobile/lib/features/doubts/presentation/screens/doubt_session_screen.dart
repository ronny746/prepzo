import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lms/core/network/api_client.dart';
import 'package:lms/core/theme/app_theme.dart';
import 'package:lms/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:lms/features/doubts/data/models/doubt_models.dart';
import 'package:lms/features/doubts/data/repositories/doubts_repository.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class DoubtSessionScreen extends StatefulWidget {
  const DoubtSessionScreen({super.key});

  @override
  State<DoubtSessionScreen> createState() => _DoubtSessionScreenState();
}

class _DoubtSessionScreenState extends State<DoubtSessionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  late final DoubtsRepository _doubtsRepository;

  List<DoubtBatchModel> _batches = [];
  List<TeacherModel> _teachers = [];
  List<DoubtModel> _doubts = [];

  String? _selectedBatchId;
  String? _selectedTeacherId;
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  File? _attachedImageFile;
  String? _attachedImageUrl;
  String? _attachedFileName;
  bool _isUploadingImage = false;

  bool _isLoadingData = true;
  bool _isLoadingDoubts = false;
  bool _isSubmitting = false;

  String _viewMode = 'MY_DOUBTS'; // 'MY_DOUBTS' or 'PUBLIC_FEED'
  String _statusFilter = 'ALL'; // 'ALL', 'PENDING', 'RESOLVED'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _doubtsRepository = DoubtsRepository(apiClient: ApiClient());
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _questionController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _getToken() {
    return context.read<AuthBloc>().state.session?.accessToken ?? '';
  }

  String _getCurrentUserId() {
    return context.read<AuthBloc>().state.session?.user.id ?? '';
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoadingData = true);
    final token = _getToken();

    try {
      final batches = await _doubtsRepository.getStudentBatches(token);
      final teachers = await _doubtsRepository.getTeachers(token);

      setState(() {
        _batches = batches;
        _teachers = teachers;
        if (_batches.isNotEmpty) {
          _selectedBatchId = _batches.first.id;
        }
        if (_teachers.isNotEmpty) {
          _selectedTeacherId = _teachers.first.id;
        }
        _isLoadingData = false;
      });

      if (_selectedBatchId != null) {
        _fetchDoubts();
      }
    } catch (e) {
      setState(() => _isLoadingData = false);
    }
  }

  Future<void> _fetchDoubts() async {
    if (_selectedBatchId == null || _selectedBatchId!.isEmpty) return;
    setState(() => _isLoadingDoubts = true);
    final token = _getToken();

    try {
      final list = await _doubtsRepository.getDoubtsByBatch(
        token,
        _selectedBatchId!,
      );
      setState(() {
        _doubts = list;
        _isLoadingDoubts = false;
      });
    } catch (e) {
      setState(() => _isLoadingDoubts = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        setState(() {
          _attachedImageFile = file;
          _attachedFileName = pickedFile.name;
          _isUploadingImage = true;
        });

        final token = _getToken();
        final uploadedUrl = await _doubtsRepository.uploadFile(
          token,
          pickedFile.path,
        );

        setState(() {
          _isUploadingImage = false;
          _attachedImageUrl = uploadedUrl ?? pickedFile.path;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                uploadedUrl != null
                    ? 'Image attached & uploaded successfully!'
                    : 'Image selected locally.',
              ),
              backgroundColor: AppTheme.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isUploadingImage = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: ${e.toString()}'),
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
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Attach Photo / Image',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const PhosphorIcon(PhosphorIcons.x, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ListTile(
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
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: const Text(
                  'Capture question picture using camera',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              const SizedBox(height: 8),
              ListTile(
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
                  'Select from Gallery',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: const Text(
                  'Choose question image from gallery',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _submitDoubt() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBatchId == null || _selectedBatchId!.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a batch')));
      return;
    }
    if (_selectedTeacherId == null || _selectedTeacherId!.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a teacher')));
      return;
    }

    setState(() => _isSubmitting = true);
    final token = _getToken();

    try {
      final attachments = <String>[];
      if (_attachedImageUrl != null && _attachedImageUrl!.isNotEmpty) {
        attachments.add(_attachedImageUrl!);
      }

      await _doubtsRepository.createDoubt(
        token: token,
        batchId: _selectedBatchId!,
        teacherId: _selectedTeacherId!,
        question: _questionController.text.trim(),
        attachments: attachments,
      );

      setState(() {
        _isSubmitting = false;
        _questionController.clear();
        _attachedImageFile = null;
        _attachedImageUrl = null;
        _attachedFileName = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Doubt submitted successfully! Teacher will respond shortly.',
            ),
            backgroundColor: AppTheme.success,
          ),
        );
        _tabController.animateTo(1);
        _fetchDoubts();
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit doubt: ${e.toString()}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  String _cleanHtmlText(String text) {
    return text.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        title: const Text(
          'Doubt Sessions & Portal',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: const Color(0xFF6B7280),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          tabs: const [
            Tab(text: 'Ask New Doubt'),
            Tab(text: 'My Doubts & Feed'),
          ],
        ),
      ),
      body: _isLoadingData
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : TabBarView(
              controller: _tabController,
              children: [_buildAskDoubtTab(), _buildDoubtsFeedTab()],
            ),
    );
  }

  Widget _buildAskDoubtTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primary, AppTheme.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  PhosphorIcon(
                    PhosphorIcons.chatTeardropText,
                    color: Colors.white,
                    size: 28,
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Have a Doubt?',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Ask expert batch teachers and get 1-on-1 resolution or session assistance.',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Batch Selection Dropdown
            const Text(
              'Select Batch',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedBatchId,
                  isExpanded: true,
                  hint: const Text('Select Batch'),
                  items: _batches.map((b) {
                    final label = b.section.isNotEmpty
                        ? '${b.name} (${b.section})'
                        : b.name;
                    return DropdownMenuItem(
                      value: b.id,
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedBatchId = val);
                      _fetchDoubts();
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Teacher Selection Dropdown
            const Text(
              'Select Teacher',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedTeacherId,
                  isExpanded: true,
                  hint: const Text('Select Teacher'),
                  items: _teachers.map((t) {
                    return DropdownMenuItem(
                      value: t.id,
                      child: Text(
                        t.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedTeacherId = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Question Details Input
            const Text(
              'Question / Description',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _questionController,
              maxLines: 4,
              validator: (val) => val == null || val.trim().isEmpty
                  ? 'Please enter your question'
                  : null,
              decoration: InputDecoration(
                hintText:
                    'Describe your doubt in detail or type question text...',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Attachment Card
            const Text(
              'Attach Image / Photo',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 8),
            if (_attachedImageFile != null || _attachedImageUrl != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: _attachedImageFile != null
                          ? Image.file(
                              _attachedImageFile!,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                            )
                          : (_attachedImageUrl != null &&
                                    _attachedImageUrl!.startsWith('http')
                                ? Image.network(
                                    _attachedImageUrl!,
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    width: 60,
                                    height: 60,
                                    color: AppTheme.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    child: const PhosphorIcon(
                                      PhosphorIcons.image,
                                      color: AppTheme.primary,
                                    ),
                                  )),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _attachedFileName ?? 'Uploaded Photo',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isUploadingImage
                                ? 'Uploading to server...'
                                : 'Attached',
                            style: TextStyle(
                              fontSize: 11,
                              color: _isUploadingImage
                                  ? Colors.orange
                                  : AppTheme.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_isUploadingImage)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.grey,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _attachedImageFile = null;
                            _attachedImageUrl = null;
                            _attachedFileName = null;
                          });
                        },
                      ),
                  ],
                ),
              )
            else
              InkWell(
                onTap: _showImagePickerModal,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: const Row(
                    children: [
                      PhosphorIcon(
                        PhosphorIcons.camera,
                        color: AppTheme.primary,
                        size: 22,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Attach Image / Take Photo (Optional)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ),
                      PhosphorIcon(
                        PhosphorIcons.plusCircle,
                        color: AppTheme.primary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: (_isSubmitting || _isUploadingImage)
                    ? null
                    : _submitDoubt,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const PhosphorIcon(
                        PhosphorIcons.paperPlaneRight,
                        size: 20,
                      ),
                label: Text(_isSubmitting ? 'Posting Doubt...' : 'Post Doubt'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoubtsFeedTab() {
    final currentUserId = _getCurrentUserId();
    final search = _searchController.text.trim().toLowerCase();

    final filteredDoubts = _doubts.filter((d) {
      if (_viewMode == 'MY_DOUBTS') {
        if (currentUserId.isNotEmpty &&
            d.studentId.isNotEmpty &&
            d.studentId != currentUserId) {
          return false;
        }
      }
      if (_statusFilter != 'ALL' && d.status != _statusFilter) {
        return false;
      }
      if (search.isNotEmpty) {
        final q = d.question.toLowerCase();
        final sName = d.studentName.toLowerCase();
        return q.contains(search) || sName.contains(search);
      }
      return true;
    }).toList();

    return Column(
      children: [
        // Controls Header (Tabs, Filters, Search)
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _viewMode = 'MY_DOUBTS'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: _viewMode == 'MY_DOUBTS'
                                      ? Colors.white
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                  boxShadow: _viewMode == 'MY_DOUBTS'
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.05,
                                            ),
                                            blurRadius: 4,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Text(
                                  'My Doubts',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _viewMode == 'MY_DOUBTS'
                                        ? AppTheme.primary
                                        : const Color(0xFF6B7280),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _viewMode = 'PUBLIC_FEED'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: _viewMode == 'PUBLIC_FEED'
                                      ? Colors.white
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                  boxShadow: _viewMode == 'PUBLIC_FEED'
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.05,
                                            ),
                                            blurRadius: 4,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Text(
                                  'Batch Doubts',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _viewMode == 'PUBLIC_FEED'
                                        ? AppTheme.primary
                                        : const Color(0xFF6B7280),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _statusFilter,
                      items: const [
                        DropdownMenuItem(
                          value: 'ALL',
                          child: Text(
                            'All Status',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'PENDING',
                          child: Text(
                            'Pending',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'RESOLVED',
                          child: Text(
                            'Resolved',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _statusFilter = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search questions or students...',
                  prefixIcon: const PhosphorIcon(
                    PhosphorIcons.magnifyingGlass,
                    size: 18,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
                ),
              ),
            ],
          ),
        ),

        // List View
        Expanded(
          child: _isLoadingDoubts
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                )
              : filteredDoubts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      PhosphorIcon(
                        PhosphorIcons.chatTeardropDots,
                        size: 54,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No doubts found',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Post a doubt using the first tab.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchDoubts,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredDoubts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final doubt = filteredDoubts[index];
                      final dateStr = DateFormat(
                        'd MMM yyyy, hh:mm a',
                      ).format(doubt.createdAt.toLocal());
                      final isResolved = doubt.status == 'RESOLVED';
                      final cleanQuestion = _cleanHtmlText(doubt.question);

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Student Info Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: AppTheme.primary
                                          .withValues(alpha: 0.1),
                                      child: Text(
                                        doubt.studentName.isNotEmpty
                                            ? doubt.studentName[0].toUpperCase()
                                            : 'S',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primary,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          doubt.studentName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: Color(0xFF111827),
                                          ),
                                        ),
                                        Text(
                                          dateStr,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isResolved
                                        ? Colors.green.shade50
                                        : Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    isResolved ? 'Resolved' : 'Pending',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isResolved
                                          ? Colors.green.shade800
                                          : Colors.amber.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Question text
                            Text(
                              cleanQuestion.isNotEmpty
                                  ? cleanQuestion
                                  : doubt.question,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF1F2937),
                                height: 1.4,
                              ),
                            ),

                            // Attachments
                            if (doubt.attachments.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: doubt.attachments.map((url) {
                                  final isImage =
                                      url.contains(
                                        RegExp(
                                          r'\.(jpeg|jpg|png|webp|gif)',
                                          caseSensitive: false,
                                        ),
                                      ) ||
                                      !url.startsWith('http');
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: isImage
                                        ? (url.startsWith('http')
                                              ? Image.network(
                                                  url,
                                                  width: 80,
                                                  height: 80,
                                                  fit: BoxFit.cover,
                                                )
                                              : Image.file(
                                                  File(url),
                                                  width: 80,
                                                  height: 80,
                                                  fit: BoxFit.cover,
                                                ))
                                        : Container(
                                            padding: const EdgeInsets.all(8),
                                            color: Colors.grey.shade100,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const PhosphorIcon(
                                                  PhosphorIcons.paperclip,
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 4),
                                                const Text(
                                                  'Attachment',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                  );
                                }).toList(),
                              ),
                            ],

                            // Solution / Teacher reply section
                            if (isResolved &&
                                (doubt.solution != null ||
                                    doubt.solutionAttachments.isNotEmpty)) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50.withValues(
                                    alpha: 0.5,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.green.shade100,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const PhosphorIcon(
                                          PhosphorIcons.checkCircle,
                                          color: Colors.green,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Solution by ${doubt.teacherName}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green.shade900,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (doubt.solution != null) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        _cleanHtmlText(doubt.solution!),
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.green.shade900,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

extension ListFilter<T> on List<T> {
  List<T> filter(bool Function(T element) test) {
    return where(test).toList();
  }
}
