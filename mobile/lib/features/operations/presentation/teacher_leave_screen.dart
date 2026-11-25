import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lms/core/theme/app_theme.dart';
import 'package:lms/core/widgets/app_scaffold.dart';
import 'package:lms/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:lms/features/operations/data/repositories/operations_repository.dart';

class TeacherLeaveScreen extends StatefulWidget {
  const TeacherLeaveScreen({super.key});

  @override
  State<TeacherLeaveScreen> createState() => _TeacherLeaveScreenState();
}

class _TeacherLeaveScreenState extends State<TeacherLeaveScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  String _leaveType = 'PERSONAL';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _submitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart
        ? (_startDate ?? DateTime.now())
        : (_endDate ?? _startDate ?? DateTime.now());
    final result = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startDate = result;
        if (_endDate != null && _endDate!.isBefore(result)) _endDate = result;
      } else {
        _endDate = result;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() ||
        _startDate == null ||
        _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select both leave dates before submitting.'),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await context.read<OperationsRepository>().requestTeacherLeave(
        token: context.read<AuthBloc>().state.session?.accessToken ?? '',
        leaveType: _leaveType,
        startDate: _startDate!,
        endDate: _endDate!,
        reason: _reasonController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Leave request submitted for admin approval.'),
        ),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _dateLabel(DateTime? value) => value == null
      ? 'Select date'
      : '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Apply for leave',
      showAppBar: true,
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Your request will be visible to the institute admin for approval.',
              style: TextStyle(color: AppTheme.inkSoft(context)),
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              initialValue: _leaveType,
              decoration: const InputDecoration(labelText: 'Leave type'),
              items: const [
                DropdownMenuItem(
                  value: 'PERSONAL',
                  child: Text('Personal leave'),
                ),
                DropdownMenuItem(value: 'SICK', child: Text('Sick leave')),
              ],
              onChanged: _submitting
                  ? null
                  : (value) => setState(() => _leaveType = value ?? 'PERSONAL'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _submitting
                        ? null
                        : () => _pickDate(isStart: true),
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text('From: ${_dateLabel(_startDate)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _submitting ? null : () => _pickDate(isStart: false),
              icon: const Icon(Icons.event_available_outlined),
              label: Text('To: ${_dateLabel(_endDate)}'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _reasonController,
              enabled: !_submitting,
              maxLines: 4,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'Briefly explain the leave request',
              ),
              validator: (value) => value == null || value.trim().length < 5
                  ? 'Enter at least 5 characters.'
                  : null,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
              child: Text(_submitting ? 'Submitting…' : 'Submit for approval'),
            ),
          ],
        ),
      ),
    );
  }
}
